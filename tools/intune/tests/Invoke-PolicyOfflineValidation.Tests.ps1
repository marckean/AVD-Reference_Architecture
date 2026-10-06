Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Intune policy examples' {
    BeforeAll {
        $script:ToolsRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        $script:DeployScript = Join-Path -Path $script:ToolsRoot -ChildPath 'Deploy-IntunePolicy.ps1'
        $script:PolicyRoot = Join-Path -Path $script:ToolsRoot -ChildPath 'policies'
    }

    It 'passes the deployment script offline validation' {
        { & $script:DeployScript -PolicyPath $script:PolicyRoot -OfflineValidationOnly } | Should -Not -Throw
    }

    It 'contains no long dash characters' {
        $files = Get-ChildItem -LiteralPath $script:ToolsRoot -Recurse -File
        foreach ($file in $files) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $content | Should -Not -Match '[\u2012\u2013\u2014\u2015]'
        }
    }

    It 'uses only Microsoft Learn URLs without locale segments' {
        $policies = Get-ChildItem -LiteralPath $script:PolicyRoot -Filter '*.json' -File
        foreach ($policyFile in $policies) {
            $policy = Get-Content -LiteralPath $policyFile.FullName -Raw | ConvertFrom-Json -Depth 50
            foreach ($setting in $policy.settings) {
                foreach ($learnLink in $setting.learnLinks) {
                    $learnLink | Should -Match '^https://learn\.microsoft\.com/'
                    $learnLink | Should -Not -Match 'https://learn\.microsoft\.com/[a-z]{2}-[a-z]{2}/'
                }
            }
        }
    }

    It 'does not hardcode settings catalog definition IDs' {
        $policies = Get-ChildItem -LiteralPath $script:PolicyRoot -Filter '*.json' -File
        foreach ($policyFile in $policies) {
            $policy = Get-Content -LiteralPath $policyFile.FullName -Raw | ConvertFrom-Json -Depth 50
            foreach ($setting in $policy.settings) {
                $setting.PSObject.Properties.Name | Should -Not -Contain 'settingDefinitionId'
            }
        }
    }
}
