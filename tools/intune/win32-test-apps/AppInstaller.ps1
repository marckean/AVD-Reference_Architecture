<#
.SYNOPSIS
    Installs or uninstalls one Win32 app from its Intune package. Runs on the session host as SYSTEM.

.DESCRIPTION
    New-Win32TestAppPackages.ps1 puts this script, app.json (one app's definition) and the app's installer
    files into each .intunewin package. Intune then runs:
        Install:   powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\AppInstaller.ps1 -Action Install
        Uninstall: powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\AppInstaller.ps1 -Action Uninstall
    Written for Windows PowerShell 5.1, which the Intune Management Extension uses.
    Logs go to C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Win32TestApp-<id>-<action>.log,
    so they're collected with the Intune diagnostics.
    The exit code is the installer's, so Intune can map 3010 to a soft reboot.
#>
param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Get-Content -Raw -Path (Join-Path $here 'app.json') | ConvertFrom-Json
$logDir = Join-Path $env:ProgramData 'Microsoft\IntuneManagementExtension\Logs'
if (-not (Test-Path -Path $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }
$log = Join-Path $logDir ('Win32TestApp-{0}-{1}.log' -f $app.id, $Action)

function Write-AppLog {
    param([string]$Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $log -Value $line
    Write-Output $line
}

function Invoke-AppProcess {
    param([string]$FilePath, [string]$ArgumentList)
    Write-AppLog ('Running: "{0}" {1}' -f $FilePath, $ArgumentList)
    if ([string]::IsNullOrWhiteSpace($ArgumentList)) {
        $p = Start-Process -FilePath $FilePath -Wait -PassThru -WindowStyle Hidden
    } else {
        $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -WindowStyle Hidden
    }
    Write-AppLog ('Exit code: {0}' -f $p.ExitCode)
    return [int]$p.ExitCode
}

function Expand-AppArgument {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return $Text.Replace('{here}', $here)
}

function Get-UninstallEntry {
    param([string]$DisplayNamePattern)
    $roots = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($root in $roots) {
        if (-not (Test-Path -Path $root)) { continue }
        foreach ($k in Get-ChildItem -Path $root) {
            $props = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($props -and $props.DisplayName -like $DisplayNamePattern) {
                return [pscustomobject]@{ KeyName = $k.PSChildName; DisplayName = $props.DisplayName; Version = $props.DisplayVersion; IsMsi = ($props.WindowsInstaller -eq 1) }
            }
        }
    }
    return $null
}

try {
    Write-AppLog ('{0} {1} ({2})' -f $Action, $app.name, $app.id)
    $successCodes = @(0, 3010)
    if ($app.install.successCodes) { $successCodes = @($app.install.successCodes | ForEach-Object { [int]$_ }) }
    $code = 0

    if ($Action -eq 'Install') {
        foreach ($r in @($app.preRegistry)) {
            if (-not $r) { continue }
            if (-not (Test-Path -Path $r.key)) { $null = New-Item -Path $r.key -Force }
            $null = New-ItemProperty -Path $r.key -Name $r.name -PropertyType $r.type -Value $r.value -Force
            Write-AppLog ('Set {0}\{1} = {2}' -f $r.key, $r.name, $r.value)
        }
        $file = Join-Path $here $app.install.file
        if (-not (Test-Path -Path $file)) { throw ('Installer not found in the package: {0}' -f $file) }
        switch ($app.install.type) {
            'exe' { $code = Invoke-AppProcess -FilePath $file -ArgumentList (Expand-AppArgument $app.install.args) }
            'msi' {
                $msiLog = Join-Path $logDir ('Win32TestApp-{0}-msi.log' -f $app.id)
                $code = Invoke-AppProcess -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList ('/i "{0}" {1} /l*v "{2}"' -f $file, (Expand-AppArgument $app.install.args), $msiLog)
            }
            default { throw ('Unknown install type: {0}' -f $app.install.type) }
        }
    } else {
        $successCodes = @(0, 3010, 1605, 1614)
        switch ($app.uninstall.type) {
            'exe' {
                $path = $app.uninstall.path
                if (-not $path) { $path = Join-Path $here $app.uninstall.file }
                if (-not (Test-Path -Path $path)) { Write-AppLog ('Uninstaller not found ({0}); treating as already removed.' -f $path); $code = 0 }
                else { $code = Invoke-AppProcess -FilePath $path -ArgumentList (Expand-AppArgument $app.uninstall.args) }
            }
            'msiByName' {
                $entry = Get-UninstallEntry -DisplayNamePattern $app.uninstall.displayName
                if (-not $entry) { Write-AppLog 'Not installed; nothing to remove.'; $code = 0 }
                elseif (-not $entry.IsMsi -or $entry.KeyName -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { throw ('{0} is not an MSI product, so it can''t be removed by product code.' -f $entry.DisplayName) }
                else { $code = Invoke-AppProcess -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList ('/x {0} /qn /norestart' -f $entry.KeyName) }
            }
            default { throw ('Unknown uninstall type: {0}' -f $app.uninstall.type) }
        }
    }

    if ($successCodes -notcontains $code) { Write-AppLog ('Failed with exit code {0}.' -f $code); exit $code }
    Write-AppLog 'Done.'
    exit $code
} catch {
    Write-AppLog ('Error: {0}' -f $_.Exception.Message)
    exit 1
}
