<#
.SYNOPSIS
Inventories applications in a golden image.

.DESCRIPTION
Inventories application evidence from a golden image without changing the image.

Online mode runs inside a VM built from the image. Offline mode points at the Windows folder of a mounted image disk, loads the mounted image's SOFTWARE registry hive under a temporary HKLM key, reads uninstall entries, and unloads the hive in a finally block.

The script reports per-machine 64-bit and 32-bit Uninstall registry entries, provisioned Appx and MSIX packages, App-V client packages when App-V client cmdlets are present, and non-Microsoft services and drivers where they can be observed without modifying the image.

.PARAMETER Mode
Online inventories the running operating system. Offline reads a mounted image Windows folder.

.PARAMETER WindowsPath
Path to the Windows folder in a mounted image disk, for example F:\Windows. Required in Offline mode.

.PARAMETER IncludeMicrosoft
Includes entries with Microsoft publishers or Windows paths. By default the output focuses on non-Microsoft application candidates, while still keeping inventory source counts honest.

.PARAMETER CsvPath
Optional path for a CSV export.

.PARAMETER JsonPath
Optional path for a JSON export.

.EXAMPLE
.\Get-ImageApplicationInventory.ps1 -Mode Online -CsvPath C:\Temp\image-apps.csv -JsonPath C:\Temp\image-apps.json

Inventories applications from a VM running the golden image.

.EXAMPLE
.\Get-ImageApplicationInventory.ps1 -Mode Offline -WindowsPath F:\Windows -JsonPath C:\Temp\offline-image-apps.json

Inventories a mounted image disk. The command must run elevated because reg load requires administrative rights.

.NOTES
Sources:
https://learn.microsoft.com/windows-server/administration/windows-commands/reg-load
https://learn.microsoft.com/windows-server/administration/windows-commands/reg-unload
https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key
https://learn.microsoft.com/powershell/module/dism/get-appxprovisionedpackage
https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare

.LINK
https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Online', 'Offline')]
    [string] $Mode,

    [Parameter()]
    [ValidateScript({
        if (-not [string]::IsNullOrWhiteSpace($_) -and -not (Test-Path -LiteralPath $_ -PathType Container)) {
            throw "WindowsPath '$_' was not found."
        }
        return $true
    })]
    [string] $WindowsPath,

    [Parameter()]
    [switch] $IncludeMicrosoft,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CsvPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $JsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:IncludeMicrosoftEntries = $IncludeMicrosoft.IsPresent

function Test-CurrentProcessAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-MicrosoftEntry {
    param(
        [Parameter()]
        [string] $Publisher,

        [Parameter()]
        [string] $Path
    )

    if (-not [string]::IsNullOrWhiteSpace($Publisher) -and $Publisher -match '(?i)^Microsoft\b|Microsoft Corporation|Microsoft Windows') {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($Path) -and $Path -match '(?i)\\Windows\\|\\Program Files\\WindowsApps\\|\\Program Files\\Microsoft\\') {
        return $true
    }

    return $false
}

function ConvertTo-BooleanValue {
    param(
        [Parameter()]
        [object] $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    return ([string]$Value) -eq '1' -or ([string]$Value) -ieq 'true'
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-MsiProductCode {
    param(
        [Parameter()]
        [string] $KeyName
    )

    return $KeyName -match '^\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}$'
}

function Get-UninstallEntry {
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $RegistryView
    )

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return @()
    }

    foreach ($subKey in Get-ChildItem -LiteralPath $RootPath -ErrorAction SilentlyContinue) {
        $values = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction SilentlyContinue
        if ($null -eq $values) {
            continue
        }

        $displayName = [string](Get-PropertyValue -InputObject $values -Name 'DisplayName')
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            continue
        }

        $installLocation = [string](Get-PropertyValue -InputObject $values -Name 'InstallLocation')
        $publisher = [string](Get-PropertyValue -InputObject $values -Name 'Publisher')
        if (-not $script:IncludeMicrosoftEntries -and (Test-MicrosoftEntry -Publisher $publisher -Path $installLocation)) {
            continue
        }

        $keyName = Split-Path -Path $subKey.Name -Leaf
        $windowsInstaller = ConvertTo-BooleanValue -Value (Get-PropertyValue -InputObject $values -Name 'WindowsInstaller')

        [pscustomobject]@{
            InventoryType = 'UninstallRegistry'
            SourceType = if ($windowsInstaller -or (Test-MsiProductCode -KeyName $keyName)) { 'MSI' } else { 'InstalledApplication' }
            RegistryView = $RegistryView
            RegistryKeyName = $keyName
            IsMsiProductCode = Test-MsiProductCode -KeyName $keyName
            DisplayName = $displayName
            DisplayVersion = [string](Get-PropertyValue -InputObject $values -Name 'DisplayVersion')
            Publisher = $publisher
            InstallLocation = $installLocation
            InstallSource = [string](Get-PropertyValue -InputObject $values -Name 'InstallSource')
            UninstallString = [string](Get-PropertyValue -InputObject $values -Name 'UninstallString')
            QuietUninstallString = [string](Get-PropertyValue -InputObject $values -Name 'QuietUninstallString')
            ModifyPath = [string](Get-PropertyValue -InputObject $values -Name 'ModifyPath')
            EstimatedSize = Get-PropertyValue -InputObject $values -Name 'EstimatedSize'
            InstallDate = [string](Get-PropertyValue -InputObject $values -Name 'InstallDate')
            WindowsInstaller = $windowsInstaller
            SystemComponent = ConvertTo-BooleanValue -Value (Get-PropertyValue -InputObject $values -Name 'SystemComponent')
            ParentKeyName = [string](Get-PropertyValue -InputObject $values -Name 'ParentKeyName')
            ParentDisplayName = [string](Get-PropertyValue -InputObject $values -Name 'ParentDisplayName')
            ReleaseType = [string](Get-PropertyValue -InputObject $values -Name 'ReleaseType')
            NoRemove = ConvertTo-BooleanValue -Value (Get-PropertyValue -InputObject $values -Name 'NoRemove')
            NoModify = ConvertTo-BooleanValue -Value (Get-PropertyValue -InputObject $values -Name 'NoModify')
            NoRepair = ConvertTo-BooleanValue -Value (Get-PropertyValue -InputObject $values -Name 'NoRepair')
            URLInfoAbout = [string](Get-PropertyValue -InputObject $values -Name 'URLInfoAbout')
            HelpLink = [string](Get-PropertyValue -InputObject $values -Name 'HelpLink')
            LearnReferences = @('https://learn.microsoft.com/windows/win32/msi/uninstall-registry-key')
        }
    }
}

