Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:ImageInventoryScript = Join-Path -Path $script:ToolRoot -ChildPath 'Get-ImageApplicationInventory.ps1'
}

Describe 'Get-ImageApplicationInventory.ps1 offline hive guard' {
    It 'checks for elevation before loading the offline SOFTWARE hive' {
        $content = Get-Content -LiteralPath $script:ImageInventoryScript -Raw
        $content | Should -Match 'Offline mode requires an elevated PowerShell session'
        $content | Should -Match 'reg load'
    }

    It 'unloads a loaded hive in a finally block' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ImageInventoryScript, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0

        $tryStatements = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)
        $tryStatements.Count | Should -BeGreaterThan 0
        ($tryStatements | Where-Object { $null -ne $_.Finally -and $_.Finally.Extent.Text -match 'Invoke-RegUnload' }).Count | Should -BeGreaterThan 0
    }
}
