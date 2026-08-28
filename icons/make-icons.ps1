# Regenerates the LYNS app icons: white serif "L" on navy.
Add-Type -AssemblyName System.Drawing
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# use Fraunces if it's installed, else Georgia (the app's own serif fallback)
$fam = "Georgia"
try { $t = New-Object System.Drawing.FontFamily("Fraunces"); $fam = "Fraunces"; $t.Dispose() } catch {}
Write-Host "font: $fam"

function New-Icon([string]$path, [int]$size, [double]$padFrac, [bool]$rounded) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $navy = [System.Drawing.Color]::FromArgb(255, 18, 35, 59)   # #12233B
  $navyBrush = New-Object System.Drawing.SolidBrush($navy)

  if ($rounded) {
    $g.Clear([System.Drawing.Color]::Transparent)
    $r = [float]($size * 0.22)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc(0, 0, $r*2, $r*2, 180, 90)
    $gp.AddArc($size-$r*2, 0, $r*2, $r*2, 270, 90)
    $gp.AddArc($size-$r*2, $size-$r*2, $r*2, $r*2, 0, 90)
    $gp.AddArc(0, $size-$r*2, $r*2, $r*2, 90, 90)
    $gp.CloseFigure()
    $g.FillPath($navyBrush, $gp)
  } else {
    $g.Clear($navy)
  }

  $fontSize = [float]($size * (0.54 - $padFrac))
  $font = New-Object System.Drawing.Font($fam, $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment     = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = New-Object System.Drawing.RectangleF(0, [float]($size * -0.02), [float]$size, [float]$size)
  $g.DrawString("L", $font, [System.Drawing.Brushes]::White, $rect, $sf)

  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "wrote $path"
}

New-Icon "$outDir\icon-192.png"          192 0.00 $true
New-Icon "$outDir\icon-512.png"          512 0.00 $true
New-Icon "$outDir\icon-maskable-512.png" 512 0.10 $false
New-Icon "$outDir\apple-touch-icon.png"  180 0.00 $true
New-Icon "$outDir\favicon-32.png"         32 0.00 $true
Write-Host "done"
