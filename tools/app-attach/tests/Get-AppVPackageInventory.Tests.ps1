Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:InventoryScript = Join-Path -Path $script:ToolRoot -ChildPath 'Get-AppVPackageInventory.ps1'

    function Write-TestAppVPackage {
        param(
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter()]
            [string] $Manifest
        )

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Force
        }

        $tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path -Path $tempFolder -ChildPath 'AppxManifest.xml') -Value $Manifest -Encoding utf8
            [System.IO.Compression.ZipFile]::CreateFromDirectory($tempFolder, $Path)
        }
        finally {
            Remove-Item -LiteralPath $tempFolder -Recurse -Force
        }
    }
}

Describe 'Get-AppVPackageInventory.ps1' {
    BeforeEach {
        $script:FixtureRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        New-Item -Path $script:FixtureRoot -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:FixtureRoot) {
            Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force
        }
    }

    It 'reads identity, applications and integration points from a synthetic App-V package' {
        $packagePath = Join-Path -Path $script:FixtureRoot -ChildPath 'ContosoApp.appv'
        $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10">
  <Identity Name="Contoso.App" Publisher="CN=Contoso" Version="2.3.4.5" ProcessorArchitecture="x64" PackageId="pkg-1" VersionId="ver-1" />
  <Applications>
    <Application Id="ContosoApp" Executable="VFS\ProgramFilesX64\Contoso\App.exe" EntryPoint="Windows.FullTrustApplication">
      <VisualElements DisplayName="Contoso App" Description="Synthetic package" />
    </Application>
  </Applications>
  <Extensions>
    <Extension Category="AppV.Shortcut">
      <Shortcut Name="Contoso App" />
    </Extension>
    <Extension Category="AppV.FileTypeAssociation">
      <FileTypeAssociation Name=".cto" />
    </Extension>
    <Extension Category="AppV.URLProtocol">
      <URLProtocol Name="contoso" />
    </Extension>
    <Extension Category="AppV.COM">
      <COM Name="Contoso.Component" />
    </Extension>
    <Extension Category="AppV.Services">
      <Service Name="ContosoSvc" />
    </Extension>
    <Extension Category="AppV.Fonts">
      <Font Name="Contoso Sans" />
    </Extension>
    <Extension Category="AppV.Environment">
      <EnvironmentVariable Name="CONTOSO_HOME" />
    </Extension>
  </Extensions>
</Package>
'@
        Write-TestAppVPackage -Path $packagePath -Manifest $manifest

        $result = & $script:InventoryScript -Path $packagePath

        $result.PackageName | Should -Be 'Contoso.App'
        $result.Version | Should -Be '2.3.4.5'
        $result.PackageId | Should -Be 'pkg-1'
        $result.VersionId | Should -Be 'ver-1'
        $result.Applications[0].DisplayName | Should -Be 'Contoso App'
        $result.IntegrationPoints.Known.Shortcuts.Present | Should -BeTrue
        $result.IntegrationPoints.Known.FileTypeAssociations.Count | Should -Be 1
        $result.IntegrationPoints.Known.UrlProtocols.Count | Should -Be 1
        $result.IntegrationPoints.Known.Com.Count | Should -Be 1
        $result.IntegrationPoints.Known.Services.Count | Should -Be 1
        $result.IntegrationPoints.Known.Fonts.Count | Should -Be 1
        $result.IntegrationPoints.Known.EnvironmentVariables.Count | Should -Be 1
    }

    It 'detects standard dynamic configuration files and scripts' {
        $packagePath = Join-Path -Path $script:FixtureRoot -ChildPath 'Scripted.appv'
        $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="urn:test">
  <Identity Name="Contoso.Scripted" Publisher="CN=Contoso" Version="1.0.0.0" />
  <Applications />
</Package>
'@
        Write-TestAppVPackage -Path $packagePath -Manifest $manifest
        Set-Content -LiteralPath (Join-Path -Path $script:FixtureRoot -ChildPath 'Scripted_DeploymentConfig.xml') -Value '<DeploymentConfiguration><MachineScripts><StartVirtualEnvironmentScript Path="setup.cmd" /></MachineScripts></DeploymentConfiguration>' -Encoding utf8
        Set-Content -LiteralPath (Join-Path -Path $script:FixtureRoot -ChildPath 'Scripted_UserConfig.xml') -Value '<UserConfiguration />' -Encoding utf8

        $result = & $script:InventoryScript -Path $packagePath

        $result.HasDeploymentConfig | Should -BeTrue
        $result.DeploymentConfigContainsScripts | Should -BeTrue
        $result.HasUserConfig | Should -BeTrue
        $result.UserConfigContainsScripts | Should -BeFalse
    }

    It 'writes CSV and JSON exports' {
        $packagePath = Join-Path -Path $script:FixtureRoot -ChildPath 'Exported.appv'
        $csvPath = Join-Path -Path $script:FixtureRoot -ChildPath 'inventory.csv'
        $jsonPath = Join-Path -Path $script:FixtureRoot -ChildPath 'inventory.json'
        $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="urn:test">
  <Identity Name="Contoso.Exported" Publisher="CN=Contoso" Version="1.0.0.0" />
  <Applications />
</Package>
'@
        Write-TestAppVPackage -Path $packagePath -Manifest $manifest

        $null = & $script:InventoryScript -Path $packagePath -CsvPath $csvPath -JsonPath $jsonPath

        Test-Path -LiteralPath $csvPath | Should -BeTrue
        Test-Path -LiteralPath $jsonPath | Should -BeTrue
        (Import-Csv -LiteralPath $csvPath)[0].PackageName | Should -Be 'Contoso.Exported'
        (Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)[0].PackageName | Should -Be 'Contoso.Exported'
    }
}
