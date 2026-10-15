# Run from PowerShell: ./scripts/check.ps1
# Works in Windows PowerShell 5.1 and PowerShell 7+.
# Checks first-party source; never rewrites files or checks third-party source.
#
# Exit codes:
#   0  every check ran and passed
#   1  a check failed, or a tool is missing
#   2  nothing failed, but a tool was blocked by the OS (for example Windows
#      Application Control) so its check did NOT run. This is not a pass.
#      In CI (GITHUB_ACTIONS or CI set) a blocked tool is a failure (1).
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$checkRepo = Split-Path $PSScriptRoot -Parent
$checkFailures = [System.Collections.Generic.List[string]]::new()
$checkBlocked = [System.Collections.Generic.List[string]]::new()
$checkInCi = ($env:GITHUB_ACTIONS -eq 'true') -or ($env:CI -eq 'true')
$checkToolNames = @{ selene = 'Selene'; stylua = 'StyLua'; rojo = 'Rojo' }

# Runs a native tool and returns its exit code and combined output. 2>&1 on a native
# command wraps stderr in ErrorRecords in Windows PowerShell 5.1, which Stop would turn
# into a terminating error, so Continue is set around the call.
function Invoke-CheckTool {
    param([string]$Tool, [string[]]$ToolArguments)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $code = -1
    try {
        $lines = @(& $Tool @ToolArguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } catch {
        $lines = @($_.Exception.Message)
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $text = ($lines -join [Environment]::NewLine)
    [pscustomobject]@{
        ExitCode = $code
        Output   = $text
        Blocked  = ($text -match 'Application Control|error 4551|blocked by group policy|blocked this file')
    }
}

# Returns 'ok', 'missing' or 'blocked'. Rokit shims start fine and then fail when the
# real binary is blocked, so a --version probe is what reveals a blocked tool.
function Get-CheckToolState {
    param([string]$Tool)

    if (!(Get-Command $Tool -ErrorAction SilentlyContinue)) { return 'missing' }
    $probe = Invoke-CheckTool -Tool $Tool -ToolArguments @('--version')
    if ($probe.Blocked) { return 'blocked' }
    if ($probe.ExitCode -ne 0) {
        Write-Host $probe.Output
        return 'missing'
    }
    return 'ok'
}

Push-Location -LiteralPath $checkRepo
try {
    $checkState = @{}
    foreach ($checkTool in @('selene', 'stylua', 'rojo')) {
        $checkState[$checkTool] = Get-CheckToolState $checkTool
        switch ($checkState[$checkTool]) {
            'missing' {
                $checkFailures.Add("Missing or unusable $($checkToolNames[$checkTool]). Run rokit install in the repository first.")
            }
            'blocked' {
                Write-Warning "$($checkToolNames[$checkTool]) blocked locally, checked in CI"
                if ($checkInCi) {
                    $checkFailures.Add("$($checkToolNames[$checkTool]) is blocked in CI.")
                } else {
                    $checkBlocked.Add($checkToolNames[$checkTool])
                }
            }
        }
    }

    # Explicit enumeration also handles an empty project without linting vendor code.
    # Relative paths are built by hand: [System.IO.Path]::GetRelativePath does not exist
    # in Windows PowerShell 5.1 (.NET Framework).
    $checkRoot = (Resolve-Path -LiteralPath $checkRepo).ProviderPath.TrimEnd('\', '/')
    $checkVendor = [System.IO.Path]::Combine($checkRoot, 'src', 'server', 'vendor') + [System.IO.Path]::DirectorySeparatorChar
    $checkFiles = @(Get-ChildItem -LiteralPath (Join-Path $checkRoot 'src') -Recurse -File |
        Where-Object {
            $_.Extension -in @('.luau', '.lua') -and
            -not $_.FullName.StartsWith($checkVendor, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object { $_.FullName.Substring($checkRoot.Length + 1) })

    foreach ($checkFile in $checkFiles) {
        $checkFirstLine = Get-Content -LiteralPath $checkFile -TotalCount 1
        if ($checkFirstLine -cne '--!strict') {
            $checkFailures.Add("Missing --!strict first line: $checkFile")
        }
    }

    if ($checkFiles.Count -gt 0) {
        if ($checkState['selene'] -eq 'ok') {
            $checkResult = Invoke-CheckTool -Tool 'selene' -ToolArguments $checkFiles
            if ($checkResult.Output) { Write-Host $checkResult.Output }
            if ($checkResult.ExitCode -ne 0) { $checkFailures.Add('Selene failed.') }
        }

        if ($checkState['stylua'] -eq 'ok') {
            $checkResult = Invoke-CheckTool -Tool 'stylua' -ToolArguments (@('--check') + $checkFiles)
            if ($checkResult.Output) { Write-Host $checkResult.Output }
            if ($checkResult.ExitCode -ne 0) { $checkFailures.Add('StyLua failed.') }
        }
    } else {
        Write-Host 'No first-party Luau files yet; source lint/format checks have no input.'
    }

    if ($checkState['rojo'] -eq 'ok') {
        $checkOutputDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'roblox-game-1-checks'
        New-Item -ItemType Directory -Path $checkOutputDirectory -Force | Out-Null
        $checkResult = Invoke-CheckTool -Tool 'rojo' -ToolArguments @('build', 'default.project.json', '-o', (Join-Path $checkOutputDirectory 'game.rbxlx'))
        if ($checkResult.Output) { Write-Host $checkResult.Output }
        if ($checkResult.ExitCode -ne 0) { $checkFailures.Add('Rojo build failed. Run wally install if packages are missing.') }
    }

    if ($checkFailures.Count -gt 0) {
        Write-Host ''
        Write-Host 'CHECKS FAILED:' -ForegroundColor Red
        foreach ($checkFailure in $checkFailures) { Write-Host "  - $checkFailure" -ForegroundColor Red }
        exit 1
    }

    if ($checkBlocked.Count -gt 0) {
        Write-Host ''
        Write-Host 'INCOMPLETE, NOT A PASS: nothing failed, but these checks did not run locally:' -ForegroundColor Yellow
        foreach ($checkTool in $checkBlocked) { Write-Host "  - $checkTool blocked locally, checked in CI" -ForegroundColor Yellow }
        Write-Host 'Everything that could run passed. Confirm the blocked checks in the GitHub run.' -ForegroundColor Yellow
        exit 2
    }

    Write-Host 'All repository checks passed. This does not verify Studio runtime behavior.'
} finally {
    Pop-Location
}
