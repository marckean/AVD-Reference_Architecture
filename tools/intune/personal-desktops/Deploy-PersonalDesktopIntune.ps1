<#
.SYNOPSIS
    Creates an Intune starter set for Azure Virtual Desktop personal desktops (Microsoft Entra joined):
    compliance, Windows LAPS, session clipboard direction, session time limits, an update ring,
    Microsoft 365 Apps, trusted certificates and, optionally, screen capture protection.

.DESCRIPTION
    Built for Azure Cloud Shell (PowerShell) or any PowerShell 7.2+ session with the Microsoft Graph
    PowerShell Authentication module. There's no param block: set the variables you need in the session,
    then run it, so a paste file can carry the tenant values and nothing sensitive:

        $PolicyNamePrefix = 'Contoso AVD personal - '
        $AssignToGroupId  = '00000000-0000-0000-0000-000000000000'   # optional Entra device group
        $ValidateOnly     = $true                                    # first run: resolve and check only
        $AddOptionalPolicies = @('32-screen-capture-protection')     # optional extras
        irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/tools/intune/personal-desktops/Deploy-PersonalDesktopIntune.ps1 | iex

    What it does, in order:
      1. Loads the policy files in ./policies (from GitHub, or from $IntunePolicyFolder).
      2. Signs in to Microsoft Graph (device code in Cloud Shell) and checks Intune access.
      3. Resolves every settings catalog setting from the tenant: by setting ID, then by CSP path, then by
         display name. Child settings come from the chosen option's dependency list, never from guessed IDs.
         Values are checked against the tenant's definitions (options, minimum and maximum).
      4. Prints the plan. If anything can't be resolved, it stops before creating anything.
      5. Creates what doesn't exist yet (matched by name), unassigned unless a group is given.
      6. Assigns to the group only objects with no assignments yet, so existing assignments are never replaced.

    Intune settings catalog, compliance, platform script, update ring, trusted certificate and Microsoft 365
    Apps calls use Microsoft Graph beta, because the settings catalog and the compliance antivirus check are
    beta only. Microsoft says beta APIs change more often, so run with $ValidateOnly = $true first.

    Sources for each setting are in the policy files and in README.md next to this script.
#>

function Write-PiStep { param([string]$Text) Write-Host ''; Write-Host ("== {0}" -f $Text) -ForegroundColor Cyan }
function Write-PiOk { param([string]$Text) Write-Host ("   OK   {0}" -f $Text) -ForegroundColor Green }
function Write-PiInfo { param([string]$Text) Write-Host ("   ..   {0}" -f $Text) }
function Write-PiWarn { param([string]$Text) Write-Host ("   WARN {0}" -f $Text) -ForegroundColor Yellow }
function Stop-Pi { param([string]$Text) Write-Host ("   STOP {0}" -f $Text) -ForegroundColor Red; throw $Text }

function Get-PiSetting {
    # Reads a variable set by the caller (paste file or session). Empty strings and $null fall back to the default.
    param([string]$SettingName, $DefaultValue)
    $var = Get-Variable -Name $SettingName -ErrorAction SilentlyContinue
    if ($null -eq $var -or $null -eq $var.Value) { return $DefaultValue }
    if ($var.Value -is [string] -and [string]::IsNullOrWhiteSpace($var.Value)) { return $DefaultValue }
    return $var.Value
}

function Get-PiErrorText {
    param($ErrorRecord)
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return [string]$ErrorRecord.ErrorDetails.Message }
    return [string]$ErrorRecord.Exception.Message
}

function Test-PiNotFound {
    param($ErrorRecord)
    $resp = $ErrorRecord.Exception.Response
    if ($resp -and $resp.StatusCode -and ([int]$resp.StatusCode -eq 404)) { return $true }
    $text = Get-PiErrorText $ErrorRecord
    return ($text -match '404|NotFound|ResourceNotFound|does not exist')
}

function Invoke-PiGraph {
    param([string]$Method = 'GET', [string]$Path, $Body)
    $uri = if ($Path -match '^https://') { $Path } else { 'https://graph.microsoft.com/' + $Path.TrimStart('/') }
    $request = @{ Method = $Method; Uri = $uri; OutputType = 'PSObject'; ErrorAction = 'Stop' }
    if ($null -ne $Body) {
        $request.Body = ($Body | ConvertTo-Json -Depth 50 -Compress)
        $request.ContentType = 'application/json'
    }
    return (Invoke-MgGraphRequest @request)
}

function Get-PiGraphAll {
    # GET with paging; returns every item in value.
    param([string]$Path)
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Path
    while ($next) {
        $page = Invoke-PiGraph -Path $next
        foreach ($v in @($page.value)) { if ($null -ne $v) { $items.Add($v) } }
        $next = $page.'@odata.nextLink'
    }
    return $items.ToArray()
}

