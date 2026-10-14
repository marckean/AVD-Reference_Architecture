<#
.SYNOPSIS
Downloads and verifies three real applications and the tools for an App Attach demo.

.DESCRIPTION
Builds an App Attach demo kit on a packaging machine. It downloads:

- VLC media player and PuTTY, two free applications many organisations already use. Both ship as MSI installers, which the MSIX Packaging Tool converts to MSIX.
- Microsoft XML Notepad, which Microsoft already publishes as a signed MSIX bundle. It needs no conversion and no signing, so it's the fastest way to prove App Attach works. Microsoft Learn suggests it as a test package.
- The MSIX Packaging Tool offline bundle and its licence, the MSIX Packaging Tool driver, and MSIXMGR.

Each file is checked before it's used. Its SHA256 hash is compared with the hash the vendor publishes, where the vendor publishes one, and its signature is read. A file whose hash doesn't match is deleted and the script stops. Nothing is installed.

The script writes kit-manifest.csv, a record of every file, and conversion-input.csv, which New-MsixConversionTemplate.ps1 turns into command line conversion templates for VLC and PuTTY. Running it again for some items updates their rows and keeps the others.

.PARAMETER OutputDirectory
The folder for the kit. Installers go into an Installers subfolder and tools into a Tools subfolder.

.PARAMETER Item
The items to download. Defaults to all of them.

.PARAMETER PublisherName
The package Publisher written to conversion-input.csv. It must exactly match the Subject of the certificate that signs the packages, for example CN=Contoso App Packaging, O=Contoso Ltd, C=AU. If you leave it out, the column stays blank and New-MsixConversionTemplate.ps1 uses its own -PublisherName value.

.PARAMETER Force
Downloads files again, even if they're already in the kit.

.EXAMPLE
.\Get-AppAttachDemoKit.ps1 -PublisherName 'CN=Contoso App Packaging, O=Contoso Ltd, C=AU'

Downloads and checks everything into C:\AppAttachDemo.

.EXAMPLE
.\Get-AppAttachDemoKit.ps1 -Item XmlNotepad, MsixMgr -OutputDirectory D:\Demo

Downloads only the ready-made MSIX test package and MSIXMGR.

.NOTES
Sources:
https://learn.microsoft.com/windows/msix/packaging-tool/disconnected-environment
https://learn.microsoft.com/windows/msix/packaging-tool/tool-overview
https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image
https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file

.LINK
https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory = 'C:\AppAttachDemo',

    [Parameter()]
    [ValidateSet('VLC', 'PuTTY', 'XmlNotepad', 'MsixPackagingTool', 'MsixPackagingToolDriver', 'MsixMgr')]
    [string[]] $Item = @('VLC', 'PuTTY', 'XmlNotepad', 'MsixPackagingTool', 'MsixPackagingToolDriver', 'MsixMgr'),

    [Parameter()]
    [ValidatePattern('^CN=')]
    [string] $PublisherName,

    [Parameter()]
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Learn's offline links for the MSIX Packaging Tool, its licence and its driver.
$msixPackagingToolBundleUri = 'https://download.microsoft.com/download/e/2/e/e2e923b2-7a3a-4730-969d-ab37001fbb5e/MSIXPackagingtoolv1.2024.405.0.msixbundle'
$msixPackagingToolLicenseUri = 'https://download.microsoft.com/download/e/2/e/e2e923b2-7a3a-4730-969d-ab37001fbb5e/MSIXPackagingtoolv1.2024.405.0.License.xml'
$msixPackagingToolDriverUri = 'https://download.microsoft.com/download/6/c/7/6c7d654b-580b-40d4-8502-f8d435ca125a/Msix-PackagingTool-Driver-Package%7E31bf3856ad364e35%7Eamd64%7E%7E.cab'
$msixMgrUri = 'https://aka.ms/msixmgr'

function Get-WebText {
    param(
        [Parameter(Mandatory)]
        [string] $Uri
    )

    $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing
    if ($response.Content -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($response.Content)
    }

    return [string] $response.Content
}

function Find-LatestLinkName {
    param(
        [Parameter(Mandatory)]
        [string] $Html,

        [Parameter(Mandatory)]
        [string] $Pattern
    )

    $names = @(
        [regex]::Matches($Html, 'href="([^"?#]+)"') |
            ForEach-Object { [System.Uri]::UnescapeDataString(($_.Groups[1].Value -split '/')[-1]) } |
            Where-Object { $_ -match $Pattern } |
            Sort-Object -Unique
    )

    if ($names.Count -eq 0) {
        throw "No download matching '$Pattern' was found."
    }

    $versioned = foreach ($name in $names) {
        $match = [regex]::Match($name, $Pattern)
        $parsed = $null
        if ($match.Groups.Count -gt 1 -and [version]::TryParse($match.Groups[1].Value, [ref] $parsed)) {
            [pscustomobject]@{ Name = $name; Version = $parsed }
        }
        else {
            [pscustomobject]@{ Name = $name; Version = [version] '0.0' }
        }
    }

    return ($versioned | Sort-Object -Property Version -Descending | Select-Object -First 1).Name
}

