<#
.SYNOPSIS
Validates and deploys the example Azure Virtual Desktop Intune Settings Catalog policies.

.DESCRIPTION
Deploy-IntunePolicy.ps1 reads policy definition files from tools/intune/policies,
validates their metadata, resolves every Settings Catalog setting definition from
the tenant through Microsoft Graph beta, verifies choice options before anything is
created, creates the Intune deviceManagementConfigurationPolicy objects unassigned
by default, and optionally assigns them to a Microsoft Entra device group.

The example policy files deliberately do not hardcode settings catalog
settingDefinitionId values or choice option item IDs. The script resolves them at
deployment time by using the tenant's Settings Catalog data. If a setting or option
cannot be resolved exactly, the script stops and reports the settings picker path
from the JSON file so an Intune administrator can review the current tenant
catalog.

.PARAMETER PolicyPath
Path to a policy JSON file or to a directory that contains one or more policy JSON
files. The default is the policies folder beside this script.

.PARAMETER OfflineValidationOnly
Validates the policy JSON files without loading Microsoft Graph PowerShell,
connecting to Microsoft Graph or calling any service. Use this in pull requests
and before adapting examples.

.PARAMETER AssignToGroupId
Optional Microsoft Entra group object ID to assign every created policy to. The
examples should normally be created unassigned, then assigned to a small test
device group after review.

.PARAMETER Scopes
Delegated Microsoft Graph scopes used by Connect-MgGraph when the script connects.
The default is DeviceManagementConfiguration.ReadWrite.All. Add Group.Read.All only
if you adapt the script to resolve group names.

.PARAMETER SkipConnect
Skips Connect-MgGraph. Use this only when the current PowerShell session is already
connected to Microsoft Graph with the required scopes.

.PARAMETER PassThru
Returns created policy, setting and assignment results. Validation output is always
returned.

.EXAMPLE
PS> .\Deploy-IntunePolicy.ps1 -OfflineValidationOnly

Validates all policy JSON files locally without signing in or calling Microsoft
Graph.

.EXAMPLE
PS> .\Deploy-IntunePolicy.ps1 -WhatIf

Connects to Microsoft Graph, resolves and verifies settings catalog definitions
and options, then shows what would be created without changing Intune.

.EXAMPLE
PS> .\Deploy-IntunePolicy.ps1 -AssignToGroupId '00000000-0000-0000-0000-000000000000' -WhatIf

Performs online resolution and shows the policy and group assignment changes that
would be made for a test device group.

.NOTES
Requires PowerShell 7.2 or later.

Microsoft Learn references:
- deviceManagementConfigurationPolicy resource type, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy
- Create deviceManagementConfigurationPolicy, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-create
- List deviceManagementConfigurationSettingDefinitions, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationsettingdefinition-list
- deviceManagementConfigurationSettingDefinition resource type, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationsettingdefinition
- Create deviceManagementConfigurationSetting, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/intune-deviceconfigv2-devicemanagementconfigurationsetting-create
- groupAssignmentTarget resource type, Microsoft Graph beta:
  https://learn.microsoft.com/graph/api/resources/intune-shared-groupassignmenttarget
- Connect-MgGraph:
  https://learn.microsoft.com/powershell/module/microsoft.graph.authentication/connect-mggraph
- Invoke-MgGraphRequest:
  https://learn.microsoft.com/powershell/module/microsoft.graph.authentication/invoke-mggraphrequest

.LINK
https://learn.microsoft.com/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $PolicyPath = (Join-Path -Path $PSScriptRoot -ChildPath 'policies'),

    [Parameter()]
    [switch] $OfflineValidationOnly,

    [Parameter()]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string] $AssignToGroupId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]] $Scopes = @('DeviceManagementConfiguration.ReadWrite.All'),

    [Parameter()]
    [switch] $SkipConnect,

    [Parameter()]
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:LongDashPattern = [regex]::new('[\u2012\u2013\u2014\u2015]')

function Get-PolicyFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "PolicyPath '$Path' does not exist."
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        $files = Get-ChildItem -LiteralPath $item.FullName -Filter '*.json' -File | Sort-Object -Property Name
    }
    else {
        $files = @($item)
    }

    if ($files.Count -eq 0) {
        throw "No policy JSON files were found at '$Path'."
    }

    return $files
}