function Get-PiText {
    # Reads a file that sits next to this script: from $IntunePolicyFolder if set, otherwise from the base URI.
    param([string]$RelativePath, $Config)
    if ($Config.IntunePolicyFolder) {
        $full = Join-Path $Config.IntunePolicyFolder $RelativePath
        if (-not (Test-Path -Path $full)) { Stop-Pi ("Not found: {0}" -f $full) }
        return (Get-Content -Path $full -Raw)
    }
    $uri = ($Config.IntunePolicyBaseUri.TrimEnd('/') + '/' + $RelativePath.Replace('\', '/'))
    try { return (Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop).Content }
    catch { Stop-Pi ("Couldn't download {0}: {1}" -f $uri, $_.Exception.Message) }
}

function Get-PiDefinition {
    # A settings catalog definition by ID, cached. Returns $null if the tenant doesn't have it.
    param([string]$Id, $Ctx)
    if ([string]::IsNullOrWhiteSpace($Id)) { return $null }
    if ($Ctx.DefCache.ContainsKey($Id)) { return $Ctx.DefCache[$Id] }
    $def = $null
    try { $def = Invoke-PiGraph -Path ('beta/deviceManagement/configurationSettings/{0}' -f [uri]::EscapeDataString($Id)) }
    catch {
        if (-not (Test-PiNotFound $_)) { $Ctx.Warnings.Add(("Lookup of {0} failed: {1}" -f $Id, (Get-PiErrorText $_))) }
        $def = $null
    }
    $Ctx.DefCache[$Id] = $def
    return $def
}

function Get-PiFullUri {
    param($Definition)
    return ((([string]$Definition.baseUri) + '/' + ([string]$Definition.offsetUri)) -replace '/+', '/').TrimEnd('/')
}

function Resolve-PiDefinition {
    # Top-level setting: by ID, then by CSP path (baseUri + offsetUri), then by display name.
    param($Spec, $Ctx)
    $def = Get-PiDefinition -Id ([string]$Spec.id) -Ctx $Ctx
    if ($def) { return @{ Definition = $def; Via = 'id' } }

    $candidates = New-Object System.Collections.Generic.List[object]
    if ($Spec.omaUri) {
        $full = (([string]$Spec.omaUri).Replace('\', '/') -replace '/+', '/').TrimEnd('/')
        $parts = $full.TrimStart('.').TrimStart('/').Split('/')
        for ($i = $parts.Count - 2; $i -ge 1 -and $candidates.Count -eq 0; $i--) {
            $offset = '/' + ($parts[$i..($parts.Count - 1)] -join '/')
            foreach ($form in @($offset, $offset.TrimStart('/'))) {
                $filter = [uri]::EscapeDataString(("offsetUri eq '{0}'" -f $form))
                try { $found = Get-PiGraphAll -Path ('beta/deviceManagement/configurationSettings?$filter={0}' -f $filter) } catch { continue }
                foreach ($d in $found) {
                    if ((Get-PiFullUri $d) -ieq $full -and -not ($candidates | Where-Object { $_.id -eq $d.id })) { $candidates.Add($d) }
                }
            }
        }
        if ($candidates.Count -gt 1 -and $Spec.displayName) {
            $byName = @($candidates | Where-Object { $_.displayName -eq $Spec.displayName })
            if ($byName.Count -ge 1) { $candidates = [System.Collections.Generic.List[object]]$byName }
        }
        if ($candidates.Count -eq 1) { return @{ Definition = $candidates[0]; Via = 'CSP path' } }
    }

    if ($candidates.Count -eq 0 -and $Spec.displayName) {
        $name = ([string]$Spec.displayName).Replace("'", "''")
        $queries = @(
            ('beta/deviceManagement/configurationSettings?$filter={0}' -f [uri]::EscapeDataString(("displayName eq '{0}'" -f $name))),
            ('beta/deviceManagement/configurationSettings?$search={0}' -f [uri]::EscapeDataString(('"{0}"' -f $Spec.displayName)))
        )
        foreach ($q in $queries) {
            try { $found = Get-PiGraphAll -Path $q } catch { continue }
            foreach ($d in $found) {
                $deviceScope = ([string]$d.baseUri) -like './Device*'
                $windows = ([string]$d.applicability.platform) -match 'windows10'
                if ($d.displayName -eq $Spec.displayName -and $deviceScope -and $windows -and -not ($candidates | Where-Object { $_.id -eq $d.id })) { $candidates.Add($d) }
            }
            if ($candidates.Count -gt 0) { break }
        }
        if ($candidates.Count -eq 1) { return @{ Definition = $candidates[0]; Via = 'display name' } }
    }

    if ($candidates.Count -gt 1) {
        return @{ Definition = $null; Via = ('ambiguous: {0}' -f (($candidates | ForEach-Object { $_.id }) -join ', ')) }
    }
    return @{ Definition = $null; Via = 'not found' }
}

function Find-PiOption {
    # The option whose value, ID suffix or label matches the file. One match only.
    param($Definition, $Spec)
    $want = [string]$Spec.value
    $options = @($Definition.options | Where-Object { $_ })
    $hit = @($options | Where-Object { $null -ne $_.optionValue -and [string]$_.optionValue.value -eq $want })
    if ($hit.Count -ne 1) { $hit = @($options | Where-Object { ([string]$_.itemId) -like ('*_' + $want) }) }
    if ($hit.Count -ne 1 -and $Spec.valueLabel) { $hit = @($options | Where-Object { $_.displayName -eq $Spec.valueLabel }) }
    if ($hit.Count -eq 1) { return $hit[0] }
    return $null
}

function New-PiSettingInstance {
    # Builds a settingInstance from a tenant definition and the file's value, including child settings.
    # Children come from the chosen option's dependency list (dependedOnBy). A child can be given in the file
    # either nested under its parent or as its own top-level entry (the Pool); either way it lands where the
    # tenant's definitions say it belongs.
    param($Definition, $Spec, $Ctx, [string]$Label, $Pool)
    $type = [string]$Definition.'@odata.type'
    $where = '{0} ({1})' -f $Label, $Definition.id

    if ($type -like '*ChoiceSettingDefinition') {
        $opt = Find-PiOption -Definition $Definition -Spec $Spec
        if (-not $opt) {
            $valid = (@($Definition.options) | ForEach-Object { '{0} = {1}' -f $_.itemId, $_.displayName }) -join '; '
            $Ctx.Errors.Add(("{0}: value '{1}' ({2}) isn't an option. Options: {3}" -f $where, $Spec.value, $Spec.valueLabel, $valid))
            return $null
        }
        $children = New-Object System.Collections.Generic.List[object]
        $specChildren = @($Spec.children | Where-Object { $_ })
        $used = New-Object System.Collections.Generic.List[object]
        $deps = @($opt.dependedOnBy | Where-Object { $_ -and $_.dependedOnBy })
        foreach ($dep in $deps) {
            $childId = [string]$dep.dependedOnBy
            $childDef = $null
            $childSpec = $specChildren | Where-Object { $_.id -eq $childId } | Select-Object -First 1
            if (-not $childSpec) {
                $poolNode = @($Pool | Where-Object { -not $_.Consumed -and $_.Def -and [string]$_.Def.id -eq $childId }) | Select-Object -First 1
                if ($poolNode) { $poolNode.Consumed = $true; $childSpec = $poolNode.Spec; $childDef = $poolNode.Def }
            }
            if (-not $childDef) { $childDef = Get-PiDefinition -Id $childId -Ctx $Ctx }
            if (-not $childDef) { $Ctx.Errors.Add(("{0}: child setting {1} couldn't be read." -f $where, $childId)); continue }
            if (-not $childSpec) { $childSpec = $specChildren | Where-Object { $_.displayName -and $_.displayName -eq $childDef.displayName } | Select-Object -First 1 }
            if (-not $childSpec -and $deps.Count -eq 1 -and $specChildren.Count -eq 1 -and $specChildren[0].match -eq '*') { $childSpec = $specChildren[0] }
            if (-not $childSpec) {
                if ($dep.required) { $Ctx.Errors.Add(("{0}: required child '{1}' ({2}) has no value in the policy file." -f $where, $childDef.displayName, $childId)) }
                continue
            }
            if ($specChildren -contains $childSpec) { $used.Add($childSpec) }
            $inst = New-PiSettingInstance -Definition $childDef -Spec $childSpec -Ctx $Ctx -Label ('{0} > {1}' -f $Label, $childDef.displayName) -Pool $Pool
            if ($inst) { $children.Add($inst) }
        }
        foreach ($cs in $specChildren) {
            if ($used.Contains($cs)) { continue }
            if ($cs.optionalChild) { $Ctx.Warnings.Add(("{0}: optional child '{1}' isn't offered by this tenant's definition, so it's left out." -f $where, $cs.valueLabel)); continue }
            if ($cs.id -or $cs.omaUri) {
                $r = Resolve-PiDefinition -Spec $cs -Ctx $Ctx
                if ($r.Definition) {
                    $root = [string]$r.Definition.rootDefinitionId
                    $parentRoot = [string]$Definition.rootDefinitionId
                    if (-not $parentRoot) { $parentRoot = [string]$Definition.id }
                    if ($root -and $root -ne [string]$r.Definition.id -and $root -eq $parentRoot) {
                        # The tenant ties it to this setting through rootDefinitionId rather than the option's list.
                        $Ctx.Warnings.Add(("{0}: child {1} matched through rootDefinitionId." -f $where, $r.Definition.id))
                        $inst = New-PiSettingInstance -Definition $r.Definition -Spec $cs -Ctx $Ctx -Label ('{0} > {1}' -f $Label, $r.Definition.displayName) -Pool $Pool
                        if ($inst) { $children.Add($inst) }
                        continue
                    }
                    if (-not $root -or $root -eq [string]$r.Definition.id) {
                        # A top-level setting in this tenant: add it at the top level instead.
                        $Ctx.Warnings.Add(("{0}: '{1}' is a top-level setting in this tenant, so it's added at the top level." -f $where, $r.Definition.displayName))
                        $Ctx.Hoisted.Add([pscustomobject]@{ Spec = $cs; Def = $r.Definition; Label = ('{0}: {1}' -f ($Label -split ':')[0], $r.Definition.displayName) })
                        continue
                    }
                }
            }
            $Ctx.Errors.Add(("{0}: child '{1}' in the policy file doesn't match any child of option {2}." -f $where, $(if ($cs.displayName) { $cs.displayName } else { $cs.valueLabel }), $opt.itemId))
        }
        $Ctx.Resolved.Add(('{0} = {1}' -f $where, $opt.displayName))
        return @{
            '@odata.type'        = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
            settingDefinitionId  = [string]$Definition.id
            choiceSettingValue   = @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                value         = [string]$opt.itemId
                children      = $children.ToArray()
            }
        }
    }

    if ($type -like '*SimpleSettingDefinition') {
        $valueType = [string]$Definition.valueDefinition.'@odata.type'
        if ($valueType -like '*Integer*') {
            $n = 0
            if (-not [int]::TryParse([string]$Spec.value, [ref]$n)) { $Ctx.Errors.Add(("{0}: '{1}' isn't a whole number." -f $where, $Spec.value)); return $null }
            $min = $Definition.valueDefinition.minimumValue; $max = $Definition.valueDefinition.maximumValue
            if ($null -ne $min -and $n -lt [int64]$min) { $Ctx.Errors.Add(("{0}: {1} is below the minimum {2}." -f $where, $n, $min)); return $null }
            if ($null -ne $max -and $n -gt [int64]$max) { $Ctx.Errors.Add(("{0}: {1} is above the maximum {2}." -f $where, $n, $max)); return $null }
            $Ctx.Resolved.Add(('{0} = {1}' -f $where, $n))
            return @{
                '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
                settingDefinitionId = [string]$Definition.id
                simpleSettingValue  = @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue'; value = $n }
            }
        }
        if ($valueType -like '*String*') {
            $Ctx.Resolved.Add(('{0} = {1}' -f $where, $Spec.value))
            return @{
                '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
                settingDefinitionId = [string]$Definition.id
                simpleSettingValue  = @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'; value = [string]$Spec.value }
            }
        }
        $Ctx.Errors.Add(("{0}: value type {1} isn't supported by this script." -f $where, $valueType))
        return $null
    }

    $Ctx.Errors.Add(("{0}: setting type {1} isn't supported by this script." -f $where, $type))
    return $null
}

function Read-PiCertificate {
    # Loads a .cer (DER or Base64) and checks it belongs in the store asked for.
    param([string]$Path, [string]$Store)
    if (-not (Test-Path -Path $Path)) { Stop-Pi ("Certificate file not found: {0}" -f $Path) }
    if ($Path -match '\.(pfx|p12)$') { Stop-Pi ("{0} looks like a private key file. Use the public .cer only." -f $Path) }
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -Path $Path).Path)
    try { $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes) }
    catch { Stop-Pi ("{0} isn't a readable certificate: {1}" -f $Path, $_.Exception.Message) }
    $selfSigned = ($cert.Subject -eq $cert.Issuer)
    if ($Store -eq 'computerCertStoreRoot' -and -not $selfSigned) { Stop-Pi ("{0} isn't self-signed, so it isn't a root CA. Put it in the intermediate list." -f $Path) }
    if ($Store -eq 'computerCertStoreIntermediate' -and $selfSigned) { Stop-Pi ("{0} is self-signed (a root CA). Put it in the root list." -f $Path) }
    if ($cert.NotAfter -lt (Get-Date)) { Stop-Pi ("{0} expired on {1:yyyy-MM-dd}." -f $Path, $cert.NotAfter) }
    $cn = ($cert.Subject -split ',\s*' | Where-Object { $_ -like 'CN=*' } | Select-Object -First 1)
    if (-not $cn) { $cn = $cert.Subject } else { $cn = $cn.Substring(3) }
    return @{ Cert = $cert; CommonName = $cn; FileName = (Split-Path -Path $Path -Leaf) }
}

