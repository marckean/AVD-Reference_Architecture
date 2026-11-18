<#
.SYNOPSIS
    Deploys an Azure Virtual Desktop personal desktop pilot: a personal host pool (standard management),
    its desktop application group and workspace, access, monitoring, and personal desktop session hosts
    that are AD DS joined or Microsoft Entra joined (optionally Intune enrolled).

.DESCRIPTION
    Built for Azure Cloud Shell (PowerShell). There's no param block: set the variables you need in the
    session first, then run it, so a paste file can carry the environment values and nothing sensitive:

        $SubscriptionId    = '00000000-0000-0000-0000-000000000000'
        $ResourceGroupName = 'rg-contoso-avd-personal'
        $SubnetId          = '/subscriptions/.../virtualNetworks/vnet-contoso/subnets/snet-avd'
        $WorkloadPrefix    = 'contosodd'
        $JoinType          = 'EntraID'            # or 'ActiveDirectory'
        $PilotUserPrincipalName = 'user@contoso.com'
        irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/personal/Deploy-PersonalDesktopPilot.ps1 | iex

    What it does, in order:
      1. Pre-flight checks: modules, subscription context, providers, resource group, subnet, image,
         VM size, quota, users and groups, the AVD service principal, and the AVD agent package.
      2. hostpool.json: host pool, desktop application group, workspace, role assignments, diagnostics,
         the AVD Insights data collection rule and a Key Vault.
      3. A registration token, then sessionhosts.json for every session host that doesn't exist yet.
      4. Watches the session hosts until they're Available, optionally assigns users, and prints a summary.

    Re-running is safe: existing session hosts are left alone and only missing ones are created.
    Set $ValidateOnly = $true for a what-if run that changes nothing.

    Microsoft Learn sources for the design choices are in README.md next to this script.
#>

function Write-PdStep {
    param([string]$Text)
    Write-Host ''
    Write-Host ("== {0}" -f $Text) -ForegroundColor Cyan
}

function Write-PdOk {
    param([string]$Text)
    Write-Host ("   OK   {0}" -f $Text) -ForegroundColor Green
}

function Write-PdInfo {
    param([string]$Text)
    Write-Host ("   ..   {0}" -f $Text)
}

function Write-PdWarn {
    param([string]$Text)
    Write-Host ("   WARN {0}" -f $Text) -ForegroundColor Yellow
}

function Stop-Pd {
    param([string]$Text)
    Write-Host ("   STOP {0}" -f $Text) -ForegroundColor Red
    throw $Text
}

function Get-PdSetting {
    # Reads a variable set by the caller (paste file or session). Empty strings and $null fall back to the default.
    param([string]$SettingName, $DefaultValue)
    $var = Get-Variable -Name $SettingName -ErrorAction SilentlyContinue
    if ($null -eq $var -or $null -eq $var.Value) { return $DefaultValue }
    if ($var.Value -is [string] -and [string]::IsNullOrWhiteSpace($var.Value)) { return $DefaultValue }
    return $var.Value
}

function New-PdPassword {
    # 24 characters with upper, lower, digit and symbol, from a cryptographic RNG.
    param([int]$Length = 24)
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = 'abcdefghijkmnpqrstuvwxyz'
    $digit = '23456789'
    $symbol = '!#%*-_=+?'
    $all = $upper + $lower + $digit + $symbol
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] ($Length * 2)
    $rng.GetBytes($bytes)
    $chars = New-Object System.Collections.Generic.List[char]
    $chars.Add($upper[$bytes[0] % $upper.Length])
    $chars.Add($lower[$bytes[1] % $lower.Length])
    $chars.Add($digit[$bytes[2] % $digit.Length])
    $chars.Add($symbol[$bytes[3] % $symbol.Length])
    for ($i = 4; $i -lt $Length; $i++) { $chars.Add($all[$bytes[$i] % $all.Length]) }
    # Shuffle with the remaining random bytes
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = $bytes[$Length + ($i % $Length)] % ($i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    $rng.Dispose()
    return (-join $chars)
}

function ConvertTo-PdSecure {
    param([string]$Plain)
    if ([string]::IsNullOrEmpty($Plain)) { Stop-Pd 'An empty secret was about to be sent to the deployment.' }
    # NetworkCredential builds the SecureString without ConvertTo-SecureString -AsPlainText (a PSScriptAnalyzer error rule).
    return [System.Net.NetworkCredential]::new('', $Plain).SecurePassword
}

function Get-PdArmJson {
    # GET an ARM path with Invoke-AzRestMethod; returns the parsed body or $null on 404.
    param([string]$Path)
    $resp = Invoke-AzRestMethod -Path $Path -Method GET
    if ($resp.StatusCode -eq 404) { return $null }
    if ($resp.StatusCode -ge 400) { Stop-Pd ("GET {0} returned {1}: {2}" -f $Path, $resp.StatusCode, $resp.Content) }
    return ($resp.Content | ConvertFrom-Json)
}

