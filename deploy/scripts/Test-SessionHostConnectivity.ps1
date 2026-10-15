<#
.SYNOPSIS
Checks, from inside a session host, whether it can reach what Azure Virtual Desktop and Microsoft Entra join need.

.DESCRIPTION
Read-only. Run it on a session host, for example through Run Command from Azure Cloud Shell:

  irm https://raw.githubusercontent.com/marckean/AVD-Reference_Architecture/main/deploy/scripts/Test-SessionHostConnectivity.ps1 -OutFile ./Test-SessionHostConnectivity.ps1
  $r = Invoke-AzVMRunCommand -ResourceGroupName <rg> -VMName <vm> -CommandId RunPowerShellScript -ScriptPath ./Test-SessionHostConnectivity.ps1
  $r.Value[0].Message

Run Command reaches the VM through the Azure platform, so it works even when the VM has no internet access.

It reports:
- Microsoft Entra join and Azure Virtual Desktop agent state
- DNS servers and the WinHTTP proxy
- each required endpoint: DNS answer and TCP connection
- whether TLS to Microsoft Entra ID is being intercepted
- optionally, an Azure Files private endpoint (-StorageAccountName)
- the failures reported by the Azure Virtual Desktop Agent URL Tool, if the agent is installed

Sources:
- https://learn.microsoft.com/azure/virtual-desktop/required-fqdn-endpoint
- https://learn.microsoft.com/entra/identity/devices/howto-vm-sign-in-azure-ad-windows#requirements
- https://learn.microsoft.com/azure/virtual-desktop/check-access-validate-required-fqdn-endpoint

Wildcard entries can't be tested directly, so a known host under each is tested instead. Run Command returns only the
last 4,096 bytes of output, so the report is kept short. Works in Windows PowerShell 5.1, which Run Command uses.
#>
param(
    [string]$StorageAccountName
)

$ErrorActionPreference = 'Continue'
$report = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$Text) { $report.Add($Text) }

function Resolve-Ipv4([string]$Name) {
    try {
        $address = [System.Net.Dns]::GetHostAddresses($Name) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($address) { return $address.IPAddressToString }
    }
    catch { }
    return $null
}

function Test-TcpPort([string]$Name, [int]$Port, [int]$TimeoutMs = 4000) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $attempt = $client.BeginConnect($Name, $Port, $null, $null)
        if (-not $attempt.AsyncWaitHandle.WaitOne($TimeoutMs)) { return 'timeout' }
        $client.EndConnect($attempt)
        return 'ok'
    }
    catch { return 'refused' }
    finally { $client.Close() }
}

function Get-TlsIssuer([string]$Name) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $attempt = $client.BeginConnect($Name, 443, $null, $null)
        if (-not $attempt.AsyncWaitHandle.WaitOne(5000)) { return 'no TCP connection' }
        $client.EndConnect($attempt)
        $acceptAny = [System.Net.Security.RemoteCertificateValidationCallback] { $true }
        $ssl = New-Object System.Net.Security.SslStream($client.GetStream(), $false, $acceptAny)
        $ssl.AuthenticateAsClient($Name)
        $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
        return $certificate.Issuer
    }
    catch {
        $inner = $_.Exception.InnerException
        if ($inner) { return "TLS failed: $($inner.Message)" }
        return "TLS failed: $($_.Exception.Message)"
    }
    finally { $client.Close() }
}

Add-Line ("== Session host connectivity check: {0}, {1:yyyy-MM-dd HH:mm} UTC ==" -f $env:COMPUTERNAME, (Get-Date).ToUniversalTime())

$dsreg = dsregcmd /status 2>$null
$entraJoined = ($dsreg | Select-String 'AzureAdJoined\s*:\s*(\w+)' | Select-Object -First 1)
$domainJoined = ($dsreg | Select-String 'DomainJoined\s*:\s*(\w+)' | Select-Object -First 1)
Add-Line ("Entra joined: {0} | AD joined: {1}" -f $(if ($entraJoined) { $entraJoined.Matches[0].Groups[1].Value } else { 'unknown' }), $(if ($domainJoined) { $domainJoined.Matches[0].Groups[1].Value } else { 'unknown' }))

$services = foreach ($name in 'RDAgentBootLoader', 'RDAgent') {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service) { "$name=$($service.Status)" } else { "$name=not installed" }
}
Add-Line ("AVD agent: {0}" -f ($services -join ', '))

$dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses } | Select-Object -Unique)
Add-Line ("DNS servers: {0}" -f $(if ($dnsServers) { $dnsServers -join ', ' } else { 'none found' }))

$proxyText = (netsh winhttp show proxy) -join ' '
if ($proxyText -match 'Direct access') { $proxy = 'direct (no proxy)' }
elseif ($proxyText -match 'Proxy Server\(s\)\s*:\s*(\S+)') { $proxy = $Matches[1] }
else { $proxy = 'unknown' }
Add-Line "WinHTTP proxy: $proxy"

