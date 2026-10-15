<#
.SYNOPSIS
Read-only readiness check for a pooled Azure Virtual Desktop deployment.

.DESCRIPTION
Reads a subscription and reports what a North Star deployment needs to know before
it runs: the region and compute quota, an existing session host subnet, private DNS
zones, existing AVD, storage and Key Vault resources, and the Azure Policy
assignments that most often block a deployment. It changes nothing: every call is a
Get. It is generic and contains no customer values.

Set the values below in the session first, then pipe the script into iex. Nothing is
hard-coded, so the script is safe to publish.

.EXAMPLE
$SubscriptionId = '00000000-0000-0000-0000-000000000000'
$VnetName = 'my-vnet'
$SubnetName = 'my-subnet'
irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/scripts/Test-LandingZoneReadiness.ps1 | iex
#>

$ErrorActionPreference = 'Stop'
$Location = if ($Location) { $Location } else { 'australiaeast' }

function Head($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }
function Line($k, $v) { Write-Host ("  {0,-22} {1}" -f $k, $v) }

if ($SubscriptionId) { $null = Set-AzContext -Subscription $SubscriptionId -WarningAction SilentlyContinue }
$ctx = Get-AzContext
Head 'Subscription'
Line 'Name' $ctx.Subscription.Name
Line 'Id' $ctx.Subscription.Id
Line 'Tenant' $ctx.Tenant.Id
Line 'Signed in as' $ctx.Account.Id
Line 'Region checked' $Location
$subScope = "/subscriptions/$($ctx.Subscription.Id)"

Head 'Compute quota in the region'
try {
    $usage = Get-AzVMUsage -Location $Location
    $total = $usage | Where-Object { $_.Name.Value -eq 'cores' }
    if ($total) { Line 'Total regional vCPUs' ("{0} used of {1}" -f $total.CurrentValue, $total.Limit) }
    foreach ($fam in 'standardDADSv5Family', 'standardDASv5Family', 'standardDasv6Family', 'standardEADSv5Family', 'standardEASv5Family') {
        $f = $usage | Where-Object { $_.Name.Value -eq $fam }
        if ($f -and $f.Limit -gt 0) { Line $f.Name.LocalizedValue ("{0} used of {1}" -f $f.CurrentValue, $f.Limit) }
    }
} catch { Line 'Quota' "could not read ($($_.Exception.Message))" }

Head 'Session host subnet'
try {
    $vnets = if ($VnetName) { @(Get-AzVirtualNetwork -Name $VnetName) } else { Get-AzVirtualNetwork }
    if (-not $vnets) { Line 'VNets' 'none found (check the name or your access)' }
    foreach ($vnet in $vnets) {
        $subnets = if ($SubnetName) { $vnet.Subnets | Where-Object Name -eq $SubnetName } else { $vnet.Subnets }
        foreach ($sn in $subnets) {
            $prefix = ($sn.AddressPrefix -join ',')
            $bits = [int]($prefix -replace '.*/', '')
            $size = [math]::Pow(2, 32 - $bits)
            $used = @($sn.IpConfigurations).Count
            $free = [int]$size - 5 - $used
            Write-Host ("  {0} / {1}" -f $vnet.Name, $sn.Name) -ForegroundColor White
            Line '  resource group' $vnet.ResourceGroupName
            Line '  location' $vnet.Location
            Line '  address prefix' $prefix
            Line '  free IPs (approx)' $free
            Line '  NSG' ($(if ($sn.NetworkSecurityGroup) { ($sn.NetworkSecurityGroup.Id -split '/')[-1] } else { 'none' }))
            Line '  route table' ($(if ($sn.RouteTable) { ($sn.RouteTable.Id -split '/')[-1] } else { 'none' }))
            Line '  private endpoints' (@($sn.PrivateEndpoints).Count)
            Line '  resource id' $sn.Id
        }
    }
} catch { Line 'Subnet' "could not read ($($_.Exception.Message))" }

