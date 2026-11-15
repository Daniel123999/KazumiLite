Add-Type -AssemblyName System.Drawing

$outDir = "C:\Users\25744\Documents\KazumiLite\ios\icons"
New-Item -ItemType Directory -Force $outDir | Out-Null

function New-Icon([int]$size, [string]$name) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(255, 245, 84, 125)), ([System.Drawing.Color]::FromArgb(255, 196, 43, 108)), 45.0
    $g.FillRectangle($brush, $rect)

    # subtle top highlight
    $hl = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28, 255, 255, 255))
    $g.FillEllipse($hl, -$size * 0.35, -$size * 0.55, $size * 1.7, $size * 1.1)

    # white play mark + K
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $fontSize = [float]($size * 0.52)
    $font = New-Object System.Drawing.Font "Segoe UI", $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("K", $font, $white, (New-Object System.Drawing.RectangleF 0, ($size * 0.02), $size, $size), $fmt)

    # play triangle bottom-right
    $tri = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cx = $size * 0.70; $cy = $size * 0.70; $r = $size * 0.15
    $tri.AddPolygon(@(
        (New-Object System.Drawing.PointF ($cx - $r * 0.55), ($cy - $r)),
        (New-Object System.Drawing.PointF ($cx - $r * 0.55), ($cy + $r)),
        (New-Object System.Drawing.PointF ($cx + $r * 0.8), $cy)
    ))
    $g.FillPath($white, $tri)

    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

foreach ($base in @(29, 40, 60, 76)) {
    New-Icon $base "Icon$($base)x$($base).png"
    New-Icon ($base * 2) "Icon$($base)x$($base)@2x.png"
    New-Icon ($base * 3) "Icon$($base)x$($base)@3x.png"
}
New-Icon 1024 "Icon1024.png"
Write-Output "icons generated"
