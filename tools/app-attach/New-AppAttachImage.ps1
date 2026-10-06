<#
.SYNOPSIS
Creates App Attach images from MSIX or Appx packages.

.DESCRIPTION
Uses the Microsoft Learn documented MSIXMGR command line to unpack MSIX or Appx packages into App Attach images.

The default image type is CimFS because Microsoft Learn recommends CimFS for Windows 11 session hosts for better mount and unmount performance and lower CPU and memory use. VHDX is available when a single disk file is required.

.PARAMETER PackagePath
One or more .msix, .msixbundle, .appx, or .appxbundle packages.

.PARAMETER OutputDirectory
The folder that receives generated images.

.PARAMETER ImageType
The image type to create. CimFS produces a .cim file and companion files. VHDX produces a single .vhdx file.

.PARAMETER MsixMgrPath
Path to msixmgr.exe. Defaults to msixmgr.exe on PATH.

.PARAMETER Force
Allows overwriting an existing destination file or folder.

.PARAMETER PassThru
Outputs one object per package with the command and expected image path.

.EXAMPLE
.\New-AppAttachImage.ps1 -PackagePath C:\Packages\*.msix -OutputDirectory C:\AppAttachImages -WhatIf

Shows the MSIXMGR operations that would create CimFS images.

.EXAMPLE
.\New-AppAttachImage.ps1 -PackagePath C:\Packages\Contoso.msix -OutputDirectory C:\AppAttachImages -ImageType VHDX -MsixMgrPath C:\Tools\msixmgr.exe -PassThru

Creates a VHDX image for one package and returns the image metadata.

.NOTES
Sources:
https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview
https://learn.microsoft.com/windows/msix/package/msixmgr-tool

.LINK
https://learn.microsoft.com/azure/virtual-desktop/app-attach-create-msix-image
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({
        foreach ($candidate in $_) {
            if ($candidate -notmatch '\.(msix|msixbundle|appx|appxbundle)$') {
                throw "Package '$candidate' must end with .msix, .msixbundle, .appx, or .appxbundle."
            }
        }
        return $true
    })]
    [string[]] $PackagePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory,

    [Parameter()]
    [ValidateSet('CimFS', 'VHDX')]
    [string] $ImageType = 'CimFS',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $MsixMgrPath = 'msixmgr.exe',

    [Parameter()]
    [switch] $Force,

    [Parameter()]
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Create output directory')) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
}

foreach ($package in $PackagePath) {
    $resolvedPackages = @(Resolve-Path -Path $package | ForEach-Object { Get-Item -LiteralPath $_.ProviderPath })
    if ($resolvedPackages.Count -eq 0) {
        throw "Package '$package' was not found."
    }

    foreach ($resolvedPackage in $resolvedPackages) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPackage.Name)
    $fileType = if ($ImageType -eq 'CimFS') { 'cim' } else { 'vhdx' }
    $destination = if ($ImageType -eq 'CimFS') {
        $imageFolder = Join-Path -Path $OutputDirectory -ChildPath $baseName
        if (-not (Test-Path -LiteralPath $imageFolder -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($imageFolder, 'Create image directory')) {
                New-Item -Path $imageFolder -ItemType Directory -Force | Out-Null
            }
        }
        Join-Path -Path $imageFolder -ChildPath "$baseName.cim"
    }
    else {
        Join-Path -Path $OutputDirectory -ChildPath "$baseName.vhdx"
    }

    if ((Test-Path -LiteralPath $destination) -and -not $Force.IsPresent) {
        throw "Destination '$destination' already exists. Use -Force to overwrite."
    }

    $arguments = @(
        '-Unpack'
        '-packagePath'
        $resolvedPackage.FullName
        '-destination'
        $destination
        '-applyACLs'
        '-create'
        '-fileType'
        $fileType
        '-rootDirectory'
        'apps'
    )

    if ($PSCmdlet.ShouldProcess($destination, "Create $ImageType image from $($resolvedPackage.FullName)")) {
        $output = & $MsixMgrPath @arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "MSIXMGR failed for '$($resolvedPackage.FullName)' with exit code $LASTEXITCODE. Output: $($output -join [Environment]::NewLine)"
        }
        Write-Information ($output -join [Environment]::NewLine)
    }

    if ($PassThru.IsPresent) {
        [pscustomobject]@{
            PackagePath = $resolvedPackage.FullName
            ImageType = $ImageType
            ImagePath = $destination
            Command = "$MsixMgrPath $($arguments -join ' ')"
        }
    }
    }
}
