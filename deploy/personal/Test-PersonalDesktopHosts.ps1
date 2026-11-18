<#
.SYNOPSIS
    Read-only readiness check for the session hosts in an Azure Virtual Desktop host pool: join and Intune
    state, AVD agent, Teams media optimisation parts, Microsoft 365 Apps, session policy (clipboard, time
    limits, screen capture), Windows LAPS, antivirus and a few developer tools.

.DESCRIPTION
    Built for Azure Cloud Shell (PowerShell). No param block: set the variables, then run it.

        $SubscriptionId    = '00000000-0000-0000-0000-000000000000'
        $ResourceGroupName = 'rg-contoso-avd-personal'
        irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/personal/Test-PersonalDesktopHosts.ps1 | iex

    Optional: $HostPoolName (default: the only host pool in the resource group), $VmNames (a subset).
    It uses Run Command (RunPowerShellScript) on each running VM. The script it runs only reads: it changes
    nothing on the host and never prints secrets (the AVD registration token is not read).
    Deallocated VMs are listed and skipped; nothing is started.
#>

function Write-PtStep { param([string]$Text) Write-Host ''; Write-Host ("== {0}" -f $Text) -ForegroundColor Cyan }
function Write-PtOk { param([string]$Text) Write-Host ("   OK   {0}" -f $Text) -ForegroundColor Green }
function Write-PtInfo { param([string]$Text) Write-Host ("   ..   {0}" -f $Text) }
function Write-PtWarn { param([string]$Text) Write-Host ("   WARN {0}" -f $Text) -ForegroundColor Yellow }
function Stop-Pt { param([string]$Text) Write-Host ("   STOP {0}" -f $Text) -ForegroundColor Red; throw $Text }

function Get-PtSetting {
    param([string]$SettingName, $DefaultValue)
    $var = Get-Variable -Name $SettingName -ErrorAction SilentlyContinue
    if ($null -eq $var -or $null -eq $var.Value) { return $DefaultValue }
    if ($var.Value -is [string] -and [string]::IsNullOrWhiteSpace($var.Value)) { return $DefaultValue }
    return $var.Value
}

# The script that runs on each host (Windows PowerShell 5.1, as SYSTEM). Read-only.
$PtHostScript = @'
$ErrorActionPreference = 'SilentlyContinue'
function Get-Prop($Path, $Name) { $p = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue; if ($p) { return $p.$Name } else { return $null } }
function Get-Uninstall($Pattern) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in Get-ChildItem -Path $root -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DisplayName -like $Pattern) { return ('{0} {1}' -f $p.DisplayName, $p.DisplayVersion) }
        }
    }
    return $null
}
$ds = (& dsregcmd.exe /status) -join "`n"
function Get-Ds($Name) { if ($ds -match ('(?m)^\s*' + $Name + '\s*:\s*(.+?)\s*$')) { return $Matches[1] } else { return $null } }
$cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$ts = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
$laps = $null
foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS') {
    $b = Get-Prop $k 'BackupDirectory'
    if ($null -ne $b) { $laps = @{ 0 = 'disabled'; 1 = 'Entra ID'; 2 = 'AD' }[[int]$b]; break }
}
$c2r = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$teams = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'MSTeams' } | Select-Object -First 1
$av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue | ForEach-Object { $_.displayName })
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$r = [ordered]@{
    Computer           = $env:COMPUTERNAME
    OS                 = ('{0} {1}.{2}' -f (Get-Prop $cv 'ProductName'), (Get-Prop $cv 'CurrentBuild'), (Get-Prop $cv 'UBR'))
    DisplayVersion     = Get-Prop $cv 'DisplayVersion'
    UptimeHours        = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    FreeDiskGB         = [math]::Round($disk.FreeSpace / 1GB, 1)
    EntraJoined        = Get-Ds 'AzureAdJoined'
    DomainJoined       = Get-Ds 'DomainJoined'
    DomainName         = Get-Ds 'DomainName'
    TenantName         = Get-Ds 'TenantName'
    MdmUrl             = Get-Ds 'MdmUrl'
    IntuneExtension    = [string](Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue).Status
    RDAgent            = [string](Get-Service -Name RDAgentBootLoader -ErrorAction SilentlyContinue).Status
    AvdRegistered      = Get-Prop 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' 'IsRegistered'
    AvdAgent           = Get-Uninstall 'Remote Desktop Services Infrastructure Agent*'
    VcRedistX64        = Get-Prop 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64' 'Version'
    WebRtcRedirector   = Get-Uninstall 'Remote Desktop WebRTC Redirector Service*'
    TeamsIsWVD         = Get-Prop 'HKLM:\SOFTWARE\Microsoft\Teams' 'IsWVDEnvironment'
    TeamsProvisioned   = $(if ($teams) { [string]$teams.Version } else { $null })
    TeamsClassic       = Get-Uninstall 'Teams Machine-Wide Installer*'
    M365Apps           = Get-Prop $c2r 'VersionToReport'
    M365Products       = Get-Prop $c2r 'ProductReleaseIds'
    M365Channel        = Get-Prop $c2r 'CDNBaseUrl'
    SharedActivation   = Get-Prop $c2r 'SharedComputerLicensing'
    ClipServerToClient = Get-Prop $ts 'SCClipLevel'
    ClipClientToServer = Get-Prop $ts 'CSClipLevel'
    ClipDisabled       = Get-Prop $ts 'fDisableClip'
    DrivesDisabled     = Get-Prop $ts 'fDisableCdm'
    IdleLimitMin       = $(if ($null -ne (Get-Prop $ts 'MaxIdleTime')) { [int](Get-Prop $ts 'MaxIdleTime') / 60000 } else { $null })
    DisconnectLimitMin = $(if ($null -ne (Get-Prop $ts 'MaxDisconnectionTime')) { [int](Get-Prop $ts 'MaxDisconnectionTime') / 60000 } else { $null })
    ScreenCapture      = Get-Prop $ts 'fEnableScreenCaptureProtect'
    LapsBackup         = $laps
    Antivirus          = ($av -join ', ')
    Git                = Test-Path 'C:\Program Files\Git\cmd\git.exe'
    VSCode             = Test-Path 'C:\Program Files\Microsoft VS Code\Code.exe'
    AzureCli           = Test-Path 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
    PowerShell7        = Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe'
}
'PTJSON:' + ($r | ConvertTo-Json -Compress)
'@

