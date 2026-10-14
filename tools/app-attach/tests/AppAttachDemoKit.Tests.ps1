Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:DemoRoot = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'demo'
    $script:KitScript = Join-Path -Path $script:DemoRoot -ChildPath 'Get-AppAttachDemoKit.ps1'
    $script:CertificateScript = Join-Path -Path $script:DemoRoot -ChildPath 'New-TestSigningCertificate.ps1'
    $script:InstallScript = Join-Path -Path $script:DemoRoot -ChildPath 'Install-PackagingTools.ps1'

    # Load the kit script's helper functions without running the script.
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:KitScript, [ref] $null, [ref] $null)
    $helpers = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
    foreach ($helper in $helpers) {
        . ([scriptblock]::Create($helper.Extent.Text))
    }

    function Get-TestSecureString {
        $secure = New-Object -TypeName System.Security.SecureString
        foreach ($character in 'Demo-only-1'.ToCharArray()) {
            $secure.AppendChar($character)
        }
        return $secure
    }
}

Describe 'Get-AppAttachDemoKit.ps1 helpers' {
    It 'turns vendor versions into four-part MSIX versions' {
        ConvertTo-MsixVersion -Version '3.0.24' | Should -Be '3.0.24.0'
        ConvertTo-MsixVersion -Version '0.85' | Should -Be '0.85.0.0'
        ConvertTo-MsixVersion -Version 'v2.9.0.22' | Should -Be '2.9.0.22'
    }

    It 'finds the published hash for a file in a checksum list' {
        $hashText = @(
            '1111111111111111111111111111111111111111111111111111111111111111  w32/putty-0.85-installer.msi'
            'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd  w64/putty-64bit-0.85-installer.msi'
        ) -join "`n"

        Find-PublishedHash -HashText $hashText -FileName 'putty-64bit-0.85-installer.msi' | Should -Be ('ABCDEF' * 10 + 'ABCD')
        Find-PublishedHash -HashText $hashText -FileName 'missing.msi' | Should -Be ''
    }

    It 'picks the newest matching download link' {
        $html = '<a href="vlc-3.0.9-win64.msi">a</a><a href="vlc-3.0.24-win64.msi">b</a><a href="vlc-3.0.24-win64.msi.sha256">c</a>'
        Find-LatestLinkName -Html $html -Pattern '^vlc-(\d+\.\d+\.\d+)-win64\.msi$' | Should -Be 'vlc-3.0.24-win64.msi'
    }
}