function Read-PolicyFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File
    )

    $raw = Get-Content -LiteralPath $File.FullName -Raw
    if ($script:LongDashPattern.IsMatch($raw)) {
        throw "$($File.FullName) contains a long dash. Use plain hyphens only."
    }

    try {
        $policy = $raw | ConvertFrom-Json -Depth 50
    }
    catch {
        throw "$($File.FullName) is not valid JSON. $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        File   = $File
        Raw    = $raw
        Policy = $policy
    }
}

function Test-LearnLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url,

        [Parameter(Mandatory = $true)]
        [string] $Context
    )

    if ($Url -notmatch '^https://learn\.microsoft\.com/') {
        throw "$Context has a non Microsoft Learn URL: $Url"
    }

    if ($Url -match 'https://learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/') {
        throw "$Context uses a locale segment. Use canonical learn.microsoft.com URLs without a locale segment: $Url"
    }
}

function Test-PolicyObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $PolicyRecord
    )

    $policy = $PolicyRecord.Policy
    $fileName = $PolicyRecord.File.FullName
    $requiredPolicyProperties = @('schemaVersion', 'name', 'description', 'platforms', 'technologies', 'settings')

    foreach ($propertyName in $requiredPolicyProperties) {
        if (-not ($policy.PSObject.Properties.Name -contains $propertyName)) {
            throw "$fileName is missing required property '$propertyName'."
        }
    }

    if ($policy.name -notmatch '^Contoso AVD - ') {
        throw "$fileName policy name must start with 'Contoso AVD - '."
    }

    if (-not ($policy.settings -is [array]) -or $policy.settings.Count -eq 0) {
        throw "$fileName must contain at least one setting."
    }

    $supportedTypes = @('choice', 'simpleInteger', 'simpleString', 'multiString')
    for ($index = 0; $index -lt $policy.settings.Count; $index++) {
        $setting = $policy.settings[$index]
        $context = "$fileName setting index $index"
        $requiredSettingProperties = @('key', 'settingPickerPath', 'scope', 'settingType', 'value', 'resolver', 'why', 'learnLinks')

        foreach ($propertyName in $requiredSettingProperties) {
            if (-not ($setting.PSObject.Properties.Name -contains $propertyName)) {
                throw "$context is missing required property '$propertyName'."
            }
        }

        if ($setting.PSObject.Properties.Name -contains 'settingDefinitionId') {
            throw "$context hardcodes settingDefinitionId. Use resolver metadata instead."
        }

        if ($setting.scope -notin @('device', 'user')) {
            throw "$context has unsupported scope '$($setting.scope)'."
        }

        if ($setting.settingType -notin $supportedTypes) {
            throw "$context has unsupported settingType '$($setting.settingType)'."
        }

        if (-not ($setting.learnLinks -is [array]) -or $setting.learnLinks.Count -eq 0) {
            throw "$context must include at least one Learn link."
        }

        foreach ($learnLink in $setting.learnLinks) {
            Test-LearnLink -Url $learnLink -Context $context
        }

        if (-not ($setting.resolver.PSObject.Properties.Name -contains 'displayNames') -or $setting.resolver.displayNames.Count -eq 0) {
            throw "$context must include resolver.displayNames."
        }

        switch ($setting.settingType) {
            'simpleInteger' {
                if (-not ($setting.value -is [int] -or $setting.value -is [long])) {
                    throw "$context must have an integer value."
                }
            }
            'simpleString' {
                if (-not ($setting.value -is [string]) -or [string]::IsNullOrWhiteSpace($setting.value)) {
                    throw "$context must have a non-empty string value."
                }
            }
            'multiString' {
                if (-not ($setting.value -is [array]) -or $setting.value.Count -eq 0) {
                    throw "$context must have a non-empty string array value."
                }
            }
            'choice' {
                if (-not ($setting.value.PSObject.Properties.Name -contains 'optionDisplayName')) {
                    throw "$context choice value must include optionDisplayName."
                }
            }
        }
    }

    return [pscustomobject]@{
        File        = $PolicyRecord.File.FullName
        Name        = $policy.name
        SettingCount = $policy.settings.Count
        Valid       = $true
    }
}

