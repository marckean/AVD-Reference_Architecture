<#
.SYNOPSIS
    Builds Intune Win32 app packages (.intunewin) for a set of test apps, with detection scripts and a
    sheet of the exact values to enter in the Intune admin center.

.DESCRIPTION
    Run on any Windows 10 or 11 machine with internet access and Windows PowerShell 5.1 or PowerShell 7:
    an admin workstation, a packaging VM, or a test session host.

        .\New-Win32TestAppPackages.ps1                                  # all apps in apps.json
        .\New-Win32TestAppPackages.ps1 -Apps vcredist-x64, webrtc-redirector, teams-vdi
        .\New-Win32TestAppPackages.ps1 -SourceFolder D:\Installers      # installers you already have

    For each app it:
      1. downloads the installer from the vendor URL in apps.json (or the latest GitHub release asset), unless
         a file with the same name is in -SourceFolder;
      2. checks the Authenticode signature is Valid and names the expected signer (stops if not);
      3. stages AppInstaller.ps1, the app's app.json and the installer, and runs the Microsoft Win32 Content
         Prep Tool (IntuneWinAppUtil.exe) to make <id>.intunewin;
      4. writes a detection script, Detect-<id>.ps1.
    Then it writes intune-entries.md and intune-entries.csv: name, publisher, version, install and uninstall
    commands, detection script, return codes and dependencies, ready to type into the admin center.

    IntuneWinAppUtil.exe comes from -IntuneWinAppUtilPath, or is downloaded from Microsoft's GitHub repository
    (microsoft/Microsoft-Win32-Content-Prep-Tool) and its signature checked before it's run.
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path -Path (Get-Location) -ChildPath 'win32-test-apps-out'),
    [string[]]$Apps,
    [string]$SourceFolder,
    [string]$IntuneWinAppUtilPath,
    [string]$AppsJsonPath = (Join-Path -Path $PSScriptRoot -ChildPath 'apps.json')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is far slower with the progress bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Write-Step { param([string]$Text) Write-Host ''; Write-Host ('== {0}' -f $Text) -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host ('   OK   {0}' -f $Text) -ForegroundColor Green }
function Write-Info { param([string]$Text) Write-Host ('   ..   {0}' -f $Text) }

if ($env:OS -ne 'Windows_NT') { throw 'Run this on Windows: IntuneWinAppUtil.exe and signature checks need it.' }
if (-not (Test-Path -Path $AppsJsonPath)) { throw ('apps.json not found: {0}' -f $AppsJsonPath) }
$installerScript = Join-Path -Path $PSScriptRoot -ChildPath 'AppInstaller.ps1'
if (-not (Test-Path -Path $installerScript)) { throw ('AppInstaller.ps1 must sit next to this script: {0}' -f $installerScript) }

$catalog = Get-Content -Raw -Path $AppsJsonPath | ConvertFrom-Json
if ($catalog.schema -ne 'pd-win32-apps/1') { throw 'apps.json has an unknown schema.' }
$selected = @($catalog.apps)
if ($Apps) {
    $unknown = @($Apps | Where-Object { $_ -notin @($catalog.apps.id) })
    if ($unknown) { throw ('Unknown app id(s): {0}. Known: {1}' -f ($unknown -join ', '), (@($catalog.apps.id) -join ', ')) }
    $selected = @($catalog.apps | Where-Object { $_.id -in $Apps })
    foreach ($a in $selected) {
        foreach ($d in @($a.dependsOn)) { if ($d -and $d -notin $Apps) { Write-Info ('{0} depends on {1}, which isn''t in -Apps. Package it too, or it must already be in Intune.' -f $a.id, $d) } }
    }
}

