# Generates Android mipmap and iOS AppIcon assets from one source image.
#
# Why not just scale the source: launcher icons must be OPAQUE SQUARES.
# The artwork already has rounded corners with transparent pixels, and both
# platforms apply their own mask on top. Shipping it as-is gives double-rounded
# corners on Android and black corners on iOS (iOS drops the alpha channel).
# So we crop to the artwork, then composite it onto a full-bleed gradient
# sampled from the artwork itself.
#
# NOTE: kept ASCII-only. Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI.
#
# Usage: powershell -File tools/make_app_icon.ps1 -Source path\icon.png

param(
    [Parameter(Mandatory=$true)][string]$Source,
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Source))
"source: {0}x{1} {2}" -f $src.Width, $src.Height, $src.PixelFormat

# ---------------------------------------------------------------- artwork box
# Locate the coloured plate by HUE, not by alpha.
# These source images have the transparency checkerboard drawn in as real grey
# pixels, so an alpha test matches the whole canvas. The plate is green while
# the checkerboard is neutral grey/white, so green-ness separates them cleanly.
$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
$step = 2
for ($y = 0; $y -lt $src.Height; $y += $step) {
    for ($x = 0; $x -lt $src.Width; $x += $step) {
        $p = $src.GetPixel($x, $y)
        if ($p.A -gt 200 -and $p.G -gt ($p.R + 12) -and $p.G -gt ($p.B + 12)) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
if ($maxX -lt 0) { throw "No coloured plate found in $Source" }
$plateW = $maxX - $minX + 1
$plateH = $maxY - $minY + 1
"plate: ({0},{1}) {2}x{3}" -f $minX, $minY, $plateW, $plateH

# Crop INSIDE the rounded corners so no checkerboard survives.
# A squircle of radius r needs an inset of about 0.3r; with r near 0.18w that
# is roughly 0.055w. Take 8% for margin.
$insetX = [int]($plateW * 0.08)
$insetY = [int]($plateH * 0.08)
$minX += $insetX; $minY += $insetY
$boxW = $plateW - 2 * $insetX
$boxH = $plateH - 2 * $insetY

# Use the largest centred square of that region so nothing is stretched.
$side = [Math]::Min($boxW, $boxH)
$minX += [int](($boxW - $side) / 2)
$minY += [int](($boxH - $side) / 2)
$boxW = $side
$boxH = $side
"crop: ({0},{1}) {2}x{3}" -f $minX, $minY, $boxW, $boxH

# ---------------------------------------------------------------- background
# Sample the artwork's own gradient so the filled corners match seamlessly.
$cx = [int]($minX + $boxW / 2)
$topColor    = $src.GetPixel($cx, [int]($minY + $boxH * 0.12))
$bottomColor = $src.GetPixel($cx, [int]($minY + $boxH * 0.88))
"gradient: #{0:X2}{1:X2}{2:X2} -> #{3:X2}{4:X2}{5:X2}" -f `
    $topColor.R, $topColor.G, $topColor.B, $bottomColor.R, $bottomColor.G, $bottomColor.B

# ---------------------------------------------------------------- master 1024
$master = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($master)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$rect = New-Object System.Drawing.Rectangle(0, 0, 1024, 1024)
$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, $topColor, $bottomColor, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
$g.FillRectangle($brush, $rect)
$brush.Dispose()

# The crop is already pure plate colour, so draw it edge to edge. The gradient
# fill underneath only matters if the crop is not perfectly square.
$srcRect = New-Object System.Drawing.Rectangle($minX, $minY, $boxW, $boxH)
$g.DrawImage($src, $rect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# ---------------------------------------------------------------- write sizes
function Save-Resized([System.Drawing.Bitmap]$from, [int]$size, [string]$path) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }

    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gg = [System.Drawing.Graphics]::FromImage($bmp)
    $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gg.DrawImage($from, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)))
    $gg.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$android = @{
    'mipmap-mdpi'    = 48
    'mipmap-hdpi'    = 72
    'mipmap-xhdpi'   = 96
    'mipmap-xxhdpi'  = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($k in $android.Keys) {
    $p = Join-Path $ProjectRoot "android\app\src\main\res\$k\ic_launcher.png"
    Save-Resized $master $android[$k] $p
    "  android $k -> $($android[$k])px"
}

# iOS names must match Contents.json exactly.
$ios = @{
    'Icon-App-20x20@1x.png'     = 20
    'Icon-App-20x20@2x.png'     = 40
    'Icon-App-20x20@3x.png'     = 60
    'Icon-App-29x29@1x.png'     = 29
    'Icon-App-29x29@2x.png'     = 58
    'Icon-App-29x29@3x.png'     = 87
    'Icon-App-40x40@1x.png'     = 40
    'Icon-App-40x40@2x.png'     = 80
    'Icon-App-40x40@3x.png'     = 120
    'Icon-App-60x60@2x.png'     = 120
    'Icon-App-60x60@3x.png'     = 180
    'Icon-App-76x76@1x.png'     = 76
    'Icon-App-76x76@2x.png'     = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
}
$iosDir = Join-Path $ProjectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($k in $ios.Keys) {
    Save-Resized $master $ios[$k] (Join-Path $iosDir $k)
    "  ios $k -> $($ios[$k])px"
}

# Keep the master for regenerating later.
$masterPath = Join-Path $ProjectRoot 'assets\icon\app_icon.png'
$masterDir = Split-Path $masterPath -Parent
if (-not (Test-Path $masterDir)) { New-Item -ItemType Directory -Force $masterDir | Out-Null }
$master.Save($masterPath, [System.Drawing.Imaging.ImageFormat]::Png)

$master.Dispose()
$src.Dispose()
"done. master saved to assets/icon/app_icon.png"