function Invoke-GraphPagedRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Uri
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $nextUri = $Uri

    while (-not [string]::IsNullOrWhiteSpace($nextUri)) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri
        if ($response.value) {
            foreach ($item in $response.value) {
                $results.Add($item)
            }
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextUri = $response.'@odata.nextLink'
        }
        else {
            $nextUri = $null
        }
    }

    return $results
}

function Get-IntuneSettingDefinition {
    [CmdletBinding()]
    param()

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/configurationSettings?$top=999'
    $definitions = Invoke-GraphPagedRequest -Uri $uri
    if ($definitions.Count -eq 0) {
        throw 'Microsoft Graph returned no Intune configuration settings.'
    }

    return $definitions
}

function ConvertTo-NormalisedPath {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return ($Path -replace '^\./', '' -replace '\\', '/' -replace '/+', '/').Trim('/').ToLowerInvariant()
}

function Resolve-SettingDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Setting,

        [Parameter(Mandatory = $true)]
        [object[]] $Definitions
    )

    $displayNames = @($Setting.resolver.displayNames | ForEach-Object { [string] $_ })
    $cspPath = if ($Setting.resolver.PSObject.Properties.Name -contains 'cspPath') { [string] $Setting.resolver.cspPath } else { $null }
    $normalisedCspPath = ConvertTo-NormalisedPath -Path $cspPath

    $candidates = foreach ($definition in $Definitions) {
        $definitionNames = @(
            [string] $definition.displayName
            [string] $definition.name
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $nameMatched = $false
        foreach ($displayName in $displayNames) {
            if ($definitionNames -contains $displayName) {
                $nameMatched = $true
            }
        }

        $cspMatched = $false
        if (-not [string]::IsNullOrWhiteSpace($normalisedCspPath)) {
            $definitionPath = ConvertTo-NormalisedPath -Path ('{0}/{1}' -f $definition.baseUri, $definition.offsetUri)
            if ($definitionPath -eq $normalisedCspPath -or $definitionPath.EndsWith($normalisedCspPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $cspMatched = $true
            }
        }

        if ($nameMatched -or $cspMatched) {
            $definition
        }
    }

    if ($candidates.Count -eq 0) {
        throw "Could not resolve setting '$($Setting.key)' at '$($Setting.settingPickerPath)'. Search for this path in the Intune settings picker and update resolver.displayNames or resolver.cspPath."
    }

    if ($candidates.Count -gt 1) {
        $candidateSummary = $candidates |
            Select-Object -First 8 -Property id, displayName, name, baseUri, offsetUri |
            ConvertTo-Json -Depth 5
        throw "Setting '$($Setting.key)' at '$($Setting.settingPickerPath)' resolved to multiple definitions. Add a more specific display name or CSP path. Candidates: $candidateSummary"
    }

    return $candidates[0]
}

function Find-ChoiceOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Setting,

        [Parameter(Mandatory = $true)]
        [pscustomobject] $Definition
    )

    if (-not ($Definition.PSObject.Properties.Name -contains 'options') -or -not $Definition.options) {
        throw "Setting '$($Setting.key)' at '$($Setting.settingPickerPath)' is a choice setting in JSON, but the tenant definition did not return options."
    }

    $wantedNames = [System.Collections.Generic.List[string]]::new()
    $wantedNames.Add([string] $Setting.value.optionDisplayName)
    if ($Setting.value.PSObject.Properties.Name -contains 'fallbackOptionDisplayNames') {
        foreach ($fallbackName in $Setting.value.fallbackOptionDisplayNames) {
            $wantedNames.Add([string] $fallbackName)
        }
    }

    $wantedNumericValue = $null
    if ($Setting.value.PSObject.Properties.Name -contains 'expectedNumericValue') {
        $wantedNumericValue = [string] $Setting.value.expectedNumericValue
    }

    $options = @($Definition.options)
    foreach ($wantedName in $wantedNames) {
        $match = $options | Where-Object {
            $_.displayName -eq $wantedName -or
            $_.name -eq $wantedName -or
            $_.itemId -eq $wantedName
        }

        if ($match.Count -eq 1) {
            return $match[0]
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($wantedNumericValue)) {
        $numericMatch = $options | Where-Object {
            $_.itemId -eq $wantedNumericValue -or
            $_.name -eq $wantedNumericValue -or
            $_.displayName -eq $wantedNumericValue
        }

        if ($numericMatch.Count -eq 1) {
            return $numericMatch[0]
        }
    }

    $available = $options | Select-Object -Property itemId, displayName, name | ConvertTo-Json -Depth 4
    throw "Could not resolve option '$($Setting.value.optionDisplayName)' for setting '$($Setting.key)' at '$($Setting.settingPickerPath)'. Available options: $available"
}

