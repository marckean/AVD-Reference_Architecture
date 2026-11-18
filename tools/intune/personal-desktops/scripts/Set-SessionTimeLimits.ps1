# Intune platform script: Remote Desktop session time limits for personal desktops.
# Runs once as SYSTEM (64-bit). Writes the computer policy values that the Administrative Template
# "Session Time Limits" settings also use, so any number of minutes is possible:
#   MaxIdleTime          - an active but idle session is disconnected after this long.
#   MaxDisconnectionTime - a disconnected session is signed out (ended) after this long.
# Both are REG_DWORD in milliseconds under HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services.
# They apply from the user's next connection or sign-in.
# Source: https://learn.microsoft.com/troubleshoot/windows-server/remote/troubleshoot-unexpected-rds-session-locks-or-disconnections

$IdleLimitMinutes = 90
$DisconnectedLimitMinutes = 180

$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
if (-not (Test-Path -Path $key)) { $null = New-Item -Path $key -Force }
$null = New-ItemProperty -Path $key -Name 'MaxIdleTime' -PropertyType DWord -Value ([int]($IdleLimitMinutes * 60000)) -Force
$null = New-ItemProperty -Path $key -Name 'MaxDisconnectionTime' -PropertyType DWord -Value ([int]($DisconnectedLimitMinutes * 60000)) -Force

$now = Get-ItemProperty -Path $key
Write-Output ('MaxIdleTime={0} ms ({1} min), MaxDisconnectionTime={2} ms ({3} min)' -f $now.MaxIdleTime, $IdleLimitMinutes, $now.MaxDisconnectionTime, $DisconnectedLimitMinutes)