function Get-ProvisionedPackageEntry {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Online', 'Offline')]
        [string] $InventoryMode,

        [Parameter()]
        [string] $ImageRoot
    )

    $packages = try {
        if ($InventoryMode -eq 'Online') {
            @(Get-AppxProvisionedPackage -Online)
        }
        else {
            @(Get-AppxProvisionedPackage -Path $ImageRoot)
        }
    }
    catch {
        Write-Warning "Get-AppxProvisionedPackage failed in $InventoryMode mode: $($_.Exception.Message)"
        @()
    }

    foreach ($package in $packages) {
        if (-not $script:IncludeMicrosoftEntries -and $package.PackageName -match '(?i)^Microsoft\.') {
            continue
        }

        [pscustomobject]@{
            InventoryType = 'ProvisionedAppx'
            SourceType = 'ProvisionedAppx'
            DisplayName = $package.DisplayName
            PackageName = $package.PackageName
            Version = $package.Version
            Publisher = $package.PublisherId
            Architecture = $package.Architecture
            InstallLocation = $package.InstallLocation
            LearnReferences = @('https://learn.microsoft.com/powershell/module/dism/get-appxprovisionedpackage')
        }
    }
}

function Get-AppVClientPackageEntry {
    $command = Get-Command -Name Get-AppvClientPackage -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return @()
    }

    foreach ($package in Get-AppvClientPackage) {
        [pscustomobject]@{
            InventoryType = 'AppVClientPackage'
            SourceType = 'AppV'
            DisplayName = $package.Name
            PackageName = $package.PackageId
            Version = $package.Version
            PackageVersionId = $package.VersionId
            Path = $package.Path
            IsPublishedGlobally = $package.IsPublishedGlobally
            LearnReferences = @('https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy')
        }
    }
}

function Get-OnlineServiceAndDriverEntry {
    param(
        [Parameter(Mandatory)]
        [object[]] $Applications
    )

    $installLocations = @($Applications | Where-Object { -not [string]::IsNullOrWhiteSpace($_.InstallLocation) } | Select-Object -Property DisplayName, InstallLocation)

    $services = Get-CimInstance -ClassName Win32_Service | Where-Object {
        $pathName = [string]$_.PathName
        $startName = [string]$_.StartName
        ($script:IncludeMicrosoftEntries -or ($pathName -notmatch '(?i)\\Windows\\|Microsoft' -and $startName -notmatch '(?i)^NT SERVICE\\|^LocalSystem$'))
    }

    foreach ($service in $services) {
        $associatedApplication = $null
        foreach ($app in $installLocations) {
            if (-not [string]::IsNullOrWhiteSpace($app.InstallLocation) -and [string]$service.PathName -like "$($app.InstallLocation)*") {
                $associatedApplication = $app.DisplayName
                break
            }
        }

        [pscustomobject]@{
            InventoryType = 'Service'
            SourceType = 'Service'
            ServiceName = $service.Name
            DisplayName = $service.DisplayName
            State = $service.State
            StartMode = $service.StartMode
            StartName = $service.StartName
            PathName = $service.PathName
            AssociatedApplication = $associatedApplication
            LearnReferences = @('https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare')
        }
    }

    $drivers = Get-CimInstance -ClassName Win32_SystemDriver | Where-Object {
        $pathName = [string]$_.PathName
        $script:IncludeMicrosoftEntries -or $pathName -notmatch '(?i)\\Windows\\'
    }

    foreach ($driver in $drivers) {
        [pscustomobject]@{
            InventoryType = 'Driver'
            SourceType = 'Driver'
            DriverName = $driver.Name
            DisplayName = $driver.DisplayName
            State = $driver.State
            StartMode = $driver.StartMode
            PathName = $driver.PathName
            AssociatedApplication = $null
            LearnReferences = @('https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare')
        }
    }
}