function ConvertTo-GraphSimpleSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $DefinitionId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('simpleInteger', 'simpleString')]
        [string] $SettingType,

        [Parameter(Mandatory = $true)]
        [object] $Value
    )

    $valueType = if ($SettingType -eq 'simpleInteger') {
        '#microsoft.graph.deviceManagementConfigurationIntegerSettingValue'
    }
    else {
        '#microsoft.graph.deviceManagementConfigurationStringSettingValue'
    }

    return @{
        '@odata.type'   = '#microsoft.graph.deviceManagementConfigurationSetting'
        settingInstance = @{
            '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'
            settingDefinitionId = $DefinitionId
            simpleSettingValue  = @{
                '@odata.type' = $valueType
                value         = $Value
            }
        }
    }
}

function ConvertTo-GraphChoiceSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $DefinitionId,

        [Parameter(Mandatory = $true)]
        [string] $OptionItemId
    )

    return @{
        '@odata.type'   = '#microsoft.graph.deviceManagementConfigurationSetting'
        settingInstance = @{
            '@odata.type'       = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'
            settingDefinitionId = $DefinitionId
            choiceSettingValue  = @{
                '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingValue'
                value         = $OptionItemId
                children      = @()
            }
        }
    }
}

function ConvertTo-GraphSettingPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Setting,

        [Parameter(Mandatory = $true)]
        [pscustomobject] $Definition
    )

    switch ($Setting.settingType) {
        'simpleInteger' {
            return @(ConvertTo-GraphSimpleSetting -DefinitionId $Definition.id -SettingType $Setting.settingType -Value ([int] $Setting.value))
        }
        'simpleString' {
            return @(ConvertTo-GraphSimpleSetting -DefinitionId $Definition.id -SettingType $Setting.settingType -Value ([string] $Setting.value))
        }
        'multiString' {
            $payloads = foreach ($item in $Setting.value) {
                ConvertTo-GraphSimpleSetting -DefinitionId $Definition.id -SettingType 'simpleString' -Value ([string] $item)
            }

            return @($payloads)
        }
        'choice' {
            $option = Find-ChoiceOption -Setting $Setting -Definition $Definition
            return @(ConvertTo-GraphChoiceSetting -DefinitionId $Definition.id -OptionItemId ([string] $option.itemId))
        }
        default {
            throw "Unsupported settingType '$($Setting.settingType)' for setting '$($Setting.key)'."
        }
    }
}

function Invoke-ConfigurationPolicyCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Policy
    )

    $body = @{
        '@odata.type'     = '#microsoft.graph.deviceManagementConfigurationPolicy'
        name              = [string] $Policy.name
        description       = [string] $Policy.description
        platforms         = [string] $Policy.platforms
        technologies      = [string] $Policy.technologies
        roleScopeTagIds   = @('0')
    }

    return Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' -Body ($body | ConvertTo-Json -Depth 20) -ContentType 'application/json'
}

function Invoke-ConfigurationSettingCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $PolicyId,

        [Parameter(Mandatory = $true)]
        [hashtable] $SettingPayload
    )

    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId/settings"
    return Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($SettingPayload | ConvertTo-Json -Depth 50) -ContentType 'application/json'
}

function Invoke-PolicyAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $PolicyId,

        [Parameter(Mandatory = $true)]
        [string] $GroupId
    )

    $body = @{
        assignments = @(
            @{
                target = @{
                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                    groupId       = $GroupId
                }
            }
        )
    }

    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$PolicyId/assign"
    return Invoke-MgGraphRequest -Method POST -Uri $uri -Body ($body | ConvertTo-Json -Depth 20) -ContentType 'application/json'
}

