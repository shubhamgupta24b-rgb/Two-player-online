# Tiles build/screens/*_<suffix>.png into contact sheets (4 across, 2 down, half size) with labels.
# Usage (from mobile/): powershell -File tool\contact_sheet.ps1 [-Suffix play] [-PerSheet 8]
param([string]$Suffix = 'play', [int]$PerSheet = 8)
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$files = Get-ChildItem "$root\build\screens\*_$Suffix.png" | Sort-Object Name
$w = 206; $h = 457; $cols = 4; $rows = [math]::Ceiling($PerSheet / $cols)
$font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$sheet = 0
for ($i = 0; $i -lt $files.Count; $i += $PerSheet) {
  $bmp = New-Object System.Drawing.Bitmap ($cols * $w), ($rows * ($h + 20))
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Black)
  $g.InterpolationMode = 'HighQualityBicubic'
  for ($k = 0; $k -lt $PerSheet -and $i + $k -lt $files.Count; $k++) {
    $f = $files[$i + $k]
    $img = [System.Drawing.Image]::FromFile($f.FullName)
    $x = ($k % $cols) * $w; $y = [math]::Floor($k / $cols) * ($h + 20)
    $g.DrawImage($img, $x, $y + 20, $w, $h)
    $g.DrawString(($f.BaseName -replace "_$Suffix$", ''), $font, [System.Drawing.Brushes]::Yellow, $x + 4, $y + 1)
    $img.Dispose()
  }
  $out = "$root\build\screens\sheet_${Suffix}_$sheet.png"
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  $out
  $sheet++
}