function Find-PublishedHash {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $HashText,

        [Parameter(Mandatory)]
        [string] $FileName
    )

    foreach ($line in ($HashText -split "`r?`n")) {
        $match = [regex]::Match($line.Trim(), '^([0-9a-fA-F]{64})\s+\*?(\S+)$')
        if ($match.Success -and (($match.Groups[2].Value -split '/')[-1] -eq $FileName)) {
            return $match.Groups[1].Value.ToUpperInvariant()
        }
    }

    return ''
}

function ConvertTo-MsixVersion {
    param(
        [Parameter(Mandatory)]
        [string] $Version
    )

    $parts = @([regex]::Matches($Version, '\d+') | ForEach-Object { [int] $_.Value } | Select-Object -First 4)
    if ($parts.Count -eq 0) {
        throw "'$Version' doesn't contain a version number."
    }

    while ($parts.Count -lt 4) {
        $parts += 0
    }

    return ($parts -join '.')
}

function Get-MsixSigner {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    # An MSIX package or bundle carries its signature in AppxSignature.p7x: the characters PKCX, then a PKCS #7 blob.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $archive.GetEntry('AppxSignature.p7x')
        if ($null -eq $entry) {
            return [pscustomobject]@{ Status = 'NotSigned'; Signer = '' }
        }

        $stream = $entry.Open()
        try {
            $buffer = New-Object -TypeName System.IO.MemoryStream
            $stream.CopyTo($buffer)
            $bytes = $buffer.ToArray()
        }
        finally {
            $stream.Dispose()
        }

        $cms = New-Object -TypeName System.Security.Cryptography.Pkcs.SignedCms
        $cms.Decode([byte[]] $bytes[4..($bytes.Length - 1)])
        $cms.CheckSignature($true)
        $signerInfo = $cms.SignerInfos[0]
        $certificate = $signerInfo.Certificate
        $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        if ($chain.Build($certificate)) {
            $status = 'Valid'
        }
        else {
            # An expired signing certificate is fine when the signature carries a timestamp from while it was valid,
            # which is how Windows treats it. Check the chain as at the signing time.
            $onlyTimeProblems = @($chain.ChainStatus | Where-Object { $_.Status -ne [System.Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NotTimeValid }).Count -eq 0
            $timestamp = @($signerInfo.UnsignedAttributes | Where-Object { $_.Oid.Value -eq '1.3.6.1.4.1.311.3.3.1' }) | Select-Object -First 1
            $status = if ($onlyTimeProblems) { 'Expired' } else { 'NotTrusted' }
            if ($onlyTimeProblems -and $null -ne $timestamp) {
                $signingTime = $certificate.NotBefore.AddDays(1)
                $tokenType = 'System.Security.Cryptography.Pkcs.Rfc3161TimestampToken' -as [type]
                if ($null -ne $tokenType) {
                    $token = $null
                    $bytesRead = 0
                    if ($tokenType::TryDecode($timestamp.Values[0].RawData, [ref] $token, [ref] $bytesRead)) {
                        $signingTime = $token.TokenInfo.Timestamp.UtcDateTime
                    }
                }

                $timeChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
                $timeChain.ChainPolicy.VerificationTime = $signingTime
                if ($timeChain.Build($certificate)) {
                    $status = 'ValidTimestamped'
                }
            }
        }

        return [pscustomobject]@{ Status = $status; Signer = $certificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false) }
    }
    finally {
        $archive.Dispose()
    }
}

function Get-KitFileCheck {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [AllowEmptyString()]
        [string] $PublishedSha256 = ''
    )

    $sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    $hashCheck = if ([string]::IsNullOrWhiteSpace($PublishedSha256)) {
        'NotPublished'
    }
    elseif ($sha256 -eq $PublishedSha256.ToUpperInvariant()) {
        'Match'
    }
    else {
        'Mismatch'
    }

    if ($Path -match '\.(msix|msixbundle|appx|appxbundle)$') {
        $signature = Get-MsixSigner -Path $Path
        $signatureStatus = $signature.Status
        $signer = $signature.Signer
    }
    elseif ($Path -match '\.(msi|exe|cab|dll)$') {
        $authenticode = Get-AuthenticodeSignature -FilePath $Path
        $signatureStatus = [string] $authenticode.Status
        $signer = if ($null -ne $authenticode.SignerCertificate) {
            $authenticode.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        }
        else {
            ''
        }
    }
    else {
        $signatureStatus = 'NotApplicable'
        $signer = ''
    }

    return [pscustomobject]@{
        Sha256 = $sha256
        HashCheck = $hashCheck
        SignatureStatus = $signatureStatus
        Signer = $signer
    }
}