$policyFiles = Get-PolicyFile -Path $PolicyPath
$policyRecords = foreach ($policyFile in $policyFiles) {
    Read-PolicyFile -File $policyFile
}

$validationResults = foreach ($policyRecord in $policyRecords) {
    Test-PolicyObject -PolicyRecord $policyRecord
}

if ($OfflineValidationOnly) {
    $validationResults
    return
}

if (-not $SkipConnect) {
    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Connect-MgGraph was not found. Install Microsoft Graph PowerShell Authentication before running online deployment.'
    }

    Connect-MgGraph -Scopes $Scopes -NoWelcome
}

if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
    throw 'Invoke-MgGraphRequest was not found. Install Microsoft Graph PowerShell Authentication before running online deployment.'
}

$definitions = Get-IntuneSettingDefinition
$deploymentResults = [System.Collections.Generic.List[object]]::new()

foreach ($policyRecord in $policyRecords) {
    $policy = $policyRecord.Policy
    $resolvedSettings = foreach ($setting in $policy.settings) {
        $definition = Resolve-SettingDefinition -Setting $setting -Definitions $definitions
        $payloads = ConvertTo-GraphSettingPayload -Setting $setting -Definition $definition

        [pscustomobject]@{
            Setting    = $setting
            Definition = $definition
            Payloads   = $payloads
        }
    }

    if ($PSCmdlet.ShouldProcess($policy.name, 'Create Intune Settings Catalog policy')) {
        $createdPolicy = Invoke-ConfigurationPolicyCreate -Policy $policy
        $deploymentResults.Add([pscustomobject]@{
                Type     = 'Policy'
                Name     = $policy.name
                Id       = $createdPolicy.id
                File     = $policyRecord.File.FullName
                Created  = $true
            })

        foreach ($resolvedSetting in $resolvedSettings) {
            foreach ($payload in $resolvedSetting.Payloads) {
                $createdSetting = Invoke-ConfigurationSettingCreate -PolicyId $createdPolicy.id -SettingPayload $payload
                $deploymentResults.Add([pscustomobject]@{
                        Type                = 'Setting'
                        PolicyName          = $policy.name
                        PolicyId            = $createdPolicy.id
                        SettingKey          = $resolvedSetting.Setting.key
                        SettingDefinitionId = $resolvedSetting.Definition.id
                        Id                  = $createdSetting.id
                        Created             = $true
                    })
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($AssignToGroupId)) {
            $assignmentTarget = "$($policy.name) to group $AssignToGroupId"
            if ($PSCmdlet.ShouldProcess($assignmentTarget, 'Assign Intune Settings Catalog policy')) {
                $assignment = Invoke-PolicyAssignment -PolicyId $createdPolicy.id -GroupId $AssignToGroupId
                $deploymentResults.Add([pscustomobject]@{
                        Type     = 'Assignment'
                        PolicyName = $policy.name
                        PolicyId  = $createdPolicy.id
                        GroupId   = $AssignToGroupId
                        Result    = $assignment
                        Created   = $true
                    })
            }
        }
    }
    else {
        foreach ($resolvedSetting in $resolvedSettings) {
            $deploymentResults.Add([pscustomobject]@{
                    Type                = 'WhatIfSetting'
                    PolicyName          = $policy.name
                    SettingKey          = $resolvedSetting.Setting.key
                    SettingPickerPath   = $resolvedSetting.Setting.settingPickerPath
                    SettingDefinitionId = $resolvedSetting.Definition.id
                    PayloadCount        = $resolvedSetting.Payloads.Count
                    Created             = $false
                })
        }

        if (-not [string]::IsNullOrWhiteSpace($AssignToGroupId)) {
            $deploymentResults.Add([pscustomobject]@{
                    Type       = 'WhatIfAssignment'
                    PolicyName = $policy.name
                    GroupId    = $AssignToGroupId
                    Created    = $false
                })
        }
    }
}

if ($PassThru -or $WhatIfPreference) {
    $deploymentResults
}
else {
    $validationResults
}
