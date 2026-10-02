# Builds the Android launcher and web icons from the rendered logo.
# Run after:  flutter test tool/render_logo_test.dart   (from mobile/)
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent

function Resize($src, $dst, $size) {
  $img = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($img, 0, 0, $size, $size)
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}

$icon = Join-Path $root 'build\logo\icon_1024.png'
$fg = Join-Path $root 'build\logo\foreground_1024.png'
$res = Join-Path $root 'android\app\src\main\res'
# Legacy icons (48dp) and adaptive foregrounds (108dp).
foreach ($d in @(@('mdpi', 48, 108), @('hdpi', 72, 162), @('xhdpi', 96, 216), @('xxhdpi', 144, 324), @('xxxhdpi', 192, 432))) {
  Resize $icon "$res\mipmap-$($d[0])\ic_launcher.png" $d[1]
  Resize $fg "$res\mipmap-$($d[0])\ic_launcher_foreground.png" $d[2]
}
$web = Join-Path $root 'web'
Resize $icon "$web\icons\Icon-192.png" 192
Resize $icon "$web\icons\Icon-512.png" 512
Resize $fg "$web\icons\Icon-maskable-192.png" 192
Resize $fg "$web\icons\Icon-maskable-512.png" 512
Resize $icon "$web\favicon.png" 32
'icons written'
