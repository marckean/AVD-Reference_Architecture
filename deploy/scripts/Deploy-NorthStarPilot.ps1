<#
.SYNOPSIS
Deploys the AVD North Star pilot from Azure Cloud Shell in one run.

.DESCRIPTION
Works out the values Azure needs, then deploys deploy/azuredeploy.json into an existing resource group:
- registers the Microsoft.DesktopVirtualization resource provider if needed
- looks up the newest Windows 11 Enterprise multi-session Marketplace image version
- looks up the Azure Virtual Desktop service principals (for App Attach on Azure Files)
- looks up the pilot user or group
- generates the session host local admin password
- deploys, then watches the session hosts register

Set the variables in the session first, then pipe this script into iex. Nothing customer-specific is in the
script, so it is safe to publish. Required: $SubscriptionId, $ResourceGroupName, $SubnetId, and one of
$PilotUserPrincipalName, $PilotGroupName or $PilotObjectId.

Set $LandingZoneMode = $true for a policy-governed enterprise landing zone. It switches to:
- a private endpoint whose DNS record is added by the landing zone's own policy (no privatelink zone created)
- Azure Files public network access disabled
- no Microsoft Entra Kerberos yet (FSLogix comes later; App Attach doesn't need it)
- credential sign-in to the Microsoft Entra joined hosts (no single sign-on, which needs a tenant admin)
- Virtual Machine User Login for the pilot users
- subnet join permission for the host pool identity on that one subnet, plus Reader on the network resource group, instead of subscription-wide roles
- no scaling plan
- no Intune enrolment

Optional: $WorkloadPrefix, $SessionHostNamePrefix, $SessionHostCount, $SessionHostVmSize, $MaxSessionLimit,
$ImageOffer, $ImageSku, $Tags (defaults to the resource group's own tags), $AvailabilityZones,
$LocalAdminUsername, $TemplateUri, $WatchMinutes, $EntraSingleSignOn, $EnableFilesEntraKerberos,
$FilesKerberosDomainName and $FilesKerberosDomainGuid.

Custom image: set $CustomImageResourceId to an Azure Compute Gallery image version. It must be Generation 2 with
security type TrustedLaunchSupported or TrustedLaunch, without the Azure Virtual Desktop agent installed.

AD DS join (for a hybrid joined host pool): set $JoinType = 'ActiveDirectory', $DomainName, $DomainJoinOuPath
(distinguished name) and $DomainJoinUsername. The script asks for the password unless $DomainJoinPassword is set.
The join account needs extra rights on the OU, and the subnet needs line of sight to a domain controller. Use a
different $WorkloadPrefix from any Microsoft Entra joined pool, as a host pool has one join type.

.EXAMPLE
$SubscriptionId = '00000000-0000-0000-0000-000000000000'
$ResourceGroupName = 'rg-avd-pilot'
$SubnetId = '/subscriptions/.../subnets/snet-avd'
$PilotUserPrincipalName = 'pilot.user@contoso.com'
$LandingZoneMode = $true
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/scripts/Deploy-NorthStarPilot.ps1 | iex
#>

$ErrorActionPreference = 'Stop'

function Step($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }
function Ok($t) { Write-Host "  OK   $t" -ForegroundColor Green }
function Note($t) { Write-Host "  ...  $t" }
function Warn($t) { Write-Host "  WARN $t" -ForegroundColor Yellow }
function Value($name, $default) { $v = Get-Variable -Name $name -ValueOnly -ErrorAction SilentlyContinue; if ($null -ne $v -and "$v" -ne '') { $v } else { $default } }

function New-StrongPassword([int] $Length = 24) {
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#%^*-_=+')
    $all = ($sets -join '').ToCharArray()
    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($set in $sets) { $chars.Add($set[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($set.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($all.Length)]) }
    -join ($chars | Sort-Object { [System.Security.Cryptography.RandomNumberGenerator]::GetInt32([int]::MaxValue) })
}

$lz = [bool](Value 'LandingZoneMode' $false)
$templateUri = Value 'TemplateUri' 'https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/azuredeploy.json'
$hostCount = [int](Value 'SessionHostCount' 2)

Step 'Checking the inputs'
foreach ($n in 'SubscriptionId', 'ResourceGroupName', 'SubnetId') {
    if (-not (Value $n $null)) { throw "Set `$$n first, then run this again." }
}
$null = Set-AzContext -Subscription $SubscriptionId -WarningAction SilentlyContinue
Ok "Subscription $((Get-AzContext).Subscription.Name)"
$rg = Get-AzResourceGroup -Name $ResourceGroupName
$location = $rg.Location
Ok "Resource group $($rg.ResourceGroupName) in $location"
$subnetParts = $SubnetId -split '/'
$vnet = Get-AzVirtualNetwork -ResourceGroupName $subnetParts[4] -Name $subnetParts[8]
$subnet = $vnet.Subnets | Where-Object Name -eq $subnetParts[10]
if (-not $subnet) { throw "Subnet $($subnetParts[10]) not found in $($subnetParts[8])." }
Ok "Subnet $($subnetParts[10]) in $($subnetParts[8]) ($($subnetParts[4]))"
$subnetRgId = $subnetParts[0..4] -join '/'
foreach ($linked in @($subnet.NetworkSecurityGroup, $subnet.RouteTable) | Where-Object { $_ -and $_.Id }) {
    $linkedParts = $linked.Id -split '/'
    if (($linkedParts[0..4] -join '/') -ne $subnetRgId) {
        Warn "The subnet's $($linkedParts[8]) is in resource group $($linkedParts[4]), not the network's. If the deployment says it can't read it, the host pool identity needs Reader there too."
    }
}
$tags = Value 'Tags' $null
if (-not $tags) { $tags = if ($rg.Tags) { $rg.Tags } else { @{} } }
Ok "Tags: $(($tags.Keys | Sort-Object) -join ', ')"
Ok ("Mode: {0}" -f $(if ($lz) { 'policy-governed landing zone' } else { 'standard North Star' }))

Step 'Resource provider'
$rp = Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization
if (($rp | Select-Object -First 1).RegistrationState -ne 'Registered') {
    Note 'Registering Microsoft.DesktopVirtualization (about a minute)'
    $null = Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization
    for ($i = 0; $i -lt 30 -and ((Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization | Select-Object -First 1).RegistrationState -ne 'Registered'); $i++) { Start-Sleep 10 }
}
Ok 'Microsoft.DesktopVirtualization is registered'

Step 'Marketplace image'
$offer = Value 'ImageOffer' 'office-365'
$sku = Value 'ImageSku' 'win11-26h2-avd-m365'
$image = Get-AzVMImage -Location $location -PublisherName 'MicrosoftWindowsDesktop' -Offer $offer -Skus $sku | Sort-Object { [version]$_.Version } | Select-Object -Last 1
if (-not $image) { throw "No $offer / $sku image found in $location." }
$customImage = Value 'CustomImageResourceId' ''
if ($customImage) { Ok "Not used: the custom image below replaces $offer / $sku" } else { Ok "$offer / $sku version $($image.Version)" }

if ($customImage) {
    Step 'Custom image'
    # Trusted launch, which the session hosts use, doesn't support managed images, and needs a Generation 2 image
    # whose definition has security type TrustedLaunchSupported or TrustedLaunch.
    # https://learn.microsoft.com/azure/virtual-machines/trusted-launch#unsupported-features
    if ($customImage -notmatch '/providers/Microsoft\.Compute/galleries/[^/]+/images/[^/]+/versions/[^/]+$') {
        throw '$CustomImageResourceId must be an Azure Compute Gallery image version (.../galleries/<gallery>/images/<definition>/versions/<version>). Managed images are not supported with Trusted launch.'
    }
    $imageParts = $customImage -split '/'
    if ($imageParts[2] -ne $SubscriptionId) {
        Warn "The gallery is in subscription $($imageParts[2]). Checks skipped; make sure the host pool identity can read it."
    }
    else {
        $definition = Get-AzGalleryImageDefinition -ResourceGroupName $imageParts[4] -GalleryName $imageParts[8] -Name $imageParts[10]
        $version = Get-AzGalleryImageVersion -ResourceGroupName $imageParts[4] -GalleryName $imageParts[8] -GalleryImageDefinitionName $imageParts[10] -Name $imageParts[12]
        if ($definition.HyperVGeneration -ne 'V2') { throw "Image definition $($imageParts[10]) is $($definition.HyperVGeneration). Trusted launch hosts need Generation 2." }
        $securityType = (@($definition.Features) + @($definition.Feature) | Where-Object { $_ -and $_.Name -eq 'SecurityType' } | Select-Object -First 1).Value
        if ($securityType -notmatch '^TrustedLaunch') { throw "Image definition $($imageParts[10]) has security type '$securityType'. Trusted launch hosts need TrustedLaunchSupported or TrustedLaunch." }
        $regions = @($version.PublishingProfile.TargetRegions | Where-Object { $_ } | ForEach-Object { ($_.Name -replace '\s', '').ToLower() })
        if ($regions.Count -and $regions -notcontains $location.ToLower()) { Warn "Version $($imageParts[12]) isn't replicated to $location (regions: $($regions -join ', '))." }
        Ok "$($imageParts[8]) / $($imageParts[10]) version $($imageParts[12]): Generation 2, $securityType, gallery in $($imageParts[4])"
    }
}

$joinType = Value 'JoinType' 'EntraID'
if ($joinType -notin 'EntraID', 'ActiveDirectory') { throw "`$JoinType must be EntraID or ActiveDirectory, not '$joinType'." }
# PowerShell variable names aren't case-sensitive, so this mustn't be called $DomainJoinPassword.
$joinPasswordPlain = ''
if ($joinType -eq 'ActiveDirectory') {
    Step 'AD DS domain join'
    foreach ($n in 'DomainName', 'DomainJoinUsername') {
        if (-not (Value $n $null)) { throw "Set `$$n for an AD DS join, then run this again." }
    }
    $secret = Value 'DomainJoinPassword' $null
    if (-not $secret) { $secret = Read-Host -AsSecureString -Prompt "  Password for $DomainJoinUsername" }
    $joinPasswordPlain = if ($secret -is [securestring]) { [System.Net.NetworkCredential]::new('', $secret).Password } else { "$secret" }
    if (-not $joinPasswordPlain) { throw 'No domain join password entered.' }
    Ok "Domain $DomainName, OU $(Value 'DomainJoinOuPath' '(domain default)'), account $DomainJoinUsername (stored in the Key Vault by the deployment)"
    Note 'The join account needs Reset password, Validated write to DNS host name and to service principal name, and Read and Write account restrictions on descendant computer objects in the OU, as new hosts reuse computer objects.'
    Note 'Learn: https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites'
}

Step 'Azure Virtual Desktop service principals'
$avdSpId = ''; $armSpId = ''
try { $avdSpId = (Get-AzADServicePrincipal -ApplicationId '9cdead84-a844-4324-93f2-b2e6bb768d07').Id } catch { }
try { $armSpId = (Get-AzADServicePrincipal -ApplicationId '50e95039-b200-4007-bc97-8d5790743a63').Id } catch { }
if ($avdSpId) { Ok "Azure Virtual Desktop $avdSpId" } else { Warn 'Azure Virtual Desktop service principal not found. App Attach role on storage will be skipped.' }
if ($armSpId) { Ok "Azure Virtual Desktop ARM Provider $armSpId" } else { Warn 'Azure Virtual Desktop ARM Provider service principal not found. App Attach role on storage will be skipped.' }

Step 'Pilot users'
$pilotType = Value 'PilotPrincipalType' 'Group'
$pilotId = Value 'PilotObjectId' ''
if (-not $pilotId -and (Value 'PilotUserPrincipalName' '')) {
    $pilotId = (Get-AzADUser -UserPrincipalName $PilotUserPrincipalName).Id; $pilotType = 'User'
}
elseif (-not $pilotId -and (Value 'PilotGroupName' '')) {
    $pilotId = (Get-AzADGroup -DisplayName $PilotGroupName | Select-Object -First 1).Id; $pilotType = 'Group'
}
if (-not $pilotId) { throw 'Set $PilotUserPrincipalName, $PilotGroupName or $PilotObjectId.' }
Ok "$pilotType $pilotId"

Step 'Session host local admin'
$adminUser = Value 'LocalAdminUsername' 'avdlocaladmin'
$adminPassword = New-StrongPassword
Ok "Username $adminUser, password generated and stored in the Key Vault by the deployment"
Write-Host ''
Write-Host '  SAVE THIS NOW (shown once). The deployment below can outlast a Cloud Shell session.' -ForegroundColor Yellow
Write-Host "  Session host local admin:  $adminUser" -ForegroundColor White
Write-Host "  Password:                  $adminPassword" -ForegroundColor White
Write-Host '  Also in the Key Vault as sessionHostLocalAdminPassword. Running this again replaces it with a new one.'

$params = @{
    workloadPrefix                                         = Value 'WorkloadPrefix' 'avdpilot'
    location                                               = $location
    pilotUsersGroupObjectId                                = $pilotId
    pilotPrincipalType                                     = $pilotType
    localAdminUsername                                     = $adminUser
    localAdminPassword                                     = $adminPassword
    networkMode                                            = 'existing'
    existingSubnetResourceId                               = $SubnetId
    assignSubnetJoinToHostPoolIdentity                     = $lz
    enableFilesPrivateEndpoint                             = $true
    filesPrivateDnsZoneMode                                = $(if ($lz) { 'ManagedByPolicy' } else { 'Create' })
    filesPublicNetworkAccess                               = $(if ($lz) { 'Disabled' } else { 'Enabled' })
    enableFilesEntraKerberos                               = [bool](Value 'EnableFilesEntraKerberos' (-not $lz))
    filesKerberosDomainName                                = Value 'FilesKerberosDomainName' ''
    filesKerberosDomainGuid                                = Value 'FilesKerberosDomainGuid' ''
    entraSingleSignOn                                      = [bool](Value 'EntraSingleSignOn' (-not $lz))
    assignVirtualMachineUserLogin                          = $lz
    deployScalingPlan                                      = [bool](Value 'DeployScalingPlan' (-not $lz))
    scalingMethod                                          = Value 'ScalingMethod' 'CreateDeletePowerManage'
    assignAutoscaleRolesToHostPoolIdentity                 = -not $lz
    azureVirtualDesktopServicePrincipalObjectId            = $avdSpId
    azureVirtualDesktopArmProviderServicePrincipalObjectId = $armSpId
    sessionHostVmSize                                      = Value 'SessionHostVmSize' 'Standard_D8ads_v5'
    sessionHostNamePrefix                                  = Value 'SessionHostNamePrefix' 'avdpilot'
    maxSessionLimit                                        = [int](Value 'MaxSessionLimit' 12)
    marketplaceImageOffer                                  = $offer
    marketplaceImageSku                                    = $sku
    marketplaceImageVersion                                = $image.Version
    enrollSessionHostsInIntune                             = [bool](Value 'EnrolInIntune' (-not $lz))
    availabilityZones                                      = @(Value 'AvailabilityZones' @(1, 2, 3))
    rampUpMinimumHostPoolSize                              = $hostCount
    rampUpMaximumHostPoolSize                              = [math]::Max($hostCount, 2)
    tags                                                   = $tags
}
if ($customImage) { $params.customImageResourceId = $customImage }
if ($joinType -eq 'ActiveDirectory') {
    $params.sessionHostJoinType = 'ActiveDirectory'
    $params.domainName = $DomainName
    $params.domainJoinOuPath = Value 'DomainJoinOuPath' ''
    $params.domainJoinUsername = $DomainJoinUsername
    $params.domainJoinPassword = $joinPasswordPlain
    if ($params.entraSingleSignOn) { Warn 'Single sign-on on hybrid joined hosts needs a Kerberos server object in AD, or sign-in falls back or fails: https://learn.microsoft.com/azure/virtual-desktop/configure-single-sign-on#create-a-kerberos-server-object' }
}

Step 'Deploying (10-30 minutes; if Cloud Shell times out, it carries on in Azure - watch it in the portal)'
$deploymentName = "northstar-pilot-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Note "Deployment $deploymentName from $templateUri"
# New role assignments can take up to 10 minutes to apply (https://learn.microsoft.com/azure/role-based-access-control/troubleshooting#azure-role-assignments).
# The deployment creates them, then the session host configuration checks the network straight away, so retry
# for up to 10 minutes if Azure hasn't applied them yet. A permission missing somewhere this deployment doesn't
# grant access won't fix itself, so that stops straight away with what to do.
$propagation = 'AuthorizationFailed|UnableToAccessAzureResource|PrincipalNotFound|refresh your credentials'
$grantedScopes = @("/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName", $subnetRgId)
$maxAttempts = 5
$deployment = $null
for ($attempt = 1; $attempt -le $maxAttempts -and -not $deployment; $attempt++) {
    try {
        $deployment = New-AzResourceGroupDeployment -Name "$deploymentName-$attempt" -ResourceGroupName $ResourceGroupName -TemplateUri $templateUri -TemplateParameterObject $params
    }
    catch {
        $message = $_.Exception.Message
        $scope = [regex]::Match($message, "over scope '([^']+)'").Groups[1].Value
        $granted = -not $scope -or @($grantedScopes | Where-Object { $scope -eq $_ -or $scope -like "$_/*" }).Count -gt 0
        if ($attempt -lt $maxAttempts -and $message -match $propagation -and $granted) {
            Note "Attempt $attempt of $maxAttempts hit a permission Azure hasn't applied yet (new role assignments take up to 10 minutes). Retrying in 2.5 minutes; re-running only fills in what's missing."
            Start-Sleep -Seconds 150
            continue
        }
        Warn 'The deployment failed. The message below names the resource and, for a policy block, the policy.'
        Write-Host "  $message" -ForegroundColor Red
        Write-Host "  Details: portal > Resource groups > $ResourceGroupName > Deployments > $deploymentName-$attempt" -ForegroundColor Red
        if ($message -match $propagation -and -not $granted) {
            $identity = [regex]::Match($message, "object id '([0-9a-fA-F-]{36})'").Groups[1].Value
            $scopeRg = ($scope -split '/')[0..4] -join '/'
            Warn "This permission is missing outside the resource groups this deployment grants access to: $scope"
            Warn 'Give the identity Reader on that resource group (or ask its owner to), then run this again:'
            Write-Host "  New-AzRoleAssignment -ObjectId $identity -RoleDefinitionName Reader -Scope $scopeRg" -ForegroundColor Yellow
        }
        throw 'Deployment failed. See the message above.'
    }
}
$o = $deployment.Outputs
Ok "Host pool $($o.hostPoolName.Value), workspace $($o.workspaceName.Value), desktop app group $($o.desktopApplicationGroupName.Value)"
Ok "App Attach share $($o.appAttachSharePath.Value)"

Step "Watching the session hosts register (up to $(Value 'WatchMinutes' 15) minutes)"
$deadline = (Get-Date).AddMinutes([int](Value 'WatchMinutes' 15))
$available = 0
do {
    $hosts = @()
    try { $hosts = @(Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $o.hostPoolName.Value -ErrorAction Stop) } catch { }
    $available = @($hosts | Where-Object { $_.Status -eq 'Available' }).Count
    $vms = @(Get-AzVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue).Count
    Note ("{0:HH:mm:ss}  VMs created: {1}  registered: {2}  available: {3} of {4}" -f (Get-Date), $vms, $hosts.Count, $available, $hostCount)
    if ($available -ge $hostCount) { break }
    Start-Sleep -Seconds 60
} while ((Get-Date) -lt $deadline)
if ($available -ge $hostCount) { Ok 'All session hosts are available' }
else {
    Warn 'Not all hosts are available yet. Creation carries on in the background. Check: portal > host pool > Session hosts.'
    Warn 'If hosts are created but never register, the subnet usually cannot reach the Azure Virtual Desktop required URLs through the firewall.'
}

Step 'Done'
Write-Host '  Connect as the pilot user: https://windows.cloud.microsoft/' -ForegroundColor Green
if ($joinType -eq 'ActiveDirectory' -and -not $params.entraSingleSignOn) { Write-Host '  The hosts are joined to AD DS: sign in with the pilot user''s domain credentials when the desktop starts.' }
elseif (-not $params.entraSingleSignOn) { Write-Host '  Sign-in mode is credentials (targetisaadjoined): enter the pilot user name and password when the desktop starts.' }
