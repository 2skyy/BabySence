# SVG -> PNG renderer built on System.Drawing.
#
# Handles only the subset this project's SVGs use: rect (with rx), circle,
# path (M/L/z), and text. Styles are already inline attributes, so no CSS.
#
# NOTE: kept ASCII-only. Windows PowerShell 5.1 reads BOM-less .ps1 files as
# ANSI, which corrupts non-ASCII source and breaks parsing.
#
# Usage: powershell -File svg2png.ps1 -In in.svg -Out out.png [-Scale 2.5]

param(
    [Parameter(Mandatory=$true)][string]$In,
    [Parameter(Mandatory=$true)][string]$Out,
    [double]$Scale = 2.5
)

Add-Type -AssemblyName System.Drawing

$svg = Get-Content -Path $In -Raw -Encoding UTF8

if ($svg -match 'viewBox="0 0 ([\d.]+) ([\d.]+)"') {
    $vbW = [double]$Matches[1]
    $vbH = [double]$Matches[2]
} else {
    throw "viewBox not found in $In"
}

# first family listed in the root font-family attribute
$fontName = 'Segoe UI'
if ($svg -match 'font-family="([^"]+)"') {
    $fontName = ($Matches[1] -split ',')[0].Trim()
}
$installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }
if ($installed -notcontains $fontName) {
    foreach ($cand in @('Malgun Gothic', 'Segoe UI', 'Arial')) {
        if ($installed -contains $cand) { $fontName = $cand; break }
    }
}

$canvasW = [int][Math]::Ceiling($vbW * $Scale)
$canvasH = [int][Math]::Ceiling($vbH * $Scale)

$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
$bmp.SetResolution(300, 300)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::White)