function Invoke-PersonalDesktopHostCheck {
    $c = [ordered]@{
        SubscriptionId    = Get-PtSetting 'SubscriptionId' ''
        ResourceGroupName = Get-PtSetting 'ResourceGroupName' ''
        HostPoolName      = Get-PtSetting 'HostPoolName' ''
        VmNames           = @(Get-PtSetting 'VmNames' @())
    }
    Write-PtStep 'Settings'
    foreach ($k in $c.Keys) { Write-PtInfo ('{0} = {1}' -f $k, $(if ($c[$k] -is [array]) { $c[$k] -join ', ' } else { $c[$k] })) }
    if (-not $c.SubscriptionId -or -not $c.ResourceGroupName) { Stop-Pt 'Set $SubscriptionId and $ResourceGroupName first.' }

    $null = Set-AzContext -Subscription $c.SubscriptionId -ErrorAction Stop
    $pools = @(Get-AzWvdHostPool -ResourceGroupName $c.ResourceGroupName -ErrorAction Stop)
    if ($c.HostPoolName) { $pools = @($pools | Where-Object { $_.Name -eq $c.HostPoolName }) }
    if ($pools.Count -ne 1) { Stop-Pt ('Found {0} host pool(s) in {1}. Set $HostPoolName.' -f $pools.Count, $c.ResourceGroupName) }
    $hp = $pools[0]

    Write-PtStep ('AVD view of {0} ({1}, {2})' -f $hp.Name, $hp.HostPoolType, $hp.PersonalDesktopAssignmentType)
    $hosts = @(Get-AzWvdSessionHost -ResourceGroupName $c.ResourceGroupName -HostPoolName $hp.Name)
    foreach ($h in $hosts) {
        $n = ($h.Name -split '/')[-1]
        $failed = @($h.SessionHostHealthCheckResult | Where-Object { $_.HealthCheckResult -and $_.HealthCheckResult -notlike '*Succeeded*' } | ForEach-Object { $_.HealthCheckName })
        $line = '{0}: {1}, agent {2}, user {3}, heartbeat {4:yyyy-MM-dd HH:mm} UTC{5}' -f $n, $h.Status, $h.AgentVersion, $(if ($h.AssignedUser) { $h.AssignedUser } else { '(none)' }), $h.LastHeartBeat, $(if ($failed) { ', failed checks: ' + ($failed -join ', ') } else { '' })
        if ($h.Status -eq 'Available') { Write-PtOk $line } else { Write-PtWarn $line }
    }
    if ($hp.CustomRdpProperty) { Write-PtInfo ('RDP properties: {0}' -f $hp.CustomRdpProperty) }

    $vmNames = @($hosts | ForEach-Object { ((($_.Name -split '/')[-1]) -split '\.')[0] })
    if ($c.VmNames.Count -gt 0) { $vmNames = @($vmNames | Where-Object { $_ -in $c.VmNames }) }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pt-host-check-{0}.ps1' -f ([guid]::NewGuid().ToString('N')))
    Set-Content -Path $tmp -Value $PtHostScript -Encoding UTF8

    Write-PtStep 'Running the read-only check on each running host (about a minute)'
    $jobs = @{}
    foreach ($name in $vmNames) {
        $vm = Get-AzVM -ResourceGroupName $c.ResourceGroupName -Name $name -Status -ErrorAction SilentlyContinue
        if (-not $vm) {
            $other = Get-AzResource -ResourceType 'Microsoft.Compute/virtualMachines' -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($other) { $vm = Get-AzVM -ResourceGroupName $other.ResourceGroupName -Name $name -Status -ErrorAction SilentlyContinue }
        }
        if (-not $vm) { Write-PtWarn ('{0}: VM not found' -f $name); continue }
        $power = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
        if ($power -ne 'VM running') { Write-PtInfo ('{0}: {1}, skipped (nothing is started)' -f $name, $power); continue }
        $jobs[$name] = Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -VMName $name -CommandId 'RunPowerShellScript' -ScriptPath $tmp -AsJob
    }
    $results = @{}
    foreach ($name in $jobs.Keys) {
        $out = $jobs[$name] | Wait-Job -Timeout 600 | Receive-Job -ErrorAction SilentlyContinue
        $msg = (@($out.Value) | ForEach-Object { $_.Message }) -join "`n"
        $jsonLine = ($msg -split "`n" | Where-Object { $_ -like 'PTJSON:*' } | Select-Object -First 1)
        if ($jsonLine) { $results[$name] = ($jsonLine.Substring(7) | ConvertFrom-Json) }
        else { Write-PtWarn ('{0}: no result. Output: {1}' -f $name, $msg) }
    }
    Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue

    foreach ($name in ($results.Keys | Sort-Object)) {
        $r = $results[$name]
        Write-PtStep ('{0}: {1} ({2})' -f $name, $r.OS, $r.DisplayVersion)
        $checks = @(
            @('Join', ('Entra {0}, domain {1} {2}' -f $r.EntraJoined, $r.DomainJoined, $r.DomainName), ($r.EntraJoined -eq 'YES' -or $r.DomainJoined -eq 'YES')),
            @('Intune enrolment', $(if ($r.MdmUrl) { $r.MdmUrl } else { 'not enrolled' }), [bool]$r.MdmUrl),
            @('Intune Management Extension', [string]$r.IntuneExtension, ([string]$r.IntuneExtension -eq 'Running')),
            @('AVD agent', ('{0}; boot loader {1}; registered {2}' -f $r.AvdAgent, $r.RDAgent, $r.AvdRegistered), ($r.AvdRegistered -eq 1)),
            @('VC++ x64 runtime', [string]$r.VcRedistX64, [bool]$r.VcRedistX64),
            @('WebRTC Redirector', [string]$r.WebRtcRedirector, [bool]$r.WebRtcRedirector),
            @('Teams (new), machine-wide', $(if ($r.TeamsProvisioned) { $r.TeamsProvisioned } else { 'not provisioned' }), [bool]$r.TeamsProvisioned),
            @('Teams IsWVDEnvironment', [string]$r.TeamsIsWVD, ($r.TeamsIsWVD -eq 1)),
            @('Microsoft 365 Apps', ('{0} {1}; shared activation {2}' -f $r.M365Apps, $r.M365Products, $r.SharedActivation), [bool]$r.M365Apps),
            @('Clipboard policy', ('server>client {0}, client>server {1}, all off {2}' -f $r.ClipServerToClient, $r.ClipClientToServer, $r.ClipDisabled), ($null -ne $r.ClipServerToClient -or $null -ne $r.ClipClientToServer -or $null -ne $r.ClipDisabled)),
            @('Session time limits', ('idle {0} min, disconnected {1} min' -f $r.IdleLimitMin, $r.DisconnectLimitMin), ($null -ne $r.IdleLimitMin -and $null -ne $r.DisconnectLimitMin)),
            @('Windows LAPS backup', $(if ($r.LapsBackup) { $r.LapsBackup } else { 'no policy' }), [bool]$r.LapsBackup),
            @('Antivirus (Security Center)', $(if ($r.Antivirus) { $r.Antivirus } else { 'none registered' }), [bool]$r.Antivirus)
        )
        foreach ($chk in $checks) {
            $text = '{0}: {1}' -f $chk[0], $chk[1]
            if ($chk[2]) { Write-PtOk $text } else { Write-PtWarn $text }
        }
        Write-PtInfo ('Screen capture protection policy: {0}' -f $(if ($null -ne $r.ScreenCapture) { $r.ScreenCapture } else { 'not set' }))
        Write-PtInfo ('Developer tools: Git {0}, VS Code {1}, Azure CLI {2}, PowerShell 7 {3}' -f $r.Git, $r.VSCode, $r.AzureCli, $r.PowerShell7)
        Write-PtInfo ('Uptime {0} h, free disk C: {1} GB, classic Teams {2}' -f $r.UptimeHours, $r.FreeDiskGB, $(if ($r.TeamsClassic) { $r.TeamsClassic } else { 'not installed' }))
    }
    Write-PtStep 'Done'
    Write-PtInfo 'WARN lines are things to check, not always faults: an AD-joined pool has no Intune enrolment unless it is co-managed, and policies set by Group Policy show here too.'
}

Invoke-PersonalDesktopHostCheck