$installerDirectory = Join-Path -Path $OutputDirectory -ChildPath 'Installers'
$toolDirectory = Join-Path -Path $OutputDirectory -ChildPath 'Tools'
foreach ($folder in @($OutputDirectory, $installerDirectory, $toolDirectory)) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($folder, 'Create folder')) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }
}

# Work out what to download first, so -WhatIf shows the real file names and versions.
$plan = foreach ($name in $Item) {
    switch ($name) {
        'VLC' {
            $index = 'https://download.videolan.org/pub/videolan/vlc/last/win64/'
            $fileName = Find-LatestLinkName -Html (Get-WebText -Uri $index) -Pattern '^vlc-(\d+\.\d+\.\d+)-win64\.msi$'
            $version = [regex]::Match($fileName, '\d+\.\d+\.\d+').Value
            $hashText = Get-WebText -Uri "$index$fileName.sha256"
            [pscustomobject]@{
                Item = 'VLC'; Uri = "$index$fileName"; FileName = $fileName; Folder = $installerDirectory; Version = $version
                PublishedSha256 = Find-PublishedHash -HashText $hashText -FileName $fileName
                Conversion = [pscustomobject]@{ ApplicationName = 'VLC media player'; InstallLocation = 'C:\Program Files\VideoLAN\VLC'; PackageName = 'VideoLAN.VLC'; PackageDisplayName = 'VLC media player'; PublisherDisplayName = 'VideoLAN' }
            }
        }
        'PuTTY' {
            $index = 'https://the.earth.li/~sgtatham/putty/latest/w64/'
            $fileName = Find-LatestLinkName -Html (Get-WebText -Uri $index) -Pattern '^putty-64bit-(\d+\.\d+)-installer\.msi$'
            $version = [regex]::Match($fileName, '\d+\.\d+').Value
            $hashText = Get-WebText -Uri 'https://the.earth.li/~sgtatham/putty/latest/sha256sums'
            [pscustomobject]@{
                Item = 'PuTTY'; Uri = "$index$fileName"; FileName = $fileName; Folder = $installerDirectory; Version = $version
                PublishedSha256 = Find-PublishedHash -HashText $hashText -FileName $fileName
                Conversion = [pscustomobject]@{ ApplicationName = 'PuTTY'; InstallLocation = 'C:\Program Files\PuTTY'; PackageName = 'SimonTatham.PuTTY'; PackageDisplayName = 'PuTTY'; PublisherDisplayName = 'Simon Tatham' }
            }
        }
        'XmlNotepad' {
            $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/XmlNotepad/releases/latest' -UseBasicParsing
            $asset = @($release.assets | Where-Object { $_.name -like '*.msixbundle' }) | Select-Object -First 1
            if ($null -eq $asset) {
                throw 'The latest XML Notepad release has no .msixbundle file.'
            }

            $digest = if (($asset.PSObject.Properties.Name -contains 'digest') -and ([string] $asset.digest -match '^sha256:([0-9a-fA-F]{64})$')) { $Matches[1].ToUpperInvariant() } else { '' }
            [pscustomobject]@{
                Item = 'XmlNotepad'; Uri = $asset.browser_download_url; FileName = $asset.name; Folder = $installerDirectory; Version = [string] $release.tag_name
                PublishedSha256 = $digest; Conversion = $null
            }
        }
        'MsixPackagingTool' {
            [pscustomobject]@{
                Item = 'MsixPackagingTool'; Uri = $msixPackagingToolBundleUri; FileName = ($msixPackagingToolBundleUri -split '/')[-1]; Folder = $toolDirectory; Version = '1.2024.405.0'
                PublishedSha256 = ''; Conversion = $null
            }
            [pscustomobject]@{
                Item = 'MsixPackagingToolLicense'; Uri = $msixPackagingToolLicenseUri; FileName = ($msixPackagingToolLicenseUri -split '/')[-1]; Folder = $toolDirectory; Version = '1.2024.405.0'
                PublishedSha256 = ''; Conversion = $null
            }
        }
        'MsixPackagingToolDriver' {
            [pscustomobject]@{
                Item = 'MsixPackagingToolDriver'; Uri = $msixPackagingToolDriverUri; FileName = 'Msix-PackagingTool-Driver-Package~31bf3856ad364e35~amd64~~.cab'; Folder = $toolDirectory; Version = 'Windows 11'
                PublishedSha256 = ''; Conversion = $null
            }
        }
        'MsixMgr' {
            [pscustomobject]@{
                Item = 'MsixMgr'; Uri = $msixMgrUri; FileName = 'msixmgr.zip'; Folder = $toolDirectory; Version = 'Latest'
                PublishedSha256 = ''; Conversion = $null
            }
        }
    }
}

