Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$assetDir = Join-Path $root "assets\branding"
New-Item -ItemType Directory -Path $assetDir -Force | Out-Null

$kiwi = [System.Drawing.ColorTranslator]::FromHtml("#98C95F")
$obsidian = [System.Drawing.ColorTranslator]::FromHtml("#0F172A")
$black = [System.Drawing.Color]::Black
$transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)

function New-Canvas {
    param(
        [int]$Width,
        [int]$Height,
        [System.Drawing.Color]$Background
    )

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.Clear($Background)

    return @{
        Bitmap = $bitmap
        Graphics = $graphics
    }
}

function Save-Canvas {
    param(
        [hashtable]$Canvas,
        [string]$Path
    )

    $Canvas.Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Canvas.Graphics.Dispose()
    $Canvas.Bitmap.Dispose()
}

function Draw-KoveK {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Color]$Color,
        [float]$X,
        [float]$Y,
        [float]$Size
    )

    $brush = New-Object System.Drawing.SolidBrush $Color
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath

    $leftBar = New-Object System.Drawing.RectangleF ($X), ($Y), ($Size * 0.12), ($Size)
    $path.AddRectangle($leftBar)

    $topPoints = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($X, $Y),
        [System.Drawing.PointF]::new($X + $Size * 0.94, $Y),
        [System.Drawing.PointF]::new($X + $Size * 0.46, $Y + $Size * 0.48),
        [System.Drawing.PointF]::new($X + $Size * 0.12, $Y + $Size * 0.48)
    )
    $path.AddPolygon($topPoints)

    $bottomPoints = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($X + $Size * 0.10, $Y + $Size * 0.52),
        [System.Drawing.PointF]::new($X + $Size * 0.24, $Y + $Size * 0.40),
        [System.Drawing.PointF]::new($X + $Size * 0.90, $Y + $Size),
        [System.Drawing.PointF]::new($X + $Size * 0.68, $Y + $Size),
        [System.Drawing.PointF]::new($X + $Size * 0.16, $Y + $Size * 0.60)
    )
    $path.AddPolygon($bottomPoints)

    $baseBar = New-Object System.Drawing.RectangleF ($X), ($Y + $Size * 0.94), ($Size * 0.68), ($Size * 0.06)
    $path.AddRectangle($baseBar)

    $Graphics.FillPath($brush, $path)

    $path.Dispose()
    $brush.Dispose()
}

function Draw-Wordmark {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Color]$Color,
        [System.Drawing.Color]$InnerColor,
        [float]$X,
        [float]$Y,
        [float]$Height
    )

    $brush = New-Object System.Drawing.SolidBrush $Color
    $innerBrush = New-Object System.Drawing.SolidBrush $InnerColor
    $pen = New-Object System.Drawing.Pen $Color, ($Height * 0.09)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter

    $kSize = $Height * 0.86
    Draw-KoveK -Graphics $Graphics -Color $Color -X $X -Y ($Y + $Height * 0.06) -Size $kSize

    $oX = $X + $Height * 0.98
    $outer = New-Object System.Drawing.RectangleF ($oX), ($Y), ($Height * 0.62), ($Height)
    $inner = New-Object System.Drawing.RectangleF ($oX + $Height * 0.16), ($Y + $Height * 0.16), ($Height * 0.30), ($Height * 0.68)
    $Graphics.FillEllipse($brush, $outer)
    if ($InnerColor.A -eq 0) {
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $Graphics.FillEllipse($innerBrush, $inner)
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    } else {
        $Graphics.FillEllipse($innerBrush, $inner)
    }

    $vX = $oX + $Height * 0.90
    $vPoints = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($vX, $Y + $Height * 0.06),
        [System.Drawing.PointF]::new($vX + $Height * 0.62, $Y + $Height * 0.06),
        [System.Drawing.PointF]::new($vX + $Height * 0.31, $Y + $Height * 0.96)
    )
    $Graphics.DrawPolygon($pen, $vPoints)

    $eX = $vX + $Height * 0.88
    $eWidth = $Height * 0.52
    $Graphics.FillRectangle($brush, $eX, $Y, $Height * 0.10, $Height)
    $Graphics.FillRectangle($brush, $eX, $Y, $eWidth, $Height * 0.14)
    $Graphics.FillRectangle($brush, $eX, $Y + $Height * 0.43, $eWidth * 0.80, $Height * 0.14)
    $Graphics.FillRectangle($brush, $eX, $Y + $Height * 0.86, $eWidth, $Height * 0.14)

    $pen.Dispose()
    $innerBrush.Dispose()
    $brush.Dispose()
}

$iconCanvas = New-Canvas -Width 1024 -Height 1024 -Background $kiwi
Draw-KoveK -Graphics $iconCanvas.Graphics -Color $black -X 180 -Y 180 -Size 664
Save-Canvas -Canvas $iconCanvas -Path (Join-Path $assetDir "kove_icon_full.png")

$iconForegroundCanvas = New-Canvas -Width 1024 -Height 1024 -Background $transparent
Draw-KoveK -Graphics $iconForegroundCanvas.Graphics -Color $black -X 180 -Y 180 -Size 664
Save-Canvas -Canvas $iconForegroundCanvas -Path (Join-Path $assetDir "kove_icon_foreground.png")

$android12Canvas = New-Canvas -Width 1024 -Height 1024 -Background $transparent
Draw-KoveK -Graphics $android12Canvas.Graphics -Color $kiwi -X 180 -Y 180 -Size 664
Save-Canvas -Canvas $android12Canvas -Path (Join-Path $assetDir "kove_android12_mark.png")

$splashCanvas = New-Canvas -Width 2200 -Height 900 -Background $transparent
Draw-Wordmark -Graphics $splashCanvas.Graphics -Color $kiwi -InnerColor $transparent -X 430 -Y 200 -Height 360
Save-Canvas -Canvas $splashCanvas -Path (Join-Path $assetDir "kove_splash_logo.png")

$squareLogoCanvas = New-Canvas -Width 1200 -Height 1200 -Background $obsidian
Draw-Wordmark -Graphics $squareLogoCanvas.Graphics -Color $kiwi -InnerColor $obsidian -X 90 -Y 430 -Height 300
Save-Canvas -Canvas $squareLogoCanvas -Path (Join-Path $assetDir "kove_brand_preview.png")
