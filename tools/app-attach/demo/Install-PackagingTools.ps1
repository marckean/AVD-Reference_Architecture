<#
.SYNOPSIS
Installs the MSIX Packaging Tool, its driver and MSIXMGR on a packaging machine from the demo kit.

.DESCRIPTION
Installs the tools that Get-AppAttachDemoKit.ps1 downloaded, using the offline steps Microsoft Learn documents:

- The MSIX Packaging Tool, provisioned from its offline bundle and licence with Add-AppxProvisionedPackage, then registered for the current user.
- The MSIX Packaging Tool driver, a Feature on Demand installed with DISM.
- MSIXMGR, which the kit script has already extracted. This script reports where it is.

Optionally, it imports a test certificate into the Local Machine Trusted People store. That lets you install a package signed with a self-signed certificate on this machine to test it, as Learn describes. Don't use it on session hosts or Cloud PCs.

Run it in an elevated PowerShell session on a clean packaging machine.

.PARAMETER KitDirectory
The kit folder that Get-AppAttachDemoKit.ps1 created.

.PARAMETER TestCertificatePath
Optional. A .cer file to trust on this machine for local testing of self-signed packages.

.EXAMPLE
.\Install-PackagingTools.ps1

Installs the tools from C:\AppAttachDemo.

.EXAMPLE
.\Install-PackagingTools.ps1 -TestCertificatePath C:\AppAttachDemo\Certificate\AppAttachDemo-1A2B3C4D.cer

Installs the tools and trusts the test certificate on this machine only.

.NOTES
Sources:
https://learn.microsoft.com/windows/msix/packaging-tool/disconnected-environment
https://learn.microsoft.com/windows/msix/packaging-tool/tool-overview
https://learn.microsoft.com/windows/msix/package/create-certificate-package-signing

.LINK
https://learn.microsoft.com/windows/msix/packaging-tool/disconnected-environment
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $KitDirectory = 'C:\AppAttachDemo',

    [Parameter()]
    [ValidateScript({
        if ($_ -notmatch '\.cer$') {
            throw 'TestCertificatePath must be a .cer file.'
        }
        return $true
    })]
    [string] $TestCertificatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolDirectory = Join-Path -Path $KitDirectory -ChildPath 'Tools'
if (-not (Test-Path -LiteralPath $toolDirectory -PathType Container)) {
    throw "No Tools folder in '$KitDirectory'. Run Get-AppAttachDemoKit.ps1 first."
}

$results = New-Object -TypeName System.Collections.Generic.List[object]

$bundle = Get-ChildItem -LiteralPath $toolDirectory -Filter 'MSIXPackagingtool*.msixbundle' | Select-Object -First 1
$license = Get-ChildItem -LiteralPath $toolDirectory -Filter 'MSIXPackagingtool*.License.xml' | Select-Object -First 1
if ($null -eq $bundle -or $null -eq $license) {
    throw "The MSIX Packaging Tool bundle or its licence isn't in '$toolDirectory'."
}

if ($PSCmdlet.ShouldProcess($bundle.FullName, 'Provision the MSIX Packaging Tool for all users')) {
    Add-AppxProvisionedPackage -Online -PackagePath $bundle.FullName -LicensePath $license.FullName | Out-Null
    try {
        Add-AppxPackage -Path $bundle.FullName
    }
    catch {
        Write-Warning "The MSIX Packaging Tool is provisioned, but couldn't be registered for this user now. Sign out and back in. $($_.Exception.Message)"
    }
}
$results.Add([pscustomobject]@{ Tool = 'MSIX Packaging Tool'; Path = $bundle.FullName; Result = 'Provisioned' })

$driver = Get-ChildItem -LiteralPath $toolDirectory -Filter 'Msix-PackagingTool-Driver-Package*.cab' | Select-Object -First 1
if ($null -eq $driver) {
    throw "The MSIX Packaging Tool driver isn't in '$toolDirectory'."
}

if ($PSCmdlet.ShouldProcess($driver.FullName, 'Install the MSIX Packaging Tool driver with DISM')) {
    $output = & dism.exe /Online /add-package "/packagepath:$($driver.FullName)" /NoRestart 2>&1
    # 3010 means the driver installed and Windows wants a restart.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
        throw "DISM couldn't install the driver. Exit code $LASTEXITCODE. $($output -join [Environment]::NewLine)"
    }
    $driverResult = if ($LASTEXITCODE -eq 3010) { 'Installed, restart needed' } else { 'Installed' }
    $results.Add([pscustomobject]@{ Tool = 'MSIX Packaging Tool driver'; Path = $driver.FullName; Result = $driverResult })
}

$msixMgr = Get-ChildItem -LiteralPath $toolDirectory -Filter 'msixmgr.exe' -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -eq 'x64' } |
    Select-Object -First 1
$msixMgrResult = if ($null -ne $msixMgr) { 'Ready' } else { 'Not found. Run Get-AppAttachDemoKit.ps1 -Item MsixMgr' }
$msixMgrPath = if ($null -ne $msixMgr) { $msixMgr.FullName } else { '' }
$results.Add([pscustomobject]@{ Tool = 'MSIXMGR'; Path = $msixMgrPath; Result = $msixMgrResult })

if (-not [string]::IsNullOrWhiteSpace($TestCertificatePath)) {
    if ($PSCmdlet.ShouldProcess($TestCertificatePath, 'Trust the test certificate on this machine (Local Machine Trusted People)')) {
        Import-Certificate -FilePath $TestCertificatePath -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    }
    $results.Add([pscustomobject]@{ Tool = 'Test certificate'; Path = $TestCertificatePath; Result = 'Trusted on this machine only' })
}

$results
