# Downtown look development: lay out and render one direction end to end (headless Blender,
# no add-ons, no MCP). Run from PowerShell:
#   .\assets\downtown\kit\run_direction.ps1 -Dir A [-Kit <folder>] [-Out <folder>] [-SkipChase]
# Assumes the kit meshes are already built (build_kit.py). Waits while free memory is under
# 4.5 GB and logs each reading to <Kit>\memory-log.txt. One Blender process at a time.
param(
    [Parameter(Mandatory = $true)][ValidateSet("A", "B", "C")][string]$Dir,
    [string]$Kit = "C:\Users\agert\Documents\Car-Hop-Art\downtown-kit",
    [string]$Out = "C:\Users\agert\Documents\Car-Hop-Art\review\hud-downtown\downtown\blender",
    [int]$Samples = 24,
    [int]$ChaseFrames = 96,
    [switch]$SkipChase
)
$ErrorActionPreference = "Stop"
$env:PYTHONDONTWRITEBYTECODE = "1"  # keep __pycache__ out of the repository folder
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$python = "C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe"

function Wait-Memory([string]$what) {
    while ($true) {
        $gb = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
        "$(Get-Date -Format s) free=$([math]::Round($gb, 2))GB before=$what" | Out-File -Append -Encoding utf8 (Join-Path $Kit "memory-log.txt")
        if ($gb -ge 4.5) { return }
        Start-Sleep -Seconds 60
    }
}

& $python (Join-Path $here "layout.py") --kit $Kit --dir $Dir
Wait-Memory "render-$Dir-stills"
& $blender --background --factory-startup --python (Join-Path $here "render.py") -- --kit $Kit --dir $Dir --out $Out --mode stills --samples $Samples
if (-not $SkipChase) {
    Wait-Memory "render-$Dir-chase"
    & $blender --background --factory-startup --python (Join-Path $here "render.py") -- --kit $Kit --dir $Dir --out $Out --mode chase --chase-frames $ChaseFrames
    $ffmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe | Select-Object -First 1).FullName
    & $ffmpeg -y -loglevel error -framerate 24 -i (Join-Path $Out "chase-$Dir\frame_%04d.png") -c:v libx264 -pix_fmt yuv420p -crf 18 (Join-Path $Out "chase-$Dir.mp4")
}