$manifest = New-Object -TypeName System.Collections.Generic.List[object]
$conversionRows = New-Object -TypeName System.Collections.Generic.List[object]

foreach ($entry in $plan) {
    $path = Join-Path -Path $entry.Folder -ChildPath $entry.FileName

    if ((Test-Path -LiteralPath $path) -and -not $Force.IsPresent) {
        Write-Verbose "Already in the kit: $path"
    }
    elseif ($PSCmdlet.ShouldProcess($path, "Download $($entry.Uri)")) {
        Invoke-WebRequest -Uri $entry.Uri -OutFile $path -UseBasicParsing
    }

    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    $check = Get-KitFileCheck -Path $path -PublishedSha256 $entry.PublishedSha256
    if ($check.HashCheck -eq 'Mismatch') {
        Remove-Item -LiteralPath $path -Force
        throw "SHA256 for $($entry.FileName) doesn't match the vendor's published hash. The file was deleted. Expected $($entry.PublishedSha256), got $($check.Sha256)."
    }

    $checkedPath = $path
    if ($entry.Item -eq 'MsixMgr') {
        $msixMgrFolder = Join-Path -Path $toolDirectory -ChildPath 'msixmgr'
        if ($PSCmdlet.ShouldProcess($msixMgrFolder, 'Extract MSIXMGR')) {
            Expand-Archive -LiteralPath $path -DestinationPath $msixMgrFolder -Force
        }

        $exe = Get-ChildItem -LiteralPath $msixMgrFolder -Filter 'msixmgr.exe' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq 'x64' } |
            Select-Object -First 1
        if ($null -ne $exe) {
            $checkedPath = $exe.FullName
            $exeCheck = Get-KitFileCheck -Path $exe.FullName
            $check.SignatureStatus = $exeCheck.SignatureStatus
            $check.Signer = $exeCheck.Signer
        }
    }

    $manifest.Add([pscustomobject]@{
        Item = $entry.Item
        Version = $entry.Version
        Path = $checkedPath
        Source = $entry.Uri
        Sha256 = $check.Sha256
        PublishedSha256 = $entry.PublishedSha256
        HashCheck = $check.HashCheck
        SignatureStatus = $check.SignatureStatus
        Signer = $check.Signer
    })

    if ($null -ne $entry.Conversion) {
        $conversionRows.Add([pscustomobject]@{
            ApplicationName = $entry.Conversion.ApplicationName
            InstallerPath = $path
            InstallerArguments = ''
            InstallLocation = $entry.Conversion.InstallLocation
            PackageName = $entry.Conversion.PackageName
            PackageDisplayName = $entry.Conversion.PackageDisplayName
            PublisherName = $PublisherName
            PublisherDisplayName = $entry.Conversion.PublisherDisplayName
            Version = ConvertTo-MsixVersion -Version $entry.Version
        })
    }
}

function Merge-KitRow {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [object[]] $Row,

        [Parameter(Mandatory)]
        [string] $Key
    )

    # Keep rows from earlier runs for anything this run didn't touch.
    if (-not (Test-Path -LiteralPath $Path)) {
        return $Row
    }

    $newKeys = @($Row | ForEach-Object { [string] $_.$Key })
    $kept = @(Import-Csv -LiteralPath $Path | Where-Object { $_.PSObject.Properties[$Key] -and $newKeys -notcontains [string] $_.PSObject.Properties[$Key].Value })
    return @($kept) + @($Row)
}

# Read and merge first: Export-Csv opens its file before an upstream command runs.
if ($manifest.Count -gt 0) {
    $manifestPath = Join-Path -Path $OutputDirectory -ChildPath 'kit-manifest.csv'
    if ($PSCmdlet.ShouldProcess($manifestPath, 'Write the kit manifest')) {
        $manifestRows = Merge-KitRow -Path $manifestPath -Row $manifest.ToArray() -Key 'Item'
        $manifestRows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
    }
}

if ($conversionRows.Count -gt 0) {
    $conversionPath = Join-Path -Path $OutputDirectory -ChildPath 'conversion-input.csv'
    if ($PSCmdlet.ShouldProcess($conversionPath, 'Write the conversion input for New-MsixConversionTemplate.ps1')) {
        $mergedConversionRows = Merge-KitRow -Path $conversionPath -Row $conversionRows.ToArray() -Key 'PackageName'
        $mergedConversionRows | Export-Csv -LiteralPath $conversionPath -NoTypeInformation -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($PublisherName)) {
        Write-Warning 'No -PublisherName given, so the Publisher in conversion-input.csv is blank. Pass the certificate Subject to New-MsixConversionTemplate.ps1 with -PublisherName.'
    }
}

$manifest