Describe 'Get-AppAttachDemoKit.ps1 downloads' {
    BeforeEach {
        $script:FixtureRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        New-Item -Path $script:FixtureRoot -ItemType Directory -Force | Out-Null

        Mock Invoke-WebRequest -ParameterFilter { "$Uri" -eq 'https://download.videolan.org/pub/videolan/vlc/last/win64/' } -MockWith {
            [pscustomobject]@{ Content = '<a href="vlc-3.0.24-win64.msi">vlc</a><a href="vlc-3.0.24-win64.msi.sha256">hash</a>' }
        }
        Mock Invoke-WebRequest -ParameterFilter { "$Uri" -like '*.msi' -and $OutFile } -MockWith {
            Set-Content -LiteralPath $OutFile -Value 'fake installer' -NoNewline
        }
        Mock Get-AuthenticodeSignature -MockWith { [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null } }
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:FixtureRoot) {
            Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force
        }
    }

    It 'checks the hash and writes the conversion input' {
        # The SHA256 of the ASCII text 'fake installer', which the download mock writes.
        Mock Invoke-WebRequest -ParameterFilter { "$Uri" -like '*.sha256' } -MockWith {
            [pscustomobject]@{ Content = [System.Text.Encoding]::ASCII.GetBytes("941ef2fd249e8e3535908e3663515a85a291c538016f75be86032da473029b3e  vlc-3.0.24-win64.msi`n") }
        }

        $manifest = & $script:KitScript -OutputDirectory $script:FixtureRoot -Item VLC -PublisherName 'CN=Contoso App Packaging, O=Contoso Ltd, C=AU'

        $manifest.HashCheck | Should -Be 'Match'
        $manifest.Version | Should -Be '3.0.24'
        $row = Import-Csv -LiteralPath (Join-Path -Path $script:FixtureRoot -ChildPath 'conversion-input.csv')
        $row.PackageName | Should -Be 'VideoLAN.VLC'
        $row.Version | Should -Be '3.0.24.0'
        $row.PublisherName | Should -Be 'CN=Contoso App Packaging, O=Contoso Ltd, C=AU'
        $row.InstallerArguments | Should -Be ''
        Test-Path -LiteralPath (Join-Path -Path $script:FixtureRoot -ChildPath 'kit-manifest.csv') | Should -BeTrue
    }

    It 'deletes a download whose hash does not match and stops' {
        Mock Invoke-WebRequest -ParameterFilter { "$Uri" -like '*.sha256' } -MockWith {
            [pscustomobject]@{ Content = [System.Text.Encoding]::ASCII.GetBytes(('0' * 64) + "  vlc-3.0.24-win64.msi`n") }
        }

        { & $script:KitScript -OutputDirectory $script:FixtureRoot -Item VLC } | Should -Throw '*doesn''t match*'
        Test-Path -LiteralPath (Join-Path -Path $script:FixtureRoot -ChildPath 'Installers\vlc-3.0.24-win64.msi') | Should -BeFalse
    }

    It 'leaves the Publisher blank without -PublisherName and keeps other rows' {
        Mock Invoke-WebRequest -ParameterFilter { "$Uri" -like '*.sha256' } -MockWith {
            [pscustomobject]@{ Content = [System.Text.Encoding]::ASCII.GetBytes("941ef2fd249e8e3535908e3663515a85a291c538016f75be86032da473029b3e  vlc-3.0.24-win64.msi`n") }
        }
        $conversionPath = Join-Path -Path $script:FixtureRoot -ChildPath 'conversion-input.csv'
        [pscustomobject]@{ ApplicationName = 'PuTTY'; InstallerPath = 'C:\putty.msi'; InstallerArguments = ''; InstallLocation = ''; PackageName = 'SimonTatham.PuTTY'; PackageDisplayName = 'PuTTY'; PublisherName = 'CN=Earlier'; PublisherDisplayName = 'Simon Tatham'; Version = '0.85.0.0' } |
            Export-Csv -LiteralPath $conversionPath -NoTypeInformation -Encoding utf8

        $null = & $script:KitScript -OutputDirectory $script:FixtureRoot -Item VLC -WarningAction SilentlyContinue

        $rows = @(Import-Csv -LiteralPath $conversionPath)
        $rows.Count | Should -Be 2
        ($rows | Where-Object PackageName -eq 'SimonTatham.PuTTY').PublisherName | Should -Be 'CN=Earlier'
        ($rows | Where-Object PackageName -eq 'VideoLAN.VLC').PublisherName | Should -Be ''
    }
}

Describe 'New-TestSigningCertificate.ps1' {
    It 'requires a Subject that starts with CN=' {
        { & $script:CertificateScript -Subject 'Contoso' -OutputDirectory ([System.IO.Path]::GetTempPath()) -PfxPassword (Get-TestSecureString) } | Should -Throw
    }

    It 'creates nothing with -WhatIf' {
        $folder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
        $before = @(Get-ChildItem -Path 'Cert:\CurrentUser\My').Count

        $result = & $script:CertificateScript -Subject 'CN=Pester Test Only' -OutputDirectory $folder -PfxPassword (Get-TestSecureString) -WhatIf

        $result | Should -BeNullOrEmpty
        Test-Path -LiteralPath $folder | Should -BeFalse
        @(Get-ChildItem -Path 'Cert:\CurrentUser\My').Count | Should -Be $before
    }
}

Describe 'Install-PackagingTools.ps1' {
    It 'requires an elevated session' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:InstallScript, [ref] $tokens, [ref] $errors)
        $errors | Should -BeNullOrEmpty
        $ast.ScriptRequirements.IsElevationRequired | Should -BeTrue
    }
}
