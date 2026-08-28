Add-Type -AssemblyName System.Drawing
$outDir = "C:\Users\nelad\OneDrive\Documents\LYNS\web\icons"

function New-Icon([string]$path, [int]$size, [double]$padFrac) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

  $navy = [System.Drawing.Color]::FromArgb(255, 18, 35, 59)   # #12233B
  $gold = [System.Drawing.Color]::FromArgb(255, 198, 162, 101) # #C6A265
  $g.Clear($navy)

  $navyBrush = New-Object System.Drawing.SolidBrush($navy)
  $whiteBrush = [System.Drawing.Brushes]::White
  $goldPen = New-Object System.Drawing.Pen($gold, [float]($size * 0.02))

  # pin geometry, scaled into the safe area
  $s = $size * (1.0 - $padFrac * 2.0)
  $cx = $size / 2.0
  $cy = $size / 2.0 - $s * 0.06
  $headR = $s * 0.30
  $headCy = $cy - $s * 0.10

  # triangle tail
  $pts = @(
    (New-Object System.Drawing.PointF([float]($cx - $s * 0.21), [float]($cy + $s * 0.06))),
    (New-Object System.Drawing.PointF([float]$cx, [float]($cy + $s * 0.44))),
    (New-Object System.Drawing.PointF([float]($cx + $s * 0.21), [float]($cy + $s * 0.06)))
  )
  $g.FillPolygon($whiteBrush, $pts)
  # head
  $g.FillEllipse($whiteBrush, [float]($cx - $headR), [float]($headCy - $headR), [float]($headR * 2), [float]($headR * 2))
  # inner hole
  $holeR = $s * 0.11
  $g.FillEllipse($navyBrush, [float]($cx - $holeR), [float]($headCy - $holeR), [float]($holeR * 2), [float]($holeR * 2))
  $g.DrawEllipse($goldPen, [float]($cx - $holeR), [float]($headCy - $holeR), [float]($holeR * 2), [float]($holeR * 2))

  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "wrote $path"
}

New-Icon "$outDir\icon-192.png" 192 0.16
New-Icon "$outDir\icon-512.png" 512 0.16
New-Icon "$outDir\icon-maskable-512.png" 512 0.26
New-Icon "$outDir\apple-touch-icon.png" 180 0.12
New-Icon "$outDir\favicon-32.png" 32 0.12
Write-Host "done"