function Get-PiExisting {
    # Existing objects in a collection with the given name.
    param([string]$Collection, [string]$NameProperty, [string]$Name, [string]$ODataType)
    if ($ODataType) {
        $short = $ODataType.TrimStart('#')
        try { $all = Get-PiGraphAll -Path ('{0}?$filter={1}' -f $Collection, [uri]::EscapeDataString(("isof('{0}')" -f $short))) }
        catch { $all = Get-PiGraphAll -Path $Collection }
    } else {
        try { $all = Get-PiGraphAll -Path ('{0}?$select=id,{1}' -f $Collection, $NameProperty) }
        catch { $all = Get-PiGraphAll -Path $Collection }
    }
    return @($all | Where-Object { $_.$NameProperty -eq $Name })
}

function New-PiAssignmentBody {
    param([string]$Kind, [string]$GroupId, [string]$FilterId, [string]$Intent)
    $target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $GroupId }
    if ($FilterId -and $Kind -ne 'platformScript') {
        $target.deviceAndAppManagementAssignmentFilterId = $FilterId
        $target.deviceAndAppManagementAssignmentFilterType = 'include'
    }
    switch ($Kind) {
        'platformScript' { return @{ deviceManagementScriptAssignments = @(@{ '@odata.type' = '#microsoft.graph.deviceManagementScriptAssignment'; target = $target }) } }
        'officeSuiteApp' { return @{ mobileAppAssignments = @(@{ '@odata.type' = '#microsoft.graph.mobileAppAssignment'; intent = $Intent; target = $target; settings = $null }) } }
        default { return @{ assignments = @(@{ target = $target }) } }
    }
}