Head 'Private DNS zones (for a storage private endpoint)'
try {
    $zones = Get-AzPrivateDnsZone -ErrorAction Stop
    foreach ($want in 'privatelink.file.core.windows.net', 'privatelink.vaultcore.azure.net') {
        $have = $zones | Where-Object Name -eq $want
        Line $want ($(if ($have) { "present in RG $($have[0].ResourceGroupName)" } else { 'not found' }))
    }
} catch { Line 'Private DNS' "could not read ($($_.Exception.Message))" }

Head 'Already in this subscription'
foreach ($t in @(
        @{ n = 'AVD host pools'; type = 'Microsoft.DesktopVirtualization/hostpools' },
        @{ n = 'AVD workspaces'; type = 'Microsoft.DesktopVirtualization/workspaces' },
        @{ n = 'Storage accounts'; type = 'Microsoft.Storage/storageAccounts' },
        @{ n = 'Key vaults'; type = 'Microsoft.KeyVault/vaults' },
        @{ n = 'Compute galleries'; type = 'Microsoft.Compute/galleries' })) {
    try {
        $r = Get-AzResource -ResourceType $t.type
        $names = (@($r) | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', '
        Line $t.n ("{0}{1}" -f @($r).Count, $(if ($names) { " ($names)" } else { '' }))
    } catch { Line $t.n 'could not read' }
}

Head 'Resource groups (naming convention)'
try {
    $rgs = Get-AzResourceGroup
    Line 'Count' @($rgs).Count
    Line 'Examples' ((@($rgs) | Select-Object -First 6 | ForEach-Object { $_.ResourceGroupName }) -join ', ')
    $tagged = @($rgs) | Where-Object { $_.Tags -and $_.Tags.Count -gt 0 } | Select-Object -First 1
    if ($tagged) { Line 'Tags seen on an RG' (($tagged.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ') }
} catch { Line 'Resource groups' 'could not read' }

Head 'Policy assignments that could block a deploy'
try {
    # Read a property from either the new flat model or the older .Properties model.
    function P($o, $name) { if ($null -ne $o.$name) { return $o.$name } elseif ($o.Properties) { return $o.Properties.$name } else { return $null } }
    $defCache = @{}
    function Get-Effect($a) {
        $defId = P $a 'PolicyDefinitionId'
        if (-not $defId) { return '?' }
        if ($defId -match '/policySetDefinitions/') { return 'initiative (review)' }
        if (-not $defCache.ContainsKey($defId)) {
            try { $defCache[$defId] = Get-AzPolicyDefinition -Id $defId } catch { $defCache[$defId] = $null }
        }
        $def = $defCache[$defId]
        if (-not $def) { return '?' }
        $rule = P $def 'PolicyRule'
        $eff = $rule.then.effect
        if ($eff -is [string] -and $eff -notmatch '^\[') { return $eff }
        $pname = ($eff -replace ".*parameters\('", '' -replace "'.*", '')
        $params = P $a 'Parameter'; if (-not $params) { $params = P $a 'Parameters' }
        $pv = $params.$pname.value
        if ($pv) { return $pv }
        $dparams = P $def 'Parameter'; if (-not $dparams) { $dparams = P $def 'Parameters' }
        $pd = $dparams.$pname.defaultValue
        if ($pd) { return "$pd (default)" }
        return 'parameterised'
    }
    $assigns = Get-AzPolicyAssignment -Scope $subScope
    $blockers = @()
    foreach ($a in $assigns) {
        try {
            $eff = Get-Effect $a
            if ($eff -match 'deny|modify|append|DeployIfNotExists|initiative') {
                $blockers += [pscustomobject]@{ Effect = $eff; Name = (P $a 'DisplayName'); Enforce = (P $a 'EnforcementMode') }
            }
        } catch { }
    }
    Line 'Total assignments' @($assigns).Count
    Line 'Deny/Modify/etc' @($blockers).Count
    foreach ($b in ($blockers | Sort-Object Effect)) {
        Write-Host ("  [{0}] {1}{2}" -f $b.Effect, $b.Name, $(if ($b.Enforce -eq 'DoNotEnforce') { ' (not enforced)' } else { '' })) -ForegroundColor Yellow
    }
} catch { Line 'Policy' "could not read ($($_.Exception.Message))" }

Head 'Done'
Write-Host '  Read-only check complete. Nothing was changed.' -ForegroundColor Green
