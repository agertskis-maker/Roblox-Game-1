# Downtown look development: side-by-side comparison sheets of the three directions from the
# same fixture frames (Blender renders, not Roblox). Needs the per-direction renders first.
#   .\assets\downtown\kit\compare.ps1 [-Out <blender render folder>]
# Writes compare-<frame>.png (A | B | C, 640 wide each) and chase-ABC.mp4 (three chase passes
# side by side, 480 wide each).
param([string]$Out = "C:\Users\agert\Documents\Car-Hop-Art\review\hud-downtown\downtown\blender")
$ffmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe | Select-Object -First 1).FullName
foreach ($f in "chase-s030", "chase-s115", "chase-s200", "chase-s262", "ped-s60", "ped-s250") {
    $a = Join-Path $Out "A-$f.png"; $b = Join-Path $Out "B-$f.png"; $c = Join-Path $Out "C-$f.png"
    if ((Test-Path $a) -and (Test-Path $b) -and (Test-Path $c)) {
        & $ffmpeg -y -loglevel error -i $a -i $b -i $c -filter_complex "[0]scale=640:-1[a];[1]scale=640:-1[b];[2]scale=640:-1[c];[a][b][c]hstack=inputs=3" -frames:v 1 -update 1 (Join-Path $Out "compare-$f.png")
    }
}
$va = Join-Path $Out "chase-A.mp4"; $vb = Join-Path $Out "chase-B.mp4"; $vc = Join-Path $Out "chase-C.mp4"
if ((Test-Path $va) -and (Test-Path $vb) -and (Test-Path $vc)) {
    & $ffmpeg -y -loglevel error -i $va -i $vb -i $vc -filter_complex "[0]scale=480:-2[a];[1]scale=480:-2[b];[2]scale=480:-2[c];[a][b][c]hstack=inputs=3" -c:v libx264 -pix_fmt yuv420p -crf 20 (Join-Path $Out "chase-ABC.mp4")
}