function Get-OfflineDriverEntry {
    param(
        [Parameter(Mandatory)]
        [string] $MountedWindowsPath
    )

    $driverFolder = Join-Path -Path $MountedWindowsPath -ChildPath 'System32\drivers'
    if (-not (Test-Path -LiteralPath $driverFolder -PathType Container)) {
        return @()
    }

    foreach ($driverFile in Get-ChildItem -LiteralPath $driverFolder -Filter '*.sys' -File -ErrorAction SilentlyContinue) {
        $signature = Get-AuthenticodeSignature -LiteralPath $driverFile.FullName
        $subject = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { '' }
        if (-not $script:IncludeMicrosoftEntries -and $subject -match '(?i)Microsoft') {
            continue
        }

        [pscustomobject]@{
            InventoryType = 'Driver'
            SourceType = 'Driver'
            DriverName = $driverFile.BaseName
            DisplayName = $driverFile.Name
            PathName = $driverFile.FullName
            Publisher = $subject
            AssociatedApplication = $null
            LearnReferences = @('https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare')
        }
    }
}

function Invoke-RegLoad {
    param(
        [Parameter(Mandatory)]
        [string] $KeyName,

        [Parameter(Mandatory)]
        [string] $HivePath
    )

    $output = & reg.exe load $KeyName $HivePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "reg load failed with exit code $LASTEXITCODE. Output: $($output -join ' ')"
    }
}

function Invoke-RegUnload {
    param(
        [Parameter(Mandatory)]
        [string] $KeyName
    )

    $output = & reg.exe unload $KeyName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "reg unload failed with exit code $LASTEXITCODE. Output: $($output -join ' ')"
    }
}

if ($Mode -eq 'Offline' -and [string]::IsNullOrWhiteSpace($WindowsPath)) {
    throw 'WindowsPath is required in Offline mode.'
}

$inventory = @()
$loadedHiveKey = $null
$loadedHive = $false

try {
    if ($Mode -eq 'Online') {
        $applications = @(
            Get-UninstallEntry -RootPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -RegistryView '64-bit'
            Get-UninstallEntry -RootPath 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -RegistryView '32-bit'
        )
        $inventory += $applications
        $inventory += Get-ProvisionedPackageEntry -InventoryMode Online
        $inventory += Get-AppVClientPackageEntry
        $inventory += Get-OnlineServiceAndDriverEntry -Applications $applications
    }
    else {
        if (-not (Test-CurrentProcessAdministrator)) {
            throw 'Offline mode requires an elevated PowerShell session because reg load must load the mounted image SOFTWARE hive under HKLM.'
        }

        $softwareHive = Join-Path -Path $WindowsPath -ChildPath 'System32\Config\SOFTWARE'
        if (-not (Test-Path -LiteralPath $softwareHive -PathType Leaf)) {
            throw "SOFTWARE hive was not found at '$softwareHive'."
        }

        $imageRoot = Split-Path -Path $WindowsPath -Parent
        $loadedHiveKeyName = "AppAttachImageSoftware_$([Guid]::NewGuid().ToString('N'))"
        $loadedHiveKey = "HKLM\$loadedHiveKeyName"
        Invoke-RegLoad -KeyName $loadedHiveKey -HivePath $softwareHive
        $loadedHive = $true

        $applications = @(
            Get-UninstallEntry -RootPath "Registry::HKEY_LOCAL_MACHINE\$loadedHiveKeyName\Microsoft\Windows\CurrentVersion\Uninstall" -RegistryView '64-bit'
            Get-UninstallEntry -RootPath "Registry::HKEY_LOCAL_MACHINE\$loadedHiveKeyName\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -RegistryView '32-bit'
        )
        $inventory += $applications
        $inventory += Get-ProvisionedPackageEntry -InventoryMode Offline -ImageRoot $imageRoot
        $inventory += Get-OfflineDriverEntry -MountedWindowsPath $WindowsPath
    }
}
finally {
    if ($loadedHive -and -not [string]::IsNullOrWhiteSpace($loadedHiveKey)) {
        Invoke-RegUnload -KeyName $loadedHiveKey
    }
}

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $inventory | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $inventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonPath -Encoding utf8
}

$inventory
