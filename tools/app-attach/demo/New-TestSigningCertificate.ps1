<#
.SYNOPSIS
Creates a self-signed code signing certificate for testing MSIX packages.

.DESCRIPTION
Creates a code signing certificate with the New-SelfSignedCertificate command that Microsoft Learn documents, then exports it twice:

- A .pfx file with the private key, which the MSIX Packaging Tool or SignTool uses to sign packages.
- A .cer file with only the public certificate, which machines import to trust the signature.

The Subject becomes the package Publisher. Every package you sign with this certificate must have exactly this Publisher.

Use it for testing only. For anything users rely on, use a certificate from your organisation's certificate authority or a public one. Learn says to install a self-signed root in the Trusted Root Certification Authorities store on each session host, and not to distribute it with Group Policy or Intune.

.PARAMETER Subject
The certificate Subject, which is also the package Publisher, for example CN=Contoso App Packaging, O=Contoso Ltd, C=AU.

.PARAMETER OutputDirectory
The folder for the .pfx and .cer files.

.PARAMETER PfxPassword
The password that protects the .pfx file. PowerShell prompts for it if you don't supply it.

.PARAMETER FriendlyName
The friendly name shown in the certificate store.

.EXAMPLE
.\New-TestSigningCertificate.ps1 -Subject 'CN=Contoso App Packaging, O=Contoso Ltd, C=AU' -OutputDirectory C:\AppAttachDemo\Certificate

Creates the certificate in the current user's store and exports it. PowerShell prompts for the .pfx password.

.NOTES
Sources:
https://learn.microsoft.com/windows/msix/package/create-certificate-package-signing
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview

.LINK
https://learn.microsoft.com/windows/msix/package/create-certificate-package-signing
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^CN=')]
    [string] $Subject,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory,

    [Parameter(Mandatory)]
    [securestring] $PfxPassword,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $FriendlyName = 'App Attach demo code signing (test only)'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Create output directory')) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
}

if ($PSCmdlet.ShouldProcess($Subject, 'Create a self-signed code signing certificate in Cert:\CurrentUser\My')) {
    # The command and extensions come from Learn: code signing EKU 1.3.6.1.5.5.7.3.3, and an end-entity basic constraint.
    $certificate = New-SelfSignedCertificate -Type Custom -KeyUsage DigitalSignature -CertStoreLocation 'Cert:\CurrentUser\My' -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}') -Subject $Subject -FriendlyName $FriendlyName

    $baseName = 'AppAttachDemo-' + $certificate.Thumbprint.Substring(0, 8)
    $pfxPath = Join-Path -Path $OutputDirectory -ChildPath "$baseName.pfx"
    $cerPath = Join-Path -Path $OutputDirectory -ChildPath "$baseName.cer"

    Export-PfxCertificate -Cert $certificate -FilePath $pfxPath -Password $PfxPassword | Out-Null
    Export-Certificate -Cert $certificate -FilePath $cerPath | Out-Null

    [pscustomobject]@{
        Publisher = $certificate.Subject
        Thumbprint = $certificate.Thumbprint
        NotAfter = $certificate.NotAfter
        PfxPath = $pfxPath
        CerPath = $cerPath
        Note = 'Test only. Set every package Publisher to exactly this Subject.'
    }
}