# Learn: required FQDNs and endpoints for session hosts, Azure Entra join of Azure VMs, and the Azure fabric IPs.
$endpoints = @(
    @('login.microsoftonline.com', 443, 'Entra sign-in'),
    @('rdbroker.wvd.microsoft.com', 443, '*.wvd.microsoft.com'),
    @('rdweb.wvd.microsoft.com', 443, '*.wvd.microsoft.com'),
    @('windows.cloud.microsoft', 443, '*.windows.cloud.microsoft'),
    @('catalogartifact.azureedge.net', 443, 'Marketplace'),
    @('gcs.prod.monitoring.core.windows.net', 443, 'Agent traffic'),
    @('mrsglobalsteus2prod.blob.core.windows.net', 443, 'Agent updates'),
    @('wvdportalstorageblob.blob.core.windows.net', 443, 'Portal support'),
    @('azkms.core.windows.net', 1688, 'Windows activation'),
    @('oneocsp.microsoft.com', 80, 'Certificates'),
    @('www.microsoft.com', 80, 'Certificates'),
    @('ctldl.windowsupdate.com', 80, 'Certificates'),
    @('enterpriseregistration.windows.net', 443, 'Entra join'),
    @('device.login.microsoftonline.com', 443, 'Entra join'),
    @('pas.windows.net', 443, 'Entra join'),
    @('169.254.169.254', 80, 'IMDS, must not be proxied'),
    @('168.63.129.16', 80, 'WireServer, must not be proxied'),
    @('168.63.129.16', 32526, 'WireServer, must not be proxied')
)
Add-Line '-- Required endpoints (result, endpoint, DNS answer, purpose) --'
$failures = 0
foreach ($endpoint in $endpoints) {
    $name, $port, $purpose = $endpoint
    $isIp = $name -match '^\d+\.\d+\.\d+\.\d+$'
    $ip = if ($isIp) { $name } else { Resolve-Ipv4 $name }
    $tcp = if ($ip) { Test-TcpPort $name $port } else { 'no DNS' }
    if ($tcp -ne 'ok') { $failures++ }
    $parts = @($(if ($tcp -eq 'ok') { 'OK  ' } else { 'FAIL' }), "${name}:$port")
    if (-not $isIp -and $ip) { $parts += "-> $ip" }
    if ($tcp -ne 'ok') { $parts += "[$tcp]" }
    $parts += "($purpose)"
    Add-Line ($parts -join ' ')
}
Add-Line ("{0} of {1} endpoints reachable" -f ($endpoints.Count - $failures), $endpoints.Count)

Add-Line '-- TLS inspection (Learn: keep Entra endpoints out of break-and-inspect) --'
foreach ($name in 'login.microsoftonline.com', 'enterpriseregistration.windows.net') {
    $issuer = Get-TlsIssuer $name
    if ($issuer -match 'Microsoft|DigiCert') { $verdict = 'not intercepted' }
    elseif ($issuer -match '^TLS failed|^no TCP') { $verdict = 'no TLS session' }
    else { $verdict = 'LOOKS INTERCEPTED' }
    Add-Line ("{0}: {1} (issuer: {2})" -f $name, $verdict, $issuer)
}

if ($StorageAccountName) {
    Add-Line '-- Azure Files --'
    $fqdn = "$StorageAccountName.file.core.windows.net"
    $ip = Resolve-Ipv4 $fqdn
    $scope = if (-not $ip) { 'no DNS answer' } elseif ($ip -match '^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)') { 'private endpoint' } else { 'PUBLIC address, so the private endpoint DNS record is missing' }
    $smb = if ($ip) { Test-TcpPort $fqdn 445 } else { 'not tested' }
    Add-Line ("{0} -> {1} ({2}), SMB 445: {3}" -f $fqdn, $(if ($ip) { $ip } else { '-' }), $scope, $smb)
}

$tool = Get-ChildItem 'C:\Program Files\Microsoft RDInfra' -Filter 'WVDAgentUrlTool.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Add-Line '-- AVD Agent URL Tool --'
if ($tool) {
    $log = Join-Path $env:TEMP 'WVDAgentUrlTool-output.txt'
    $process = Start-Process -FilePath $tool.FullName -WorkingDirectory $tool.DirectoryName -RedirectStandardOutput $log -NoNewWindow -PassThru
    if (-not $process.WaitForExit(120000)) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue; Add-Line 'Tool did not finish within 2 minutes.' }
    $lines = @(Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_.Trim() })
    $bad = @($lines | Where-Object { $_ -match '(?i)inaccessible|not accessible|fail' })
    if ($bad) { $bad | Select-Object -First 12 | ForEach-Object { Add-Line $_.Trim() } }
    else { $lines | Select-Object -Last 4 | ForEach-Object { Add-Line $_.Trim() } }
}
else { Add-Line 'Not found: the AVD agent is not installed yet, so the endpoint checks above are the evidence.' }

$report -join [Environment]::NewLine
