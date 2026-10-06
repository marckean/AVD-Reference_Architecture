Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:TriageScript = Join-Path -Path $script:ToolRoot -ChildPath 'Invoke-ApplicationTriage.ps1'
    $script:RulesPath = Join-Path -Path $script:ToolRoot -ChildPath 'triage-rules.json'
}

Describe 'Invoke-ApplicationTriage.ps1' {
    BeforeEach {
        $script:FixtureRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        New-Item -Path $script:FixtureRoot -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:FixtureRoot) {
            Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force
        }
    }

    It 'classifies synthetic applications with editable regex rules' {
        $inputPath = Join-Path -Path $script:FixtureRoot -ChildPath 'inventory.json'
        @(
            [pscustomobject]@{
                DisplayName = 'Contoso VPN Driver'
                Publisher = 'Contoso'
                InstallLocation = 'C:\Program Files\Contoso VPN'
                InventoryType = 'UninstallRegistry'
                SourceType = 'InstalledApplication'
            }
            [pscustomobject]@{
                DisplayName = 'Contoso Legacy App-V'
                Publisher = 'Contoso'
                PackagePath = 'C:\Packages\ContosoLegacy.appv'
                InventoryType = 'AppVClientPackage'
                SourceType = 'AppV'
            }
            [pscustomobject]@{
                DisplayName = 'Visual C++ Redistributable'
                Publisher = 'Microsoft Corporation'
                InstallLocation = 'C:\Program Files\Microsoft'
                InventoryType = 'UninstallRegistry'
                SourceType = 'MSI'
            }
            [pscustomobject]@{
                DisplayName = 'Contoso Claims Viewer'
                Publisher = 'Contoso'
                InstallLocation = 'C:\Program Files\Contoso Claims Viewer'
                InventoryType = 'UninstallRegistry'
                SourceType = 'InstalledApplication'
            }
        ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inputPath -Encoding utf8

        $result = & $script:TriageScript -InputPath $inputPath -RulesPath $script:RulesPath

        ($result | Where-Object Name -eq 'Contoso VPN Driver').Recommendation | Should -Be 'ReviewDriversOrServices'
        ($result | Where-Object Name -eq 'Contoso Legacy App-V').Recommendation | Should -Be 'AppAttachAppV'
        ($result | Where-Object Name -eq 'Visual C++ Redistributable').Recommendation | Should -Be 'KeepInBaseImage'
        ($result | Where-Object Name -eq 'Contoso Claims Viewer').Recommendation | Should -Be 'AppAttachMsix'
    }

    It 'writes CSV and JSON exports' {
        $inputPath = Join-Path -Path $script:FixtureRoot -ChildPath 'inventory.csv'
        $csvPath = Join-Path -Path $script:FixtureRoot -ChildPath 'triage.csv'
        $jsonPath = Join-Path -Path $script:FixtureRoot -ChildPath 'triage.json'
        @(
            [pscustomobject]@{
                DisplayName = 'Contoso App'
                Publisher = 'Contoso'
                InstallLocation = 'C:\Program Files\Contoso App'
                InventoryType = 'UninstallRegistry'
                SourceType = 'InstalledApplication'
            }
        ) | Export-Csv -LiteralPath $inputPath -NoTypeInformation -Encoding utf8

        $null = & $script:TriageScript -InputPath $inputPath -RulesPath $script:RulesPath -CsvPath $csvPath -JsonPath $jsonPath

        Test-Path -LiteralPath $csvPath | Should -BeTrue
        Test-Path -LiteralPath $jsonPath | Should -BeTrue
        (Import-Csv -LiteralPath $csvPath)[0].Recommendation | Should -Be 'AppAttachMsix'
        (Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)[0].Recommendation | Should -Be 'AppAttachMsix'
    }
}