$downloads = Join-Path $OutputFolder 'downloads'
$staging = Join-Path $OutputFolder 'staging'
$packages = Join-Path $OutputFolder 'packages'
$detection = Join-Path $OutputFolder 'detection'
foreach ($dir in @($OutputFolder, $downloads, $staging, $packages, $detection)) { if (-not (Test-Path -Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force } }

function Test-Signature {
    param([string]$Path, [string]$ExpectedSigner)
    $sig = Get-AuthenticodeSignature -FilePath $Path
    if ($sig.Status -ne 'Valid') { throw ('{0}: signature status is {1}. Not packaging it.' -f (Split-Path $Path -Leaf), $sig.Status) }
    $subject = $sig.SignerCertificate.Subject
    if ($ExpectedSigner -and $subject -notlike ('*CN={0}*' -f $ExpectedSigner) -and $subject -notlike ('*O={0}*' -f $ExpectedSigner)) {
        throw ('{0}: signed by "{1}", expected "{2}". Check the download, then update apps.json if the publisher changed.' -f (Split-Path $Path -Leaf), $subject, $ExpectedSigner)
    }
    Write-Ok ('{0}: signature valid ({1})' -f (Split-Path $Path -Leaf), $subject)
}

function Get-Source {
    # Returns the local path of one source file: from -SourceFolder, the download cache, or the internet.
    param($Source)
    $target = Join-Path $downloads $Source.fileName
    if ($SourceFolder -and (Test-Path -Path (Join-Path $SourceFolder $Source.fileName))) {
        Copy-Item -Path (Join-Path $SourceFolder $Source.fileName) -Destination $target -Force
        Write-Info ('{0}: from {1}' -f $Source.fileName, $SourceFolder)
    } elseif (-not (Test-Path -Path $target)) {
        $url = $Source.url
        if ($Source.github) {
            $release = Invoke-RestMethod -Uri ('https://api.github.com/repos/{0}/releases/latest' -f $Source.github) -Headers @{ 'User-Agent' = 'New-Win32TestAppPackages' }
            $asset = @($release.assets | Where-Object { $_.name -match $Source.assetPattern }) | Select-Object -First 1
            if (-not $asset) { throw ('No asset matching {0} in the latest {1} release ({2}).' -f $Source.assetPattern, $Source.github, $release.tag_name) }
            $url = $asset.browser_download_url
            Write-Info ('{0}: latest release {1}, {2}' -f $Source.github, $release.tag_name, $asset.name)
        }
        Write-Info ('Downloading {0}' -f $url)
        Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
    } else {
        Write-Info ('{0}: already downloaded' -f $Source.fileName)
    }
    if ($Source.signer) { Test-Signature -Path $target -ExpectedSigner $Source.signer }
    elseif ($Source.note) { Write-Info ('{0}: {1}' -f $Source.fileName, $Source.note) }
    return $target
}

function New-DetectionScript {
    param($App)
    $d = $App.detection
    $head = "# Intune custom detection script for $($App.name). Run as 64-bit; exits 0 with output when installed.`r`n"
    switch ($d.type) {
        'registry' {
            $body = "`$v = (Get-ItemProperty -Path '$($d.key)' -Name '$($d.value)' -ErrorAction SilentlyContinue).'$($d.value)'`r`n" +
                    "if (`$null -ne `$v -and `$v -eq $($d.equals)) { Write-Output 'Detected'; exit 0 }`r`nexit 1`r`n"
        }
        'file' {
            $body = "if (Test-Path -Path '$($d.path)') { Write-Output 'Detected'; exit 0 }`r`nexit 1`r`n"
        }
        'uninstallName' {
            $body = "`$roots = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'`r`n" +
                    "foreach (`$root in `$roots) {`r`n" +
                    "    if (-not (Test-Path -Path `$root)) { continue }`r`n" +
                    "    foreach (`$k in Get-ChildItem -Path `$root) {`r`n" +
                    "        `$p = Get-ItemProperty -Path `$k.PSPath -ErrorAction SilentlyContinue`r`n" +
                    "        if (`$p -and `$p.DisplayName -like '$($d.displayName)') { Write-Output ('Detected ' + `$p.DisplayVersion); exit 0 }`r`n" +
                    "    }`r`n}`r`nexit 1`r`n"
        }
        'teams' {
            $body = "`$pkg = Get-AppxProvisionedPackage -Online | Where-Object { `$_.DisplayName -eq 'MSTeams' }`r`n" +
                    "`$key = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Teams' -Name 'IsWVDEnvironment' -ErrorAction SilentlyContinue).IsWVDEnvironment`r`n" +
                    "if (`$pkg -and `$key -eq 1) { Write-Output ('Detected ' + `$pkg.Version); exit 0 }`r`nexit 1`r`n"
        }
        default { throw ('{0}: unknown detection type {1}' -f $App.id, $d.type) }
    }
    $path = Join-Path $detection ('Detect-{0}.ps1' -f $App.id)
    Set-Content -Path $path -Value ($head + $body) -Encoding UTF8
    return $path
}

# ---------------------------------------------------------------------------------------------------
Write-Step 'Microsoft Win32 Content Prep Tool'
if (-not $IntuneWinAppUtilPath) {
    $IntuneWinAppUtilPath = Join-Path $OutputFolder 'IntuneWinAppUtil.exe'
    if (-not (Test-Path -Path $IntuneWinAppUtilPath)) {
        Write-Info 'Downloading IntuneWinAppUtil.exe from github.com/microsoft/Microsoft-Win32-Content-Prep-Tool'
        Invoke-WebRequest -Uri 'https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe' -OutFile $IntuneWinAppUtilPath -UseBasicParsing
    }
}
if (-not (Test-Path -Path $IntuneWinAppUtilPath)) { throw ('IntuneWinAppUtil.exe not found: {0}' -f $IntuneWinAppUtilPath) }
Test-Signature -Path $IntuneWinAppUtilPath -ExpectedSigner 'Microsoft Corporation'

# ---------------------------------------------------------------------------------------------------
$rows = New-Object System.Collections.Generic.List[object]
foreach ($app in $selected) {
    Write-Step ('{0} ({1})' -f $app.name, $app.id)
    $stage = Join-Path $staging $app.id
    if (Test-Path -Path $stage) { Remove-Item -Path $stage -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $stage -Force

    $version = ''
    foreach ($src in @($app.sources)) {
        $local = Get-Source -Source $src
        Copy-Item -Path $local -Destination (Join-Path $stage $src.fileName) -Force
        if ($src.fileName -eq $app.install.file) {
            $vi = (Get-Item -Path $local).VersionInfo
            if ($vi.ProductVersion) { $version = $vi.ProductVersion.Trim() }
        }
    }
    Copy-Item -Path $installerScript -Destination (Join-Path $stage 'AppInstaller.ps1') -Force
    $app | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $stage 'app.json') -Encoding UTF8

    $out = Join-Path $packages $app.id
    if (Test-Path -Path $out) { Remove-Item -Path $out -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $out -Force
    $p = Start-Process -FilePath $IntuneWinAppUtilPath -ArgumentList ('-c "{0}" -s "AppInstaller.ps1" -o "{1}" -q' -f $stage, $out) -Wait -PassThru -NoNewWindow
    $built = Join-Path $out 'AppInstaller.intunewin'
    if ($p.ExitCode -ne 0 -or -not (Test-Path -Path $built)) { throw ('IntuneWinAppUtil failed for {0} (exit {1}).' -f $app.id, $p.ExitCode) }
    $final = Join-Path $packages ('{0}.intunewin' -f $app.id)
    Move-Item -Path $built -Destination $final -Force
    Remove-Item -Path $out -Recurse -Force
    $detect = New-DetectionScript -App $app
    $sizeMb = [math]::Round((Get-Item -Path $final).Length / 1MB, 1)
    Write-Ok ('{0} ({1} MB), detection {2}' -f (Split-Path $final -Leaf), $sizeMb, (Split-Path $detect -Leaf))

    $codes = @(0, 3010)
    if ($app.install.successCodes) { $codes = @($app.install.successCodes) }
    $rows.Add([pscustomobject]@{
        Id               = $app.id
        Name             = $app.name
        Publisher        = $app.publisher
        Version          = $(if ($version) { $version } else { 'see installer' })
        Package          = (Split-Path $final -Leaf)
        InstallCommand   = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\AppInstaller.ps1 -Action Install'
        UninstallCommand = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\AppInstaller.ps1 -Action Uninstall'
        InstallBehavior  = 'System'
        Detection        = ('Custom script: {0} (run as 32-bit: No; enforce signature check: No)' -f (Split-Path $detect -Leaf))
        ReturnCodes      = (($codes | ForEach-Object { if ([int]$_ -eq 3010) { '3010 soft reboot' } elseif ([int]$_ -eq 0) { '0 success' } else { '{0} success' -f $_ } }) -join '; ')
        DependsOn        = ((@($app.dependsOn) | Where-Object { $_ }) -join ', ')
        Why              = $app.why
    })
}

# ---------------------------------------------------------------------------------------------------
Write-Step 'Intune entries'
$csv = Join-Path $OutputFolder 'intune-entries.csv'
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$md = New-Object System.Text.StringBuilder
$null = $md.AppendLine('# Intune Win32 app entries')
$null = $md.AppendLine('')
$null = $md.AppendLine('Intune admin center > Apps > Windows > Add > Windows app (Win32). For each app: select the .intunewin from packages, then use these values. Requirements: 64-bit, minimum Windows 11 21H2 (or your own baseline). Add the dependencies on the Dependencies tab with automatic install on.')
$null = $md.AppendLine('')
foreach ($r in $rows) {
    $null = $md.AppendLine(('## {0}' -f $r.Name))
    $null = $md.AppendLine('')
    $null = $md.AppendLine(('- Package: packages\{0}' -f $r.Package))
    $null = $md.AppendLine(('- Publisher: {0}; version: {1}' -f $r.Publisher, $r.Version))
    $null = $md.AppendLine(('- Install command: `{0}`' -f $r.InstallCommand))
    $null = $md.AppendLine(('- Uninstall command: `{0}`' -f $r.UninstallCommand))
    $null = $md.AppendLine(('- Install behavior: {0}; device restart behavior: Determine behavior based on return codes' -f $r.InstallBehavior))
    $null = $md.AppendLine(('- Return codes: {0}' -f $r.ReturnCodes))
    $null = $md.AppendLine(('- Detection rules: {0}' -f $r.Detection))
    $null = $md.AppendLine(('- Dependencies: {0}' -f $(if ($r.DependsOn) { $r.DependsOn } else { 'none' })))
    $null = $md.AppendLine(('- Why: {0}' -f $r.Why))
    $null = $md.AppendLine('')
}
$mdPath = Join-Path $OutputFolder 'intune-entries.md'
Set-Content -Path $mdPath -Value $md.ToString() -Encoding UTF8
Write-Ok ('{0} package(s) in {1}' -f $rows.Count, $packages)
Write-Ok ('Detection scripts in {0}' -f $detection)
Write-Ok ('Values to enter: {0} (and {1})' -f $mdPath, (Split-Path $csv -Leaf))