function Get-PdFeature {
    param($Features, [string]$Name)
    if ($null -eq $Features) { return $null }
    $f = @($Features | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
    if ($f) { return [string]$f.value }
    return $null
}

function Get-PdNormalisedRegion {
    param([string]$Region)
    return ($Region -replace '\s', '').ToLowerInvariant()
}

function Resolve-PdAvdAgentPackage {
    # Picks the Azure Virtual Desktop configuration package (the one the portal's host pool wizard uses for
    # standard-management session hosts) and reads its AddSessionHost parameters, so the DSC extension gets
    # exactly the arguments that package version accepts. The package is only read here, never run.
    param([string]$OverrideUrl)
    $base = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts'
    $candidates = @()
    if ($OverrideUrl) { $candidates += $OverrideUrl }
    $candidates += @(
        "$base/Configuration_1.0.03362.1223.zip",
        "$base/Configuration_1.0.02797.442.zip",
        "$base/Configuration_1.0.02627.270.zip",
        "$base/Configuration_09-08-2022.zip"
    )
    $chosen = $null
    foreach ($url in $candidates) {
        try {
            $null = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            $chosen = $url
            break
        } catch {
            Write-PdInfo ("Not available: {0}" -f $url)
        }
    }
    if (-not $chosen) { Stop-Pd 'No Azure Virtual Desktop configuration package could be reached. Set $AvdAgentPackageUrl to the URL the portal uses and run again.' }

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("avd-agent-package-{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 8)))
    $null = New-Item -ItemType Directory -Path $work -Force
    $zip = Join-Path $work 'package.zip'
    Invoke-WebRequest -Uri $chosen -OutFile $zip -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
    Expand-Archive -Path $zip -DestinationPath (Join-Path $work 'pkg') -Force
    $cfg = Get-ChildItem -Path (Join-Path $work 'pkg') -Filter 'Configuration.ps1' -Recurse | Select-Object -First 1
    if (-not $cfg) { Stop-Pd ("{0} has no Configuration.ps1." -f $chosen) }
    $text = Get-Content -Path $cfg.FullName -Raw

    $start = [regex]::Match($text, '(?i)configuration\s+AddSessionHost')
    if (-not $start.Success) { Stop-Pd ("{0} has no AddSessionHost configuration." -f $chosen) }
    $rest = $text.Substring($start.Index)
    $nodeAt = [regex]::Match($rest, '(?i)\bNode\s+')
    $paramText = if ($nodeAt.Success) { $rest.Substring(0, $nodeAt.Index) } else { $rest }
    $names = @{}
    foreach ($m in [regex]::Matches($paramText, '\[(?<type>[A-Za-z][\w\.]*)\]\s*\$(?<name>[A-Za-z_]\w*)')) {
        $names[$m.Groups['name'].Value.ToLowerInvariant()] = $m.Groups['type'].Value
    }

    # Is the agent installer bundled? (Newer packages may download it instead.)
    $bundled = @(Get-ChildItem -Path (Join-Path $work 'pkg') -Recurse -Include '*RDAgent*.msi', '*RDInfra*.msi' -ErrorAction SilentlyContinue).Count -gt 0
    if (-not $bundled) {
        foreach ($inner in @(Get-ChildItem -Path (Join-Path $work 'pkg') -Recurse -Filter '*.zip')) {
            try {
                $dest = Join-Path $work ('inner-' + $inner.BaseName)
                Expand-Archive -Path $inner.FullName -DestinationPath $dest -Force
                if (@(Get-ChildItem -Path $dest -Recurse -Include '*RDAgent*.msi', '*RDInfra*.msi').Count -gt 0) { $bundled = $true }
            } catch { Write-PdInfo ("Couldn't open {0}" -f $inner.Name) }
        }
    }

    $tokenMode = $null
    if ($names.ContainsKey('registrationinfotoken')) { $tokenMode = 'String' }
    elseif ($names.ContainsKey('registrationinfotokencredential')) { $tokenMode = 'Credential' }
    else { Stop-Pd ("{0}: AddSessionHost takes neither RegistrationInfoToken nor RegistrationInfoTokenCredential." -f $chosen) }
    if (-not $names.ContainsKey('hostpoolname')) { Stop-Pd ("{0}: AddSessionHost has no HostPoolName parameter." -f $chosen) }

    $extra = @{}
    if ($names.ContainsKey('useagentdownloadendpoint')) {
        # Use the agent inside the package when it's there: its download host is on the AVD required URL list.
        $extra['UseAgentDownloadEndpoint'] = (-not $bundled)
    }

    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Url             = $chosen
        TokenMode       = $tokenMode
        PassAadJoin     = $names.ContainsKey('aadjoin')
        ExtraArguments  = $extra
        AgentBundled    = $bundled
        ParameterNames  = ($names.Keys | Sort-Object) -join ', '
    }
}

function Get-PdDeploymentError {
    param([string]$ResourceGroupName, [string]$DeploymentName)
    try {
        $ops = Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName -ErrorAction Stop
        foreach ($op in @($ops | Where-Object { $_.ProvisioningState -eq 'Failed' })) {
            Write-Host ("   FAILED {0} {1}" -f $op.TargetResource, $op.StatusMessage) -ForegroundColor Red
        }
    } catch {
        Write-PdWarn ("Couldn't read the deployment operations: {0}" -f $_.Exception.Message)
    }
}

function Invoke-PdDeployment {
    # Runs one resource group deployment as a job and prints progress every 30 seconds.
    param(
        [string]$ResourceGroupName,
        [string]$DeploymentName,
        [hashtable]$TemplateSource,
        [hashtable]$Parameters,
        [string]$Label
    )
    $job = New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroupName @TemplateSource -TemplateParameterObject $Parameters -AsJob
    $started = Get-Date
    while ($job.State -in @('NotStarted', 'Running')) {
        Start-Sleep -Seconds 30
        $mins = [int]((Get-Date) - $started).TotalMinutes
        $running = $null
        try {
            $ops = @(Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName -ErrorAction Stop)
            $done = @($ops | Where-Object { $_.ProvisioningState -eq 'Succeeded' }).Count
            $running = @($ops | Where-Object { $_.ProvisioningState -eq 'Running' } | ForEach-Object { ($_.TargetResource -split '/providers/')[-1] }) -join ', '
            Write-PdInfo ("{0}: {1} min, {2} done{3}" -f $Label, $mins, $done, $(if ($running) { "; running: $running" } else { '' }))
        } catch {
            Write-PdInfo ("{0}: {1} min" -f $Label, $mins)
        }
    }
    try {
        $null = Receive-Job -Job $job -ErrorAction Stop
    } catch {
        Write-Host ("   {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $dep = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $DeploymentName -ErrorAction SilentlyContinue
    if (-not $dep -or $dep.ProvisioningState -ne 'Succeeded') {
        Get-PdDeploymentError -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName
        Stop-Pd ("{0} deployment {1} didn't succeed. Fix the cause above, then run the same paste again." -f $Label, $DeploymentName)
    }
    return $dep
}

function Invoke-PersonalDesktopPilot {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # ---------------------------------------------------------------------------------------------------
    # Settings (variables set by the caller win; these are the defaults)
    # ---------------------------------------------------------------------------------------------------
    $c = [ordered]@{
        SubscriptionId               = Get-PdSetting 'SubscriptionId' ''
        ResourceGroupName            = Get-PdSetting 'ResourceGroupName' ''
        Location                     = Get-PdSetting 'Location' 'australiaeast'
        ResourceGroupTags            = Get-PdSetting 'ResourceGroupTags' @{}
        SubnetId                     = Get-PdSetting 'SubnetId' ''
        WorkloadPrefix               = Get-PdSetting 'WorkloadPrefix' ''
        SessionHostNamePrefix        = Get-PdSetting 'SessionHostNamePrefix' ''
        SessionHostCount             = [int](Get-PdSetting 'SessionHostCount' 2)
        VmSize                       = Get-PdSetting 'VmSize' 'Standard_D4as_v5'
        OsDiskType                   = Get-PdSetting 'OsDiskType' 'Premium_LRS'
        OsDiskSizeGB                 = [int](Get-PdSetting 'OsDiskSizeGB' 0)
        DiskControllerType           = Get-PdSetting 'DiskControllerType' ''
        AvailabilityZone             = [string](Get-PdSetting 'AvailabilityZone' '')
        VmTimeZone                   = Get-PdSetting 'VmTimeZone' ''
        JoinType                     = Get-PdSetting 'JoinType' 'EntraID'
        DomainName                   = Get-PdSetting 'DomainName' ''
        DomainJoinOuPath             = Get-PdSetting 'DomainJoinOuPath' ''
        DomainJoinUsername           = Get-PdSetting 'DomainJoinUsername' ''
        EnrollInIntune               = [bool](Get-PdSetting 'EnrollInIntune' $true)
        EntraSingleSignOn            = [bool](Get-PdSetting 'EntraSingleSignOn' $true)
        HybridSingleSignOn           = [bool](Get-PdSetting 'HybridSingleSignOn' $false)
        CustomImageResourceId        = Get-PdSetting 'CustomImageResourceId' ''
        GalleryImageDefinitionId     = Get-PdSetting 'GalleryImageDefinitionId' ''
        GalleryName                  = Get-PdSetting 'GalleryName' ''
        GalleryImageDefinitionName   = Get-PdSetting 'GalleryImageDefinitionName' ''
        MarketplaceImagePublisher    = Get-PdSetting 'MarketplaceImagePublisher' 'MicrosoftWindowsDesktop'
        MarketplaceImageOffer        = Get-PdSetting 'MarketplaceImageOffer' 'windows-11'
        MarketplaceImageSku          = Get-PdSetting 'MarketplaceImageSku' 'win11-24h2-ent'
        MarketplaceImageVersion      = Get-PdSetting 'MarketplaceImageVersion' 'latest'
        PilotUserPrincipalName       = Get-PdSetting 'PilotUserPrincipalName' ''
        PilotUserPrincipalNames      = @(Get-PdSetting 'PilotUserPrincipalNames' @())
        PilotGroupObjectId           = Get-PdSetting 'PilotGroupObjectId' ''
        PilotGroupName               = Get-PdSetting 'PilotGroupName' ''
        AssignUsers                  = @(Get-PdSetting 'AssignUsers' @())
        PersonalDesktopAssignmentType = Get-PdSetting 'PersonalDesktopAssignmentType' 'Automatic'
        StartVMOnConnect             = [bool](Get-PdSetting 'StartVMOnConnect' $true)
        WorkspaceFriendlyName        = Get-PdSetting 'WorkspaceFriendlyName' ''
        DesktopFriendlyName          = Get-PdSetting 'DesktopFriendlyName' ''
        ApplicationGroupFriendlyName = Get-PdSetting 'ApplicationGroupFriendlyName' ''
        HostPoolFriendlyName         = Get-PdSetting 'HostPoolFriendlyName' ''
        LogAnalyticsWorkspaceId      = Get-PdSetting 'LogAnalyticsWorkspaceId' ''
        LogAnalyticsWorkspaceResourceGroupName = Get-PdSetting 'LogAnalyticsWorkspaceResourceGroupName' ''
        EnableAvdInsights            = [bool](Get-PdSetting 'EnableAvdInsights' $true)
        CreateKeyVault               = [bool](Get-PdSetting 'CreateKeyVault' $true)
        KeyVaultNameSeed             = Get-PdSetting 'KeyVaultNameSeed' ''
        KeyVaultPublicNetworkAccess  = Get-PdSetting 'KeyVaultPublicNetworkAccess' 'Enabled'
        EnableAutoscale              = [bool](Get-PdSetting 'EnableAutoscale' $false)
        ScalingPlanTimeZone          = Get-PdSetting 'ScalingPlanTimeZone' 'AUS Eastern Standard Time'
        SupportGroupObjectId         = Get-PdSetting 'SupportGroupObjectId' ''
        LocalAdminUsername           = Get-PdSetting 'LocalAdminUsername' 'avdlocaladmin'
        RdpProperties                = Get-PdSetting 'RdpProperties' ''
        TemplateBaseUri              = Get-PdSetting 'TemplateBaseUri' 'https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/personal'
        TemplateFolder               = Get-PdSetting 'TemplateFolder' ''
        AvdAgentPackageUrl           = Get-PdSetting 'AvdAgentPackageUrl' ''
        ValidateOnly                 = [bool](Get-PdSetting 'ValidateOnly' $false)
        WatchMinutes                 = [int](Get-PdSetting 'WatchMinutes' 25)
    }
    if (-not $c.SessionHostNamePrefix) { $c.SessionHostNamePrefix = $c.WorkloadPrefix }

    Write-Host ''
    Write-Host 'Azure Virtual Desktop personal desktop pilot' -ForegroundColor White
    Write-Host ('Mode: {0}' -f $(if ($c.ValidateOnly) { 'validate only (what-if; only an empty resource group is created if it is missing)' } else { 'deploy' }))

    # Show what will be used, so a variable left over from an earlier paste in the same session is easy to spot.
    Write-PdStep 'Effective settings'
    foreach ($k in $c.Keys) {
        $v = $c[$k]
        if ($v -is [System.Collections.IDictionary]) { $v = ($v.Keys | ForEach-Object { '{0}={1}' -f $_, $v[$_] }) -join '; ' }
        elseif ($v -is [array]) { $v = $v -join ', ' }
        if ($null -ne $v -and "$v" -ne '') { Write-PdInfo ('{0} = {1}' -f $k, $v) }
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Checking the settings'
    foreach ($req in 'SubscriptionId', 'ResourceGroupName', 'SubnetId', 'WorkloadPrefix') {
        if (-not $c[$req]) { Stop-Pd ("Set `${0} first. Nothing has been created." -f $req) }
    }
    if ($c.WorkloadPrefix -cnotmatch '^[a-z][a-z0-9-]{1,9}$') { Stop-Pd 'WorkloadPrefix must be 2 to 10 lowercase letters, digits or hyphens, starting with a letter.' }
    if ($c.SessionHostNamePrefix -notmatch '^[a-zA-Z][a-zA-Z0-9-]{1,10}$') { Stop-Pd 'SessionHostNamePrefix must be 2 to 11 characters (letters, digits, hyphens), so <prefix>-<n> fits the 15-character computer name limit.' }
    if ($c.JoinType -notin @('ActiveDirectory', 'EntraID')) { Stop-Pd "JoinType must be 'ActiveDirectory' or 'EntraID'." }
    if ($c.PersonalDesktopAssignmentType -notin @('Automatic', 'Direct')) { Stop-Pd "PersonalDesktopAssignmentType must be 'Automatic' or 'Direct'." }
    if ($c.SessionHostCount -lt 0 -or $c.SessionHostCount -gt 100) { Stop-Pd 'SessionHostCount must be 0 to 100.' }
    if ($c.SubnetId -notmatch '^/subscriptions/(?<sub>[^/]+)/resourceGroups/(?<rg>[^/]+)/providers/Microsoft\.Network/virtualNetworks/(?<vnet>[^/]+)/subnets/(?<snet>[^/]+)$') {
        Stop-Pd 'SubnetId must be a full subnet resource ID.'
    }
    $subnetParts = $Matches
    if ($c.JoinType -eq 'ActiveDirectory') {
        foreach ($req in 'DomainName', 'DomainJoinUsername') { if (-not $c[$req]) { Stop-Pd ("JoinType ActiveDirectory needs `${0}." -f $req) } }
        if ($c.DomainJoinUsername -match 'PLACEHOLDER|CHANGE-ME') { Stop-Pd 'Replace the placeholder join account in DomainJoinUsername first.' }
        if ($c.DomainJoinOuPath -and $c.DomainJoinOuPath -notmatch '^(OU|CN)=.+,DC=.+') { Stop-Pd 'DomainJoinOuPath should look like OU=Desktops,DC=contoso,DC=com.' }
    }
    if ($c.WorkspaceFriendlyName -eq '') { $c.WorkspaceFriendlyName = ('{0} personal desktops' -f $c.WorkloadPrefix) }
    if ($c.DesktopFriendlyName -eq '') { $c.DesktopFriendlyName = 'Personal desktop' }
    if ($c.ApplicationGroupFriendlyName -eq '') { $c.ApplicationGroupFriendlyName = $c.DesktopFriendlyName }
    if ($c.HostPoolFriendlyName -eq '') { $c.HostPoolFriendlyName = ('{0} personal desktop pool' -f $c.WorkloadPrefix) }
    Write-PdOk ('{0} host pool {1}-hp, session hosts {2}-0 to {2}-{3}' -f $c.JoinType, $c.WorkloadPrefix, $c.SessionHostNamePrefix, ([Math]::Max($c.SessionHostCount - 1, 0)))

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Checking modules and the subscription'
    foreach ($cmd in 'New-AzResourceGroupDeployment', 'New-AzWvdRegistrationInfo', 'Get-AzWvdSessionHost', 'Get-AzComputeResourceSku', 'Get-AzVirtualNetwork', 'Get-AzADServicePrincipal', 'Invoke-AzRestMethod') {
        if (-not (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) { Stop-Pd ("{0} isn't available. Use Azure Cloud Shell (PowerShell), or install the Az modules." -f $cmd) }
    }
    # A new Cloud Shell session picks the tenant's first subscription, so always set it.
    $null = Set-AzContext -Subscription $c.SubscriptionId
    $ctx = Get-AzContext
    Write-PdOk ('Subscription {0} ({1}), signed in as {2}' -f $ctx.Subscription.Name, $ctx.Subscription.Id, $ctx.Account.Id)

    $providers = @('Microsoft.DesktopVirtualization', 'Microsoft.Compute', 'Microsoft.Network')
    if ($c.EnableAvdInsights) { $providers += @('Microsoft.Insights', 'Microsoft.OperationalInsights') }
    if ($c.CreateKeyVault) { $providers += 'Microsoft.KeyVault' }
    foreach ($ns in $providers) {
        $state = @(Get-AzResourceProvider -ProviderNamespace $ns -ErrorAction SilentlyContinue | Select-Object -ExpandProperty RegistrationState -Unique)
        if ($state -notcontains 'Registered') { Stop-Pd ("Resource provider {0} isn't registered in this subscription. Ask the platform team to register it." -f $ns) }
    }
    Write-PdOk ('Providers registered: {0}' -f ($providers -join ', '))

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Resource group'
    $rg = Get-AzResourceGroup -Name $c.ResourceGroupName -ErrorAction SilentlyContinue
    if ($rg) {
        if ((Get-PdNormalisedRegion $rg.Location) -ne (Get-PdNormalisedRegion $c.Location)) {
            Write-PdWarn ('{0} is in {1}, not {2}. Using {1}.' -f $rg.ResourceGroupName, $rg.Location, $c.Location)
        }
        $c.Location = $rg.Location
        Write-PdOk ('{0} exists in {1}' -f $rg.ResourceGroupName, $rg.Location)
    } else {
        # What-if needs a resource group, so validate-only creates the empty, tagged group too (it also proves the tag policy accepts it).
        $tagTable = @{}
        foreach ($k in $c.ResourceGroupTags.Keys) { $tagTable[[string]$k] = [string]$c.ResourceGroupTags[$k] }
        $rg = New-AzResourceGroup -Name $c.ResourceGroupName -Location $c.Location -Tag $tagTable
        Write-PdOk ('Created {0} in {1} with {2} tags' -f $rg.ResourceGroupName, $rg.Location, $tagTable.Count)
    }
    $tags = @{}
    foreach ($k in $c.ResourceGroupTags.Keys) { $tags[[string]$k] = [string]$c.ResourceGroupTags[$k] }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Subnet'
    if ($subnetParts['sub'] -ne $ctx.Subscription.Id) {
        Write-PdWarn 'The subnet is in another subscription, so it isn''t checked here.'
    } else {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $subnetParts['rg'] -Name $subnetParts['vnet'] -ErrorAction SilentlyContinue
        if (-not $vnet) { Stop-Pd ('VNet {0} not found in {1}.' -f $subnetParts['vnet'], $subnetParts['rg']) }
        $snet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetParts['snet'] } | Select-Object -First 1
        if (-not $snet) { Stop-Pd ('Subnet {0} not found in {1}.' -f $subnetParts['snet'], $subnetParts['vnet']) }
        if ((Get-PdNormalisedRegion $vnet.Location) -ne (Get-PdNormalisedRegion $c.Location)) { Stop-Pd ('The VNet is in {0}; session hosts must be in the same region ({1}).' -f $vnet.Location, $c.Location) }
        $prefix = @($snet.AddressPrefix)[0]
        $bits = [int]($prefix -split '/')[1]
        $used = @($snet.IpConfigurations).Count
        $free = [Math]::Pow(2, 32 - $bits) - 5 - $used
        Write-PdOk ('{0} ({1}), about {2} free IPs' -f $snet.Name, $prefix, $free)
        if ($free -lt $c.SessionHostCount) { Stop-Pd 'Not enough free IP addresses in the subnet.' }
        if ($snet.NetworkSecurityGroup) { Write-PdInfo ('NSG: {0}' -f ($snet.NetworkSecurityGroup.Id -split '/')[-1]) }
        if ($snet.RouteTable) { Write-PdInfo ('Route table: {0} (outbound to the AVD required URLs must be allowed on its next hop)' -f ($snet.RouteTable.Id -split '/')[-1]) }
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Image'
    $imageSource = 'Marketplace'
    $galleryVersionId = ''
    $securityType = 'TrustedLaunch'
    $marketplaceImage = @{ publisher = $c.MarketplaceImagePublisher; offer = $c.MarketplaceImageOffer; sku = $c.MarketplaceImageSku; version = $c.MarketplaceImageVersion }
    $definitionId = $c.GalleryImageDefinitionId
    if (-not $c.CustomImageResourceId -and -not $definitionId -and $c.GalleryName -and $c.GalleryImageDefinitionName) {
        $galleries = @(Get-AzResource -ResourceType 'Microsoft.Compute/galleries' -Name $c.GalleryName -ErrorAction SilentlyContinue)
        if ($galleries.Count -eq 0) { Stop-Pd ('Gallery {0} isn''t visible in this subscription. Ask for the image version''s full resource ID and set $CustomImageResourceId.' -f $c.GalleryName) }
        if ($galleries.Count -gt 1) { Stop-Pd ('More than one gallery is called {0}. Set $GalleryImageDefinitionId instead.' -f $c.GalleryName) }
        $definitionId = '{0}/images/{1}' -f $galleries[0].ResourceId, $c.GalleryImageDefinitionName
    }
    if ($c.CustomImageResourceId -or $definitionId) {
        $imageSource = 'Gallery'
        if ($c.CustomImageResourceId) {
            $galleryVersionId = $c.CustomImageResourceId
            $definitionId = ($galleryVersionId -replace '/versions/[^/]+$', '')
        }
        $def = Get-PdArmJson -Path ('{0}?api-version=2023-07-03' -f $definitionId)
        if (-not $def) { Stop-Pd ('Image definition not found: {0}' -f $definitionId) }
        if (-not $galleryVersionId) {
            $vers = Get-PdArmJson -Path ('{0}/versions?api-version=2023-07-03' -f $definitionId)
            $ok = @($vers.value | Where-Object { $_.properties.provisioningState -eq 'Succeeded' -and -not $_.properties.publishingProfile.excludeFromLatest })
            if ($ok.Count -eq 0) { Stop-Pd ('No published version of {0}. Ask for the image version, then run again.' -f ($definitionId -split '/')[-1]) }
            $latest = $ok | Sort-Object { [version]$_.name } | Select-Object -Last 1
            $galleryVersionId = $latest.id
        }
        $ver = Get-PdArmJson -Path ('{0}?api-version=2023-07-03' -f $galleryVersionId)
        if (-not $ver) { Stop-Pd ('Image version not found: {0}' -f $galleryVersionId) }
        if ($ver.properties.provisioningState -ne 'Succeeded') { Stop-Pd ('Image version {0} is {1}.' -f $ver.name, $ver.properties.provisioningState) }
        $regions = @($ver.properties.publishingProfile.targetRegions | ForEach-Object { Get-PdNormalisedRegion $_.name })
        if ($regions -notcontains (Get-PdNormalisedRegion $c.Location)) { Stop-Pd ('Image version {0} isn''t replicated to {1}.' -f $ver.name, $c.Location) }
        if ($def.properties.osType -ne 'Windows') { Stop-Pd 'The image isn''t Windows.' }
        if ($def.properties.osState -ne 'Generalized') { Stop-Pd 'The image is Specialized. Session hosts need a Generalized image.' }
        $sec = Get-PdFeature -Features $def.properties.features -Name 'SecurityType'
        $gen = $def.properties.hyperVGeneration
        if ($gen -eq 'V2' -and $sec -match 'TrustedLaunch') { $securityType = 'TrustedLaunch' }
        elseif ($sec -match 'Confidential') { Stop-Pd ('Image security type {0} needs confidential VM sizes; this script doesn''t build those.' -f $sec) }
        else { $securityType = 'Standard'; Write-PdWarn ('Image is {0} with security type {1}: the VMs will be Standard, not Trusted launch.' -f $gen, $(if ($sec) { $sec } else { 'Standard' })) }
        $controllers = Get-PdFeature -Features $def.properties.features -Name 'DiskControllerTypes'
        Write-PdOk ('Gallery image {0} version {1} (Generation {2}, security type {3}{4})' -f ($definitionId -split '/')[-1], $ver.name, $gen, $(if ($sec) { $sec } else { 'Standard' }), $(if ($controllers) { ", disk controllers $controllers" } else { '' }))
    } else {
        $versions = @(Get-AzVMImage -Location $c.Location -PublisherName $c.MarketplaceImagePublisher -Offer $c.MarketplaceImageOffer -Skus $c.MarketplaceImageSku -ErrorAction SilentlyContinue)
        if ($versions.Count -eq 0) {
            $skus = @(Get-AzVMImageSku -Location $c.Location -PublisherName $c.MarketplaceImagePublisher -Offer $c.MarketplaceImageOffer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Skus)
            Stop-Pd ('Marketplace image {0}/{1}/{2} not found in {3}. Available SKUs include: {4}' -f $c.MarketplaceImagePublisher, $c.MarketplaceImageOffer, $c.MarketplaceImageSku, $c.Location, (($skus | Where-Object { $_ -like 'win11*' }) -join ', '))
        }
        $newest = $versions | Sort-Object { [version]$_.Version } | Select-Object -Last 1
        if ($c.MarketplaceImageVersion -eq 'latest') { $marketplaceImage.version = $newest.Version }
        Write-PdOk ('Marketplace image {0}/{1}/{2}, version {3}' -f $c.MarketplaceImagePublisher, $c.MarketplaceImageOffer, $c.MarketplaceImageSku, $marketplaceImage.version)
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'VM size and quota'
    try {
        $allSkus = @(Get-AzComputeResourceSku -Location $c.Location -ErrorAction Stop)
    } catch {
        # Older Az.Compute versions have no -Location parameter.
        $allSkus = @(Get-AzComputeResourceSku | Where-Object { $_.Locations -contains $c.Location })
    }
    $sku = $allSkus | Where-Object { $_.ResourceType -eq 'virtualMachines' -and $_.Name -eq $c.VmSize } | Select-Object -First 1
    if (-not $sku) { Stop-Pd ('{0} isn''t offered in {1}.' -f $c.VmSize, $c.Location) }
    $blocked = @($sku.Restrictions | Where-Object { $_.ReasonCode -eq 'NotAvailableForSubscription' })
    if ($blocked.Count -gt 0) { Stop-Pd ('{0} is restricted for this subscription in {1}.' -f $c.VmSize, $c.Location) }
    $cap = @{}
    foreach ($cp in @($sku.Capabilities)) { $cap[$cp.Name] = $cp.Value }
    $vcpus = [int]$cap['vCPUs']
    $accelNet = ($cap['AcceleratedNetworkingEnabled'] -eq 'True')
    if ($securityType -eq 'TrustedLaunch' -and $cap['TrustedLaunchDisabled'] -eq 'True') { Stop-Pd ('{0} doesn''t support Trusted launch.' -f $c.VmSize) }
    if ($cap['HyperVGenerations'] -and $cap['HyperVGenerations'] -notmatch 'V2') { Stop-Pd ('{0} doesn''t support Generation 2 VMs.' -f $c.VmSize) }
    if ($c.OsDiskType -like 'Premium*' -and $cap['PremiumIO'] -ne 'True') { Stop-Pd ('{0} doesn''t support Premium SSD. Pick an "s" size or set $OsDiskType = ''StandardSSD_LRS''.' -f $c.VmSize) }
    Write-PdOk ('{0}: {1} vCPUs, {2} GB, accelerated networking {3}, family {4}' -f $c.VmSize, $vcpus, $cap['MemoryGB'], $accelNet, $sku.Family)

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Existing session hosts'
    $existing = @{}
    if ($rg) {
        foreach ($vm in @(Get-AzVM -ResourceGroupName $c.ResourceGroupName -ErrorAction SilentlyContinue)) {
            $m = [regex]::Match($vm.Name, ('^{0}-(\d+)$' -f [regex]::Escape($c.SessionHostNamePrefix)))
            if ($m.Success) { $existing[[int]$m.Groups[1].Value] = $vm.Name }
        }
    }
    $missing = @(0..([Math]::Max($c.SessionHostCount - 1, 0)) | Where-Object { $c.SessionHostCount -gt 0 -and -not $existing.ContainsKey($_) })
    if ($existing.Count -gt 0) { Write-PdInfo ('Already there: {0}' -f (($existing.Values | Sort-Object) -join ', ')) }
    Write-PdOk ('To create: {0}' -f $(if ($missing.Count) { ($missing | ForEach-Object { '{0}-{1}' -f $c.SessionHostNamePrefix, $_ }) -join ', ' } else { 'none' }))

    $usage = Get-AzVMUsage -Location $c.Location | Where-Object { $_.Name.Value -eq $sku.Family } | Select-Object -First 1
    $need = $vcpus * $missing.Count
    if ($usage) {
        $freeCores = $usage.Limit - $usage.CurrentValue
        Write-PdOk ('Quota {0}: {1} of {2} vCPUs used, {3} needed' -f $sku.Family, $usage.CurrentValue, $usage.Limit, $need)
        if ($need -gt $freeCores) { Stop-Pd ('Not enough {0} quota in {1}. Request more, or pick a size from a family with quota (for example Standard_D4as_v5).' -f $sku.Family, $c.Location) }
    } else {
        Write-PdWarn ('Couldn''t read quota for {0}.' -f $sku.Family)
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Users, groups and service principals'
    $userIds = New-Object System.Collections.Generic.List[string]
    $upns = @()
    if ($c.PilotUserPrincipalName) { $upns += $c.PilotUserPrincipalName }
    $upns += @($c.PilotUserPrincipalNames | Where-Object { $_ })
    foreach ($upn in ($upns | Select-Object -Unique)) {
        $u = Get-AzADUser -UserPrincipalName $upn -ErrorAction SilentlyContinue
        if (-not $u) { Stop-Pd ('User {0} not found in this tenant.' -f $upn) }
        $userIds.Add($u.Id)
        Write-PdOk ('User {0}' -f $upn)
    }
    $groupIds = New-Object System.Collections.Generic.List[string]
    if ($c.PilotGroupObjectId) {
        $groupIds.Add($c.PilotGroupObjectId)
        Write-PdOk ('Group {0}' -f $c.PilotGroupObjectId)
    } elseif ($c.PilotGroupName) {
        $g = @(Get-AzADGroup -DisplayName $c.PilotGroupName -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $c.PilotGroupName })
        if ($g.Count -ne 1) { Stop-Pd ('Found {0} groups called {1}. Set $PilotGroupObjectId instead.' -f $g.Count, $c.PilotGroupName) }
        $groupIds.Add($g[0].Id)
        Write-PdOk ('Group {0} ({1})' -f $g[0].DisplayName, $g[0].Id)
    }
    if ($userIds.Count -eq 0 -and $groupIds.Count -eq 0) { Write-PdWarn 'No users or groups given: nobody will see the desktop until you assign Desktop Virtualization User.' }

    $avdSp = Get-AzADServicePrincipal -ApplicationId '9cdead84-a844-4324-93f2-b2e6bb768d07' -ErrorAction SilentlyContinue
    $avdSpId = ''
    if ($avdSp) { $avdSpId = $avdSp.Id; Write-PdOk ('Azure Virtual Desktop service principal {0}' -f $avdSpId) }
    else { Write-PdWarn 'Azure Virtual Desktop service principal not found: Start VM on Connect won''t get its role.' }

    $me = $null
    try { $me = Get-AzADUser -SignedIn -ErrorAction Stop } catch { $me = $null }
    $meId = ''
    if ($me) { $meId = $me.Id; Write-PdOk ('Key Vault Secrets Officer will go to {0}' -f $me.UserPrincipalName) }
    elseif ($c.CreateKeyVault) { Write-PdWarn 'Couldn''t resolve the signed-in user: no Key Vault Secrets Officer assignment.' }

    $lawId = $c.LogAnalyticsWorkspaceId
    if (-not $lawId -and $c.LogAnalyticsWorkspaceResourceGroupName -and $c.EnableAvdInsights) {
        $law = @(Get-AzResource -ResourceGroupName $c.LogAnalyticsWorkspaceResourceGroupName -ResourceType 'Microsoft.OperationalInsights/workspaces' -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($law) { $lawId = $law.ResourceId; Write-PdOk ('Log Analytics workspace {0}' -f $law.Name) }
        else { Write-PdWarn ('No Log Analytics workspace in {0}: a new one is created.' -f $c.LogAnalyticsWorkspaceResourceGroupName) }
    } elseif ($lawId) {
        Write-PdOk ('Log Analytics workspace {0}' -f ($lawId -split '/')[-1])
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Azure Virtual Desktop agent package'
    $pkg = $null
    if ($missing.Count -gt 0 -or $c.ValidateOnly) {
        $pkg = Resolve-PdAvdAgentPackage -OverrideUrl $c.AvdAgentPackageUrl
        Write-PdOk ('{0}' -f $pkg.Url)
        Write-PdInfo ('AddSessionHost parameters: {0}' -f $pkg.ParameterNames)
        Write-PdInfo ('Token passed as {0}; agent bundled: {1}' -f $pkg.TokenMode, $pkg.AgentBundled)
    } else {
        Write-PdInfo 'Not needed: no session hosts to create.'
    }

    # ---------------------------------------------------------------------------------------------------
    $rdp = $c.RdpProperties
    if (-not $rdp) {
        $rdp = 'drivestoredirect:s:;usbdevicestoredirect:s:;devicestoredirect:s:;redirectcomports:i:0;redirectclipboard:i:1;redirectprinters:i:1;redirectsmartcards:i:1;redirectwebauthn:i:1;audiomode:i:0;audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:1;enablecredsspsupport:i:1;autoreconnection enabled:i:1;'
        if ($c.JoinType -eq 'EntraID') {
            if ($c.EntraSingleSignOn) { $rdp += 'enablerdsaadauth:i:1;' } else { $rdp += 'targetisaadjoined:i:1;' }
        } elseif ($c.HybridSingleSignOn) {
            $rdp += 'enablerdsaadauth:i:1;'
        }
    }

    $templateSource = @{}
    $hostTemplateSource = @{}
    if ($c.TemplateFolder) {
        $templateSource = @{ TemplateFile = (Join-Path $c.TemplateFolder 'hostpool.json') }
        $hostTemplateSource = @{ TemplateFile = (Join-Path $c.TemplateFolder 'sessionhosts.json') }
    } else {
        $templateSource = @{ TemplateUri = ('{0}/hostpool.json' -f $c.TemplateBaseUri.TrimEnd('/')) }
        $hostTemplateSource = @{ TemplateUri = ('{0}/sessionhosts.json' -f $c.TemplateBaseUri.TrimEnd('/')) }
    }

    $coreParams = @{
        location                           = $c.Location
        workloadPrefix                     = $c.WorkloadPrefix
        tags                               = $tags
        hostPoolFriendlyName               = $c.HostPoolFriendlyName
        applicationGroupFriendlyName       = $c.ApplicationGroupFriendlyName
        workspaceFriendlyName              = $c.WorkspaceFriendlyName
        personalDesktopAssignmentType      = $c.PersonalDesktopAssignmentType
        startVMOnConnect                   = $c.StartVMOnConnect
        customRdpProperty                  = $rdp
        avdServicePrincipalObjectId        = $avdSpId
        userGroupObjectIds                 = [string[]]@($groupIds)
        userObjectIds                      = [string[]]@($userIds)
        grantVirtualMachineUserLogin       = ($c.JoinType -eq 'EntraID')
        supportGroupObjectId               = $c.SupportGroupObjectId
        logAnalyticsWorkspaceResourceId    = $lawId
        enableDiagnostics                  = $c.EnableAvdInsights
        createAvdInsightsDataCollectionRule = $c.EnableAvdInsights
        createKeyVault                     = $c.CreateKeyVault
        keyVaultSecretsOfficerObjectId     = $meId
        keyVaultPublicNetworkAccess        = $c.KeyVaultPublicNetworkAccess
        keyVaultNameSeed                   = $c.KeyVaultNameSeed
        enableScalingPlan                  = $c.EnableAutoscale
        scalingPlanTimeZone                = $c.ScalingPlanTimeZone
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # ---------------------------------------------------------------------------------------------------
    if ($c.ValidateOnly) {
        Write-PdStep 'What-if (nothing is changed)'
        $wi = Get-AzResourceGroupDeploymentWhatIfResult -ResourceGroupName $c.ResourceGroupName @templateSource -TemplateParameterObject $coreParams
        $wi.Changes | Group-Object ChangeType | ForEach-Object { Write-PdInfo ('hostpool.json: {0} x {1}' -f $_.Count, $_.Name) }
        if ($missing.Count -gt 0) {
            $whatIfHosts = @{
                location = $c.Location; tags = $tags; vmNamePrefix = $c.SessionHostNamePrefix; vmStartIndex = [int]$missing[0]; vmCount = 1
                vmSize = $c.VmSize; subnetResourceId = $c.SubnetId; enableAcceleratedNetworking = $accelNet
                imageSource = $imageSource; marketplaceImage = $marketplaceImage; galleryImageVersionResourceId = $galleryVersionId
                securityType = $securityType; osDiskType = $c.OsDiskType; osDiskSizeGB = $c.OsDiskSizeGB; diskControllerType = $c.DiskControllerType
                availabilityZone = $c.AvailabilityZone; timeZone = $c.VmTimeZone; localAdminUsername = $c.LocalAdminUsername
                localAdminPassword = (ConvertTo-PdSecure (New-PdPassword)); joinType = $c.JoinType
                domainName = $c.DomainName; domainJoinOuPath = $c.DomainJoinOuPath; domainJoinUsername = $c.DomainJoinUsername
                domainJoinPassword = (ConvertTo-PdSecure 'what-if-placeholder'); enrollInIntune = $c.EnrollInIntune
                hostPoolName = ('{0}-hp' -f $c.WorkloadPrefix); hostPoolRegistrationToken = (ConvertTo-PdSecure 'what-if-placeholder')
                avdAgentDscPackageUrl = $pkg.Url; avdAgentDscTokenMode = $pkg.TokenMode; avdAgentDscPassAadJoin = $pkg.PassAadJoin
                avdAgentDscExtraArguments = $pkg.ExtraArguments; installAzureMonitorAgent = $c.EnableAvdInsights
            }
            $wi2 = Get-AzResourceGroupDeploymentWhatIfResult -ResourceGroupName $c.ResourceGroupName @hostTemplateSource -TemplateParameterObject $whatIfHosts
            $wi2.Changes | Group-Object ChangeType | ForEach-Object { Write-PdInfo ('sessionhosts.json (1 host): {0} x {1}' -f $_.Count, $_.Name) }
        }
        Write-PdOk 'Both templates validated. Set $ValidateOnly = $false (or remove it) and paste again to deploy.'
        return
    }

    # ---------------------------------------------------------------------------------------------------
    # Ask for the join account password before anything is built, so a blank answer costs nothing.
    $joinPassword = $null
    if ($c.JoinType -eq 'ActiveDirectory' -and $missing.Count -gt 0) {
        Write-PdStep 'Domain join account'
        $joinPassword = Read-Host -AsSecureString -Prompt ('Password for {0}' -f $c.DomainJoinUsername)
        if ($null -eq $joinPassword -or $joinPassword.Length -eq 0) { Stop-Pd 'No password entered. Nothing has been created.' }
        Write-PdOk 'Password captured (not shown, not stored).'
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Deploying the host pool, application group, workspace, access and monitoring (hostpool.json)'
    $core = Invoke-PdDeployment -ResourceGroupName $c.ResourceGroupName -DeploymentName ('personal-core-{0}' -f $stamp) -TemplateSource $templateSource -Parameters $coreParams -Label 'hostpool.json'
    $hpName = $core.Outputs['hostPoolName'].Value
    $agName = $core.Outputs['applicationGroupName'].Value
    $wsName = $core.Outputs['workspaceName'].Value
    $kvName = [string]$core.Outputs['keyVaultName'].Value
    $dcrId = [string]$core.Outputs['dataCollectionRuleResourceId'].Value
    Write-PdOk ('Host pool {0}, application group {1}, workspace {2}' -f $hpName, $agName, $wsName)
    if ($kvName) { Write-PdOk ('Key Vault {0}' -f $kvName) }

    # The desktop object has no writable properties in the template, so set its display name here.
    try {
        $desk = @(Get-AzWvdDesktop -ResourceGroupName $c.ResourceGroupName -ApplicationGroupName $agName) | Select-Object -First 1
        $null = Update-AzWvdDesktop -ResourceGroupName $c.ResourceGroupName -ApplicationGroupName $agName -Name (("$($desk.Name)" -split '/')[-1]) -FriendlyName $c.DesktopFriendlyName
        Write-PdOk ('Desktop tile: {0}' -f $c.DesktopFriendlyName)
    } catch {
        Write-PdWarn ('Couldn''t set the desktop display name: {0}' -f $_.Exception.Message)
    }

    # ---------------------------------------------------------------------------------------------------
    if ($missing.Count -gt 0) {
        Write-PdStep 'Registration token and local administrator password'
        $reg = New-AzWvdRegistrationInfo -ResourceGroupName $c.ResourceGroupName -HostPoolName $hpName -ExpirationTime ((Get-Date).ToUniversalTime().AddHours(8))
        if (-not $reg.Token) { Stop-Pd 'The host pool didn''t return a registration token.' }
        Write-PdOk ('Token valid until {0:u}' -f $reg.ExpirationTime)
        $adminPlain = New-PdPassword
        Write-Host ''
        Write-Host '   Save this now (shown once). Local administrator for the new session hosts:' -ForegroundColor Yellow
        Write-Host ('     User:     {0}' -f $c.LocalAdminUsername) -ForegroundColor Yellow
        Write-Host ('     Password: {0}' -f $adminPlain) -ForegroundColor Yellow
        if ($kvName) { Write-Host ('     Also stored in Key Vault {0} as <vm-name>-localadmin.' -f $kvName) -ForegroundColor Yellow }
        Write-Host ''
        Write-Host '   Press Enter every few minutes while this runs: Cloud Shell ends idle sessions after 20 minutes.' -ForegroundColor Yellow
        Write-Host '   If the session drops, the deployment carries on in Azure; paste again later to pick up where it is.' -ForegroundColor Yellow

        # Contiguous runs of missing indexes become one deployment each.
        $runs = New-Object System.Collections.Generic.List[object]
        $runStart = $missing[0]; $prev = $missing[0]
        foreach ($idx in ($missing | Select-Object -Skip 1)) {
            if ($idx -ne $prev + 1) { $runs.Add(@($runStart, ($prev - $runStart + 1))); $runStart = $idx }
            $prev = $idx
        }
        $runs.Add(@($runStart, ($prev - $runStart + 1)))

        $n = 0
        foreach ($run in $runs) {
            $n++
            Write-PdStep ('Deploying session hosts {0}-{1} to {0}-{2} (sessionhosts.json)' -f $c.SessionHostNamePrefix, $run[0], ($run[0] + $run[1] - 1))
            $hostParams = @{
                location                      = $c.Location
                tags                          = $tags
                vmNamePrefix                  = $c.SessionHostNamePrefix
                vmStartIndex                  = [int]$run[0]
                vmCount                       = [int]$run[1]
                vmSize                        = $c.VmSize
                subnetResourceId              = $c.SubnetId
                enableAcceleratedNetworking   = $accelNet
                imageSource                   = $imageSource
                marketplaceImage              = $marketplaceImage
                galleryImageVersionResourceId = $galleryVersionId
                securityType                  = $securityType
                osDiskType                    = $c.OsDiskType
                osDiskSizeGB                  = $c.OsDiskSizeGB
                diskControllerType            = $c.DiskControllerType
                availabilityZone              = $c.AvailabilityZone
                timeZone                      = $c.VmTimeZone
                localAdminUsername            = $c.LocalAdminUsername
                localAdminPassword            = (ConvertTo-PdSecure $adminPlain)
                keyVaultName                  = $kvName
                joinType                      = $c.JoinType
                enrollInIntune                = $c.EnrollInIntune
                hostPoolName                  = $hpName
                hostPoolRegistrationToken     = (ConvertTo-PdSecure $reg.Token)
                avdAgentDscPackageUrl         = $pkg.Url
                avdAgentDscTokenMode          = $pkg.TokenMode
                avdAgentDscPassAadJoin        = $pkg.PassAadJoin
                avdAgentDscExtraArguments     = $pkg.ExtraArguments
                installAzureMonitorAgent      = $c.EnableAvdInsights
                dataCollectionRuleResourceId  = $dcrId
            }
            if ($c.JoinType -eq 'ActiveDirectory') {
                $hostParams['domainName'] = $c.DomainName
                $hostParams['domainJoinOuPath'] = $c.DomainJoinOuPath
                $hostParams['domainJoinUsername'] = $c.DomainJoinUsername
                $hostParams['domainJoinPassword'] = $joinPassword
            }
            $null = Invoke-PdDeployment -ResourceGroupName $c.ResourceGroupName -DeploymentName ('personal-hosts-{0}-{1}' -f $stamp, $n) -TemplateSource $hostTemplateSource -Parameters $hostParams -Label 'sessionhosts.json'
            Write-PdOk 'Session hosts deployed.'
        }
        $adminPlain = $null
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Waiting for the session hosts to be Available'
    $expected = @()
    if ($c.SessionHostCount -gt 0) { $expected = @(0..($c.SessionHostCount - 1) | ForEach-Object { '{0}-{1}' -f $c.SessionHostNamePrefix, $_ }) }
    $deadline = (Get-Date).AddMinutes($c.WatchMinutes)
    $hosts = @()
    $allOk = $true
    if ($expected.Count -gt 0) { do {
        $hosts = @(Get-AzWvdSessionHost -ResourceGroupName $c.ResourceGroupName -HostPoolName $hpName -ErrorAction SilentlyContinue)
        $states = foreach ($vmName in $expected) {
            $sh = $hosts | Where-Object { (($_.Name -split '/')[-1]) -match ('^{0}(\.|$)' -f [regex]::Escape($vmName)) } | Select-Object -First 1
            if ($sh) { '{0}={1}' -f $vmName, $sh.Status } else { '{0}=not registered' -f $vmName }
        }
        $allOk = @($states | Where-Object { $_ -notmatch '=Available$' }).Count -eq 0
        Write-PdInfo (($states -join '; '))
        if ($allOk) { break }
        Start-Sleep -Seconds 30
    } while ((Get-Date) -lt $deadline) } else { $hosts = @(Get-AzWvdSessionHost -ResourceGroupName $c.ResourceGroupName -HostPoolName $hpName -ErrorAction SilentlyContinue) }
    if ($allOk) { Write-PdOk 'All session hosts are Available.' }
    else {
        Write-PdWarn ('Not all session hosts are Available after {0} minutes. See "If a host doesn''t register" in the README.' -f $c.WatchMinutes)
        $unregistered = @($states | Where-Object { $_ -match '=not registered$' } | ForEach-Object { ($_ -split '=')[0] })
        if ($unregistered.Count -gt 0) {
            Write-PdInfo 'A host that never registers usually means the join or the agent install failed. Check the extension status first:'
            foreach ($vmName in $unregistered) { Write-PdInfo ('  Get-AzVM -ResourceGroupName {0} -Name {1} -Status | Select-Object -ExpandProperty Extensions' -f $c.ResourceGroupName, $vmName) }
            Write-PdInfo 'To rebuild one, delete the VM (its NIC and OS disk go with it), then paste again. For example:'
            Write-PdInfo ('  Remove-AzVM -ResourceGroupName {0} -Name {1}' -f $c.ResourceGroupName, $unregistered[0])
        }
    }

    # ---------------------------------------------------------------------------------------------------
    if ($c.AssignUsers.Count -gt 0) {
        Write-PdStep 'Assigning users to personal desktops'
        $sorted = @($hosts | Sort-Object { [int](([regex]::Match((($_.Name -split '/')[-1]), '-(\d+)(\.|$)')).Groups[1].Value) })
        $i = 0
        foreach ($upn in $c.AssignUsers) {
            if ($i -ge $sorted.Count) { Write-PdWarn ('No desktop left for {0}.' -f $upn); continue }
            $sh = $sorted[$i]; $i++
            $shName = ($sh.Name -split '/')[-1]
            if ($sh.AssignedUser) { Write-PdInfo ('{0} is already assigned to {1}' -f $shName, $sh.AssignedUser); continue }
            try {
                $null = Update-AzWvdSessionHost -ResourceGroupName $c.ResourceGroupName -HostPoolName $hpName -Name $shName -AssignedUser $upn
                Write-PdOk ('{0} -> {1}' -f $shName, $upn)
            } catch { Write-PdWarn ('Couldn''t assign {0} to {1}: {2}' -f $upn, $shName, $_.Exception.Message) }
        }
    }

    # ---------------------------------------------------------------------------------------------------
    Write-PdStep 'Done'
    Write-PdOk ('Workspace in Windows App: {0}  |  Desktop: {1}' -f $c.WorkspaceFriendlyName, $c.DesktopFriendlyName)
    Write-PdInfo ('Resource group {0}: host pool {1}, {2} session host(s).' -f $c.ResourceGroupName, $hpName, $c.SessionHostCount)
    if ($c.JoinType -eq 'EntraID') {
        Write-PdInfo 'Next: check the hosts in Intune (Devices > Windows), then assign the personal desktop Intune policies.'
        if ($c.EntraSingleSignOn) { Write-PdInfo 'Single sign-on is on (enablerdsaadauth). Users see a one-time consent prompt per host.' }
    } else {
        Write-PdInfo 'Next: sign in with AD credentials at the host prompt. Single sign-on needs Microsoft Entra hybrid join and a Kerberos server object.'
    }
}

Invoke-PersonalDesktopPilot