function Get-Attr([string]$attrs, [string]$name) {
    # Require a boundary before the name, otherwise 'width' matches inside
    # 'stroke-width' and 'y' matches inside 'stroke-dasharray'.
    $pat = '(?:^|\s)' + [regex]::Escape($name) + '="([^"]*)"'
    if ($attrs -match $pat) { return $Matches[1] }
    return $null
}
function To-Color([string]$v) {
    if ([string]::IsNullOrEmpty($v) -or $v -eq 'none') { return $null }
    return [System.Drawing.ColorTranslator]::FromHtml($v)
}
function ToPx([string]$v, [double]$def = 0) {
    if ([string]::IsNullOrEmpty($v)) { return $def * $Scale }
    return [double]$v * $Scale
}
function Decode([string]$t) {
    $t = $t -replace '&lt;', '<'
    $t = $t -replace '&gt;', '>'
    $t = $t -replace '&quot;', '"'
    $t = $t -replace '&apos;', "'"
    $t = $t -replace '&amp;', '&'
    return $t
}
function RoundedPath([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($r -le 0) {
        $p.AddRectangle((New-Object System.Drawing.RectangleF($x, $y, $w, $h)))
        return $p
    }
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
    $p.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
    $p.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

$fmt = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
$fontFamily = New-Object System.Drawing.FontFamily($fontName)

$rx = [regex]'(?s)<(rect|circle|path|text)\s([^>]*?)(?:/>|>(.*?)</\1>)'
$nRect = 0; $nCircle = 0; $nPath = 0; $nText = 0

foreach ($m in $rx.Matches($svg)) {
    $tag   = $m.Groups[1].Value
    $attrs = $m.Groups[2].Value
    $inner = $m.Groups[3].Value

    $fillC   = To-Color (Get-Attr $attrs 'fill')
    $strokeC = To-Color (Get-Attr $attrs 'stroke')
    $sw      = ToPx (Get-Attr $attrs 'stroke-width') 1
    if ($sw -le 0) { $sw = 1 }

    $pen = $null
    if ($null -ne $strokeC) {
        $pen = New-Object System.Drawing.Pen($strokeC, [float]$sw)
        $dash = Get-Attr $attrs 'stroke-dasharray'
        if (-not [string]::IsNullOrEmpty($dash)) {
            $pat = @()
            foreach ($p in ($dash -split '[\s,]+')) {
                if ($p -ne '') { $pat += [float]((([double]$p) * $Scale) / $sw) }
            }
            if ($pat.Count -ge 2) { $pen.DashPattern = $pat }
        }
    }
    $brush = $null
    if ($null -ne $fillC) { $brush = New-Object System.Drawing.SolidBrush($fillC) }

    if ($tag -eq 'rect') {
        $x = ToPx (Get-Attr $attrs 'x')
        $y = ToPx (Get-Attr $attrs 'y')
        $w = ToPx (Get-Attr $attrs 'width')
        $h = ToPx (Get-Attr $attrs 'height')
        $r = ToPx (Get-Attr $attrs 'rx')
        $path = RoundedPath $x $y $w $h $r
        if ($null -ne $brush) { $g.FillPath($brush, $path) }
        if ($null -ne $pen)   { $g.DrawPath($pen, $path) }
        $path.Dispose()
        $nRect++
    }
    elseif ($tag -eq 'circle') {
        $cx = ToPx (Get-Attr $attrs 'cx')
        $cy = ToPx (Get-Attr $attrs 'cy')
        $r  = ToPx (Get-Attr $attrs 'r')
        $rect = New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), (2 * $r), (2 * $r))
        if ($null -ne $brush) { $g.FillEllipse($brush, $rect) }
        if ($null -ne $pen)   { $g.DrawEllipse($pen, $rect) }
        $nCircle++
    }
    elseif ($tag -eq 'path') {
        $d = Get-Attr $attrs 'd'
        if (-not [string]::IsNullOrEmpty($d)) {
            $pts = New-Object System.Collections.ArrayList
            $closed = $false
            foreach ($tok in [regex]::Matches($d, '([MLz])\s*(-?[\d.]+)?\s*(-?[\d.]+)?')) {
                if ($tok.Groups[1].Value -eq 'z') { $closed = $true; continue }
                $px = [double]$tok.Groups[2].Value * $Scale
                $py = [double]$tok.Groups[3].Value * $Scale
                [void]$pts.Add((New-Object System.Drawing.PointF([float]$px, [float]$py)))
            }
            if ($pts.Count -ge 2) {
                $arr = $pts.ToArray([System.Drawing.PointF])
                if ($closed -and $null -ne $brush) { $g.FillPolygon($brush, $arr) }
                if ($null -ne $pen) {
                    if ($closed) { $g.DrawPolygon($pen, $arr) } else { $g.DrawLines($pen, $arr) }
                }
            }
        }
        $nPath++
    }
    elseif ($tag -eq 'text') {
        $txt = Decode $inner
        if ($txt.Trim() -ne '') {
            $fsRaw = Get-Attr $attrs 'font-size'
            $fs = 12.0
            if (-not [string]::IsNullOrEmpty($fsRaw)) { $fs = [double]($fsRaw -replace 'px', '') }
            $fs = $fs * $Scale

            $fw = Get-Attr $attrs 'font-weight'
            $style = [System.Drawing.FontStyle]::Regular
            if (-not [string]::IsNullOrEmpty($fw)) {
                if ([int]$fw -ge 600) { $style = [System.Drawing.FontStyle]::Bold }
            }

            $font = New-Object System.Drawing.Font($fontFamily, [float]$fs, $style, [System.Drawing.GraphicsUnit]::Pixel)
            $ascent = $fontFamily.GetCellAscent($style) / $fontFamily.GetEmHeight($style) * $fs

            $tx = ToPx (Get-Attr $attrs 'x')
            $ty = ToPx (Get-Attr $attrs 'y')
            $anchor = Get-Attr $attrs 'text-anchor'
            $tw = $g.MeasureString($txt, $font, [int]::MaxValue, $fmt).Width
            if ($anchor -eq 'middle')  { $tx = $tx - $tw / 2 }
            elseif ($anchor -eq 'end') { $tx = $tx - $tw }

            $tb = $brush
            $ownBrush = $false
            if ($null -eq $tb) {
                $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
                $ownBrush = $true
            }
            $g.DrawString($txt, $font, $tb, [float]$tx, [float]($ty - $ascent), $fmt)
            if ($ownBrush) { $tb.Dispose() }
            $font.Dispose()
        }
        $nText++
    }

    if ($null -ne $pen)   { $pen.Dispose() }
    if ($null -ne $brush) { $brush.Dispose() }
}

$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$kb = (Get-Item $Out).Length / 1KB
"{0} -> {1}  {2}x{3}px  {4:N0} KB  font={5}" -f (Split-Path $In -Leaf), (Split-Path $Out -Leaf), $canvasW, $canvasH, $kb, $fontName
"   rect={0} circle={1} path={2} text={3}" -f $nRect, $nCircle, $nPath, $nText