function Invoke-PersonalDesktopIntune {
    $defaultFiles = @('10-windows-compliance', '20-windows-laps', '30-session-clipboard', '31-session-time-limits',
        '32-screen-capture-protection', '40-update-ring', '50-microsoft-365-apps', '60-trusted-certificates')
    $inCloudShell = [bool]($env:AZUREPS_HOST_ENVIRONMENT -like 'cloud-shell*' -or $env:ACC_CLOUD)

    $c = [ordered]@{
        TenantId                            = Get-PiSetting 'TenantId' ''
        PolicyNamePrefix                    = Get-PiSetting 'PolicyNamePrefix' 'AVD personal desktops - '
        PolicyFiles                         = @(Get-PiSetting 'PolicyFiles' $defaultFiles)
        IncludePolicies                     = @(Get-PiSetting 'IncludePolicies' @())
        AddOptionalPolicies                 = @(Get-PiSetting 'AddOptionalPolicies' @())
        ExcludePolicies                     = @(Get-PiSetting 'ExcludePolicies' @())
        AssignToGroupId                     = Get-PiSetting 'AssignToGroupId' ''
        AssignToGroupName                   = Get-PiSetting 'AssignToGroupName' ''
        AssignmentFilterName                = Get-PiSetting 'AssignmentFilterName' ''
        AppInstallIntent                    = Get-PiSetting 'AppInstallIntent' 'required'
        TrustedRootCertificatePaths         = @(Get-PiSetting 'TrustedRootCertificatePaths' @())
        TrustedIntermediateCertificatePaths = @(Get-PiSetting 'TrustedIntermediateCertificatePaths' @())
        SessionIdleLimitMinutes             = [int](Get-PiSetting 'SessionIdleLimitMinutes' 90)
        SessionDisconnectedLimitMinutes     = [int](Get-PiSetting 'SessionDisconnectedLimitMinutes' 180)
        IntunePolicyBaseUri                 = Get-PiSetting 'IntunePolicyBaseUri' 'https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/tools/intune/personal-desktops'
        IntunePolicyFolder                  = Get-PiSetting 'IntunePolicyFolder' ''
        UseDeviceCode                       = [bool](Get-PiSetting 'UseDeviceCode' $inCloudShell)
        ValidateOnly                        = [bool](Get-PiSetting 'ValidateOnly' $false)
    }

    Write-PiStep 'Settings'
    foreach ($k in $c.Keys) {
        $v = $c[$k]
        if ($v -is [array]) { $v = ($v -join ', ') }
        Write-PiInfo ('{0} = {1}' -f $k, $v)
    }
    Write-Host ('Mode: {0}' -f $(if ($c.ValidateOnly) { 'validate only (reads Intune, creates nothing)' } else { 'create what is missing' }))
    if ($c.AppInstallIntent -notin @('required', 'available')) { Stop-Pi "AppInstallIntent must be 'required' or 'available'." }
    if ($c.SessionIdleLimitMinutes -lt 0 -or $c.SessionIdleLimitMinutes -gt 1440) { Stop-Pi 'SessionIdleLimitMinutes must be 0 to 1440.' }
    if ($c.SessionDisconnectedLimitMinutes -lt 0 -or $c.SessionDisconnectedLimitMinutes -gt 10080) { Stop-Pi 'SessionDisconnectedLimitMinutes must be 0 to 10080.' }

    # -----------------------------------------------------------------------------------------------
    Write-PiStep 'Policy files'
    $selected = New-Object System.Collections.Generic.List[object]
    foreach ($f in $c.PolicyFiles) {
        $base = ([string]$f) -replace '\.json$', ''
        $prefix = ($base -split '-')[0]
        $listedInclude = [bool]($c.IncludePolicies | Where-Object { $_ -eq $base -or $_ -eq $prefix })
        $listedAdd = [bool]($c.AddOptionalPolicies | Where-Object { $_ -eq $base -or $_ -eq $prefix })
        $listedExclude = [bool]($c.ExcludePolicies | Where-Object { $_ -eq $base -or $_ -eq $prefix })
        $text = Get-PiText -RelativePath ('policies/{0}.json' -f $base) -Config $c
        $p = $text | ConvertFrom-Json -AsHashtable
        if ($p.schema -ne 'pd-intune-policy/1') { Stop-Pi ('{0}.json has an unknown schema.' -f $base) }
        if ($listedExclude) { $wanted = $false }
        elseif ($c.IncludePolicies.Count -gt 0) { $wanted = $listedInclude -or $listedAdd }
        else { $wanted = (-not $p.optional) -or $listedAdd }
        if (-not $wanted) {
            Write-PiInfo ('Skipped {0}{1}' -f $base, $(if ($p.optional -and -not $listedExclude) { ' (optional; add it with $AddOptionalPolicies)' } else { '' }))
            continue
        }
        if ($p.kind -eq 'trustedCertificates' -and ($c.TrustedRootCertificatePaths.Count + $c.TrustedIntermediateCertificatePaths.Count) -eq 0) {
            Write-PiInfo ('Skipped {0} (no certificate paths set)' -f $base)
            continue
        }
        $p.file = $base
        $selected.Add($p)
        Write-PiOk ('{0}: {1} ({2})' -f $base, $p.name, $p.kind)
    }
    if ($selected.Count -eq 0) { Stop-Pi 'Nothing selected. Check $IncludePolicies, $AddOptionalPolicies and $ExcludePolicies.' }

    # -----------------------------------------------------------------------------------------------
    Write-PiStep 'Microsoft Graph sign-in'
    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        Stop-Pi 'Microsoft.Graph.Authentication isn''t available. In Cloud Shell it is; elsewhere run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }
    if (-not $c.TenantId -and (Get-Command -Name Get-AzContext -ErrorAction SilentlyContinue)) {
        $az = Get-AzContext -ErrorAction SilentlyContinue
        if ($az -and $az.Tenant) { $c.TenantId = [string]$az.Tenant.Id; Write-PiInfo ('Tenant from the Azure context: {0}' -f $c.TenantId) }
    }
    # Validate-only needs read scopes only, so it also works for an Intune Read Only Operator.
    $access = if ($c.ValidateOnly) { 'Read' } else { 'ReadWrite' }
    $scopes = @("DeviceManagementConfiguration.$access.All")
    if ($selected | Where-Object { $_.kind -eq 'officeSuiteApp' }) { $scopes += "DeviceManagementApps.$access.All" }
    if ($c.AssignToGroupId -or $c.AssignToGroupName) { $scopes += 'Group.Read.All' }
    $mg = Get-MgContext
    $haveScopes = $mg -and -not ($scopes | Where-Object { $mg.Scopes -notcontains $_ })
    $sameTenant = $mg -and (-not $c.TenantId -or $mg.TenantId -eq $c.TenantId)
    if ($haveScopes -and $sameTenant) {
        Write-PiOk ('Reusing the Graph sign-in for {0}' -f $mg.Account)
    } else {
        $connect = @{ Scopes = $scopes; NoWelcome = $true; ErrorAction = 'Stop' }
        if ($c.TenantId) { $connect.TenantId = $c.TenantId }
        if ($c.UseDeviceCode) { $connect.UseDeviceCode = $true; Write-PiInfo 'Device code sign-in: open the link shown, enter the code, and sign in with your admin account.' }
        try { Connect-MgGraph @connect }
        catch {
            Stop-Pi ("Graph sign-in failed: {0}. If consent is needed, a tenant admin must grant it to Microsoft Graph Command Line Tools for: {1}. If Conditional Access blocks device code sign-in, use the portal steps in README.md." -f $_.Exception.Message, ($scopes -join ', '))
        }
        $mg = Get-MgContext
        Write-PiOk ('Signed in as {0} to tenant {1}' -f $mg.Account, $mg.TenantId)
    }
    try { $null = Invoke-PiGraph -Path 'beta/deviceManagement/configurationPolicies?$top=1&$select=id' }
    catch {
        Stop-Pi ("Intune didn't allow the read: {0}. Creating policies needs an Intune role such as Policy and Profile Manager or Intune Administrator (and Application Manager for apps)." -f (Get-PiErrorText $_))
    }
    Write-PiOk $(if ($c.ValidateOnly) { 'Intune read access checked' } else { 'Intune read access checked (creating needs Policy and Profile Manager or Intune Administrator; apps need Application Manager)' })

    # -----------------------------------------------------------------------------------------------
    $groupId = $c.AssignToGroupId
    $filterId = ''
    if ($c.AssignToGroupName -and -not $groupId) {
        $name = $c.AssignToGroupName.Replace("'", "''")
        $groups = @(Get-PiGraphAll -Path ('v1.0/groups?$filter={0}&$select=id,displayName' -f [uri]::EscapeDataString(("displayName eq '{0}'" -f $name))))
        if ($groups.Count -ne 1) { Stop-Pi ("Found {0} groups named '{1}'. Use `$AssignToGroupId instead." -f $groups.Count, $c.AssignToGroupName) }
        $groupId = [string]$groups[0].id
    }
    if ($groupId) {
        Write-PiStep 'Assignment target'
        try { $g = Invoke-PiGraph -Path ('v1.0/groups/{0}?$select=id,displayName,groupTypes,membershipRule' -f $groupId) }
        catch { Stop-Pi ("Group {0} couldn't be read: {1}" -f $groupId, (Get-PiErrorText $_)) }
        Write-PiOk ('Group: {0} ({1})' -f $g.displayName, $g.id)
        if ($g.membershipRule) { Write-PiInfo ('Dynamic rule: {0}' -f $g.membershipRule) }
        if ($c.AssignmentFilterName) {
            $filters = @(Get-PiGraphAll -Path 'beta/deviceManagement/assignmentFilters' | Where-Object { $_.displayName -eq $c.AssignmentFilterName })
            if ($filters.Count -ne 1) { Stop-Pi ("Found {0} assignment filters named '{1}'." -f $filters.Count, $c.AssignmentFilterName) }
            $filterId = [string]$filters[0].id
            Write-PiOk ('Include filter: {0} ({1}): {2}' -f $filters[0].displayName, $filterId, $filters[0].rule)
        }
    } else {
        Write-PiInfo 'No group set: everything is created unassigned. Assign it in the admin center after review.'
    }

    # -----------------------------------------------------------------------------------------------
    Write-PiStep 'Resolving and checking (nothing is created in this step)'
    $ctx = @{
        DefCache = @{}
        Errors   = New-Object System.Collections.Generic.List[string]
        Warnings = New-Object System.Collections.Generic.List[string]
        Resolved = New-Object System.Collections.Generic.List[string]
        Hoisted  = New-Object System.Collections.Generic.List[object]
    }
    $plan = New-Object System.Collections.Generic.List[object]

    foreach ($p in $selected) {
        $nameProp = [string]$p.graph.nameProperty
        $collection = [string]$p.graph.collection
        $errorsBefore = $ctx.Errors.Count

        if ($p.kind -eq 'trustedCertificates') {
            $certs = @()
            foreach ($path in $c.TrustedRootCertificatePaths) { if ($path) { $certs += , @((Read-PiCertificate -Path $path -Store 'computerCertStoreRoot'), 'computerCertStoreRoot', 'Root') } }
            foreach ($path in $c.TrustedIntermediateCertificatePaths) { if ($path) { $certs += , @((Read-PiCertificate -Path $path -Store 'computerCertStoreIntermediate'), 'computerCertStoreIntermediate', 'Intermediate') } }
            foreach ($entry in $certs) {
                $info = $entry[0]; $store = $entry[1]; $label = $entry[2]
                $name = '{0}{1} - {2} - {3}' -f $c.PolicyNamePrefix, $p.name, $label, $info.CommonName
                Write-PiInfo ('{0}: {1}, thumbprint {2}, expires {3:yyyy-MM-dd}' -f $label, $info.Cert.Subject, $info.Cert.Thumbprint, $info.Cert.NotAfter)
                $body = @{
                    '@odata.type'          = '#microsoft.graph.windows81TrustedRootCertificate'
                    displayName            = $name
                    description            = ('{0} Thumbprint {1}.' -f $p.description, $info.Cert.Thumbprint)
                    trustedRootCertificate = [System.Convert]::ToBase64String($info.Cert.RawData)
                    certFileName           = $info.FileName
                    destinationStore       = $store
                }
                $existing = @(Get-PiExisting -Collection $collection -NameProperty $nameProp -Name $name)
                $plan.Add([pscustomobject]@{ File = $p.file; Kind = 'deviceConfiguration'; Name = $name; Collection = $collection; Body = $body; ExistingId = $(if ($existing) { $existing[0].id } else { '' }); Ok = $true; Policy = $p })
            }
            continue
        }

        $name = $c.PolicyNamePrefix + $p.name
        $body = $null

        switch ($p.kind) {
            'settingsCatalog' {
                # Resolve every entry, then let the tenant's definitions decide what nests under what.
                $nodes = New-Object System.Collections.Generic.List[object]
                foreach ($s in @($p.settings)) {
                    $r = Resolve-PiDefinition -Spec $s -Ctx $ctx
                    if (-not $r.Definition) { $ctx.Errors.Add(("{0}: '{1}' couldn't be resolved ({2})." -f $p.file, $s.displayName, $r.Via)); continue }
                    if ($r.Via -ne 'id') { Write-PiWarn ("{0}: '{1}' resolved by {2} to {3}. Consider putting that ID in the policy file." -f $p.file, $s.displayName, $r.Via, $r.Definition.id) }
                    $nodes.Add([pscustomobject]@{ Spec = $s; Def = $r.Definition; Consumed = $false })
                }
                $childOf = @{}
                foreach ($n in $nodes) {
                    if ([string]$n.Def.'@odata.type' -like '*ChoiceSettingDefinition') {
                        $o = Find-PiOption -Definition $n.Def -Spec $n.Spec
                        if ($o) { foreach ($d in @($o.dependedOnBy | Where-Object { $_ -and $_.dependedOnBy })) { $childOf[[string]$d.dependedOnBy] = [string]$n.Def.displayName } }
                    }
                }
                $ctx.Hoisted = New-Object System.Collections.Generic.List[object]
                $instances = New-Object System.Collections.Generic.List[object]
                foreach ($n in $nodes) {
                    if ($childOf.ContainsKey([string]$n.Def.id)) { continue }
                    $n.Consumed = $true
                    $inst = New-PiSettingInstance -Definition $n.Def -Spec $n.Spec -Ctx $ctx -Label ('{0}: {1}' -f $p.file, $n.Def.displayName) -Pool $nodes
                    if ($inst) { $instances.Add(@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'; settingInstance = $inst }) }
                }
                foreach ($h in @($ctx.Hoisted)) {
                    $inst = New-PiSettingInstance -Definition $h.Def -Spec $h.Spec -Ctx $ctx -Label $h.Label -Pool $nodes
                    if ($inst) { $instances.Add(@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSetting'; settingInstance = $inst }) }
                }
                foreach ($n in $nodes) {
                    if ($childOf.ContainsKey([string]$n.Def.id)) {
                        if ($n.Consumed) { Write-PiInfo ("{0}: '{1}' sits under '{2}' in this tenant, so it's nested there." -f $p.file, $n.Def.displayName, $childOf[[string]$n.Def.id]) }
                        else { $ctx.Errors.Add(("{0}: '{1}' belongs under '{2}' but wasn't placed." -f $p.file, $n.Def.displayName, $childOf[[string]$n.Def.id])) }
                    }
                }
                $body = @{
                    name         = $name
                    description  = [string]$p.description
                    platforms    = 'windows10'
                    technologies = 'mdm'
                    settings     = $instances.ToArray()
                }
            }
            'compliancePolicy' {
                $body = $p.body.Clone()
                $body.displayName = $name
                $body.description = [string]$p.description
            }
            'deviceConfiguration' {
                $body = $p.body.Clone()
                $body.displayName = $name
                $body.description = [string]$p.description
            }
            'officeSuiteApp' {
                $body = $p.body.Clone()
                $body.displayName = $name
                $body.description = [string]$p.description
            }
            'platformScript' {
                $scriptText = Get-PiText -RelativePath ([string]$p.script.file) -Config $c
                foreach ($rep in @($p.script.replace)) {
                    $value = Get-PiSetting ([string]$rep.setting) $rep.default
                    if (-not [regex]::IsMatch($scriptText, [string]$rep.pattern)) { $ctx.Errors.Add(("{0}: the script has no line matching {1}." -f $p.file, $rep.pattern)); continue }
                    $scriptText = ([regex][string]$rep.pattern).Replace($scriptText, ([string]$rep.template -f $value).Replace('$', '$$'), 1)
                    $ctx.Resolved.Add(('{0}: {1} = {2}' -f $p.file, $rep.setting, $value))
                }
                $body = @{
                    '@odata.type'         = '#microsoft.graph.deviceManagementScript'
                    displayName           = $name
                    description           = [string]$p.description
                    scriptContent         = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptText))
                    runAsAccount          = [string]$p.script.runAsAccount
                    enforceSignatureCheck = [bool]$p.script.enforceSignatureCheck
                    runAs32Bit            = [bool]$p.script.runAs32Bit
                    fileName              = (Split-Path -Path ([string]$p.script.file) -Leaf)
                }
            }
            default { $ctx.Errors.Add(('{0}: unknown kind {1}.' -f $p.file, $p.kind)) }
        }

        $existing = @()
        if ($collection) { $existing = @(Get-PiExisting -Collection $collection -NameProperty $nameProp -Name $name -ODataType ([string]$p.graph.odataType)) }
        if ($existing.Count -gt 1) { $ctx.Warnings.Add(("{0} objects are already named '{1}'. The first is used." -f $existing.Count, $name)) }
        $plan.Add([pscustomobject]@{
            File = $p.file; Kind = $p.kind; Name = $name; Collection = $collection; Body = $body
            ExistingId = $(if ($existing) { [string]$existing[0].id } else { '' })
            Ok = ($ctx.Errors.Count -eq $errorsBefore); Policy = $p
        })
    }

    foreach ($line in $ctx.Resolved) { Write-PiOk $line }
    foreach ($w in $ctx.Warnings) { Write-PiWarn $w }

    Write-PiStep 'Plan'
    foreach ($item in $plan) {
        $action = if (-not $item.Ok) { 'ERROR' } elseif ($item.ExistingId) { 'exists, left as it is' } else { 'create' }
        Write-PiInfo ('{0,-24} {1,-22} {2}  ->  {3}' -f $item.File, $item.Kind, $item.Name, $action)
    }
    if ($ctx.Errors.Count -gt 0) {
        Write-PiStep 'Problems (nothing was created)'
        foreach ($e in $ctx.Errors) { Write-Host ("   ERR  {0}" -f $e) -ForegroundColor Red }
        Write-PiInfo 'Fix the policy file, or leave that policy out with $ExcludePolicies and build it in the admin center:'
        foreach ($item in ($plan | Where-Object { -not $_.Ok })) { Write-PiInfo ('{0}: {1}' -f $item.File, $item.Policy.portalPath) }
        Stop-Pi ('{0} problem(s) found before anything was created.' -f $ctx.Errors.Count)
    }
    if ($c.ValidateOnly) {
        Write-PiStep 'Validate only'
        Write-PiOk 'Everything resolved. Nothing was created. Set $ValidateOnly = $false and run again to create.'
        return
    }

    # -----------------------------------------------------------------------------------------------
    Write-PiStep 'Creating'
    $failed = 0
    foreach ($item in $plan) {
        if ($item.ExistingId) { Write-PiInfo ('{0} already exists ({1})' -f $item.Name, $item.ExistingId); continue }
        try {
            $created = Invoke-PiGraph -Method POST -Path $item.Collection -Body $item.Body
            $item.ExistingId = [string]$created.id
            $item | Add-Member -NotePropertyName Created -NotePropertyValue $true -Force
            Write-PiOk ('Created {0} ({1})' -f $item.Name, $created.id)
        } catch {
            $failed++
            Write-Host ("   ERR  {0}: {1}" -f $item.Name, (Get-PiErrorText $_)) -ForegroundColor Red
            Write-PiInfo ('Manual alternative: {0}' -f $item.Policy.portalPath)
        }
    }

    if ($groupId) {
        Write-PiStep 'Assigning'
        foreach ($item in ($plan | Where-Object { $_.ExistingId })) {
            $base = '{0}/{1}' -f $item.Collection, $item.ExistingId
            try { $current = @(Get-PiGraphAll -Path ('{0}/assignments' -f $base)) } catch { $current = @(); Write-PiWarn ("Couldn't read assignments of {0}: {1}" -f $item.Name, (Get-PiErrorText $_)) }
            if ($current | Where-Object { $_.target.groupId -eq $groupId }) { Write-PiInfo ('{0}: already assigned to the group' -f $item.Name); continue }
            if ($current.Count -gt 0) { Write-PiWarn ('{0} already has {1} assignment(s); left alone so they aren''t replaced. Add the group in the admin center.' -f $item.Name, $current.Count); continue }
            $body = New-PiAssignmentBody -Kind $item.Kind -GroupId $groupId -FilterId $filterId -Intent $c.AppInstallIntent
            if ($filterId -and $item.Kind -eq 'platformScript') { Write-PiInfo ('{0}: platform scripts are assigned without the filter' -f $item.Name) }
            $done = $false
            for ($attempt = 1; $attempt -le 6 -and -not $done; $attempt++) {
                try {
                    $null = Invoke-PiGraph -Method POST -Path ('{0}/assign' -f $base) -Body $body
                    $done = $true
                    Write-PiOk ('{0} -> group {1}{2}' -f $item.Name, $groupId, $(if ($item.Kind -eq 'officeSuiteApp') { ' (' + $c.AppInstallIntent + ')' } else { '' }))
                } catch {
                    $msg = Get-PiErrorText $_
                    if ($item.Kind -eq 'officeSuiteApp' -and $attempt -lt 6) { Write-PiInfo ('{0} isn''t ready to assign yet; waiting 20 seconds' -f $item.Name); Start-Sleep -Seconds 20 }
                    else { Write-PiWarn ('Couldn''t assign {0}: {1}' -f $item.Name, $msg); break }
                }
            }
        }
    }

    # -----------------------------------------------------------------------------------------------
    Write-PiStep 'Done'
    if ($failed -gt 0) { Write-PiWarn ('{0} item(s) failed to create; see the errors above. Paste again after fixing: existing items are left as they are.' -f $failed) }
    Write-PiInfo 'Tenant settings this script doesn''t change (check them in the admin centers):'
    Write-PiInfo '  Intune: Devices > Enrollment > Windows > Automatic Enrollment: MDM user scope covers the users who sign in to the hosts.'
    Write-PiInfo '  Entra ID: Devices > Device settings: Enable Microsoft Entra Local Administrator Password Solution (LAPS) = Yes.'
    Write-PiInfo '  Intune: Devices > Compliance > Compliance settings: Mark devices with no compliance policy assigned as (your choice).'
    Write-PiInfo 'Clipboard and screen capture settings need a host restart; session time limits apply from the next sign-in.'
}

Invoke-PersonalDesktopIntune
