param(
    [Parameter(Mandatory=$true)][string]$RawPath,
    [string]$OutputPath,
    [string[]]$Locales = @('en-GB'),
    [ValidateSet('outer','inner','iphone','ipad')][string[]]$Families = @('outer')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
if (!$OutputPath) { $OutputPath = Join-Path $projectRoot 'marketing/duo/exports' }
$copy = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot 'marketing/duo/copy.json') | ConvertFrom-Json
$captureManifest = Get-Content -Raw -Encoding UTF8 (Join-Path $RawPath 'manifest.json') | ConvertFrom-Json
$exports = [System.Collections.Generic.List[object]]::new()
foreach ($locale in $Locales) {
    $text = $copy.locales.$locale
    if (!$text -or $text.headlines.Count -ne 10) { throw "Incomplete screenshot copy: $locale" }
    $faceName = switch -Regex ($locale) {
        '^ja' { 'Yu Gothic'; break }
        '^ko' { 'Malgun Gothic'; break }
        '^zh-Hans' { 'Microsoft YaHei'; break }
        '^zh-Hant' { 'Microsoft JhengHei'; break }
        '^hi' { 'Nirmala UI'; break }
        default { 'Segoe UI' }
    }
    foreach ($family in $Families) {
        $sizes = switch ($family) {
            'outer' { '1398x2034' }
            'inner' { '2007x2853' }
            'iphone' { '1179x2556'; '1206x2622' }
            'ipad' { '2048x2732'; '2064x2752' }
        }
        for ($index=0; $index -lt 10; $index++) {
            $route = $copy.routes[$index]
            $capture = @($captureManifest.captures | Where-Object { $_.locale -eq $locale -and $_.family -eq $family -and $_.route -eq $route })
            if ($capture.Count -ne 1) { throw "Missing native localized capture: $locale $family $route" }
            if ($capture[0].bundleLocale -ne $locale) { throw "Native UI locale differs: $locale $family $route" }
            $raw = Join-Path $RawPath $capture[0].file
            $native = [System.Drawing.Image]::FromFile($raw)
            try {
                $width = $native.Width
                $height = $native.Height
                if ("$($width)x$($height)" -notin $sizes) { throw "Wrong native display dimensions: $raw" }
                $scale = $width / 1398.0
                $margin = [int](78*$scale)
                if ((Get-FileHash -LiteralPath $raw -Algorithm SHA256).Hash.ToLowerInvariant() -ne $capture[0].sha256) { throw "Capture hash mismatch: $raw" }
                $bitmap = [System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F5F2E9'))
                $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $teal = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#153F3E'))
                $muted = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#466561'))
                $brand = [System.Drawing.Font]::new('Segoe UI',[single](29*$scale),[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
                $graphics.DrawString('LEAVEWELL',$brand,$teal,[single]$margin,[single](46*$scale))
                $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
                if ($locale -eq 'ar') { $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::DirectionRightToLeft }
                $lines = $text.headlines[$index] -split "`n"
                $fontSize = [int](86*$scale)
                $top = [int](430*$scale)
                do {
                    $headline = [System.Drawing.Font]::new($faceName,$fontSize,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
                    $maxTextWidth = 0
                    foreach ($line in $lines) { $maxTextWidth = [Math]::Max($maxTextWidth,$graphics.MeasureString($line,$headline,[int]::MaxValue,$format).Width) }
                    $lineSpacing = [Math]::Max($fontSize*1.35,$headline.GetHeight($graphics)*1.05)
                    $tooTall = (127*$scale + $lines.Count*$lineSpacing) -gt ($top-30*$scale)
                    $tooWide = $maxTextWidth -gt ($width-2*$margin)
                    if ($tooWide -or $tooTall) { $headline.Dispose(); $fontSize-- }
                } while (($tooWide -or $tooTall) -and $fontSize -gt 20)
                if ($fontSize -le 20) { throw "Headline cannot fit: $locale $route" }
                $y = 127*$scale
                foreach ($line in $lines) {
                    $rect = [System.Drawing.RectangleF]::new($margin,[single]$y,($width-2*$margin),[single]($fontSize*1.7))
                    $graphics.DrawString($line,$headline,$teal,$rect,$format)
                    $y += $lineSpacing
                }
                if ($y -gt $top-30*$scale) { throw "Headline overlaps app: $locale $route" }
                $availableHeight = $height-$top-[int](115*$scale)
                $factor = [Math]::Min(($width-2*$margin)/$native.Width,$availableHeight/$native.Height)
                $screenWidth = [int]($native.Width*$factor)
                $screenHeight = [int]($native.Height*$factor)
                $left = [int](($width-$screenWidth)/2)
                $frame = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#153F3E'))
                $graphics.FillRectangle($frame,$left-8,$top-8,$screenWidth+16,$screenHeight+16)
                $graphics.DrawImage($native,$left,$top,$screenWidth,$screenHeight)
                $footer = if ($route -eq 'report') {$text.paid} else {$text.footer}
                $footerSize = [int](32*$scale)
                do {
                    $footerFont = [System.Drawing.Font]::new($faceName,[single]$footerSize,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
                    $footerTooWide = $graphics.MeasureString($footer,$footerFont,[int]::MaxValue,$format).Width -gt $width-2*$margin
                    if ($footerTooWide) { $footerFont.Dispose(); $footerSize-- }
                } while ($footerTooWide -and $footerSize -gt 24*$scale)
                if ($footerTooWide) { throw "Footer cannot fit legibly: $locale $route" }
                $footerRect = [System.Drawing.RectangleF]::new($margin,[single]($height-65*$scale),($width-2*$margin),[single](55*$scale))
                if ($graphics.MeasureString($footer,$footerFont,[int]::MaxValue,$format).Width -gt $width-2*$margin) { throw "Footer cannot fit: $locale $route" }
                $graphics.DrawString($footer,$footerFont,$muted,$footerRect,$format)
                $folder = Join-Path $OutputPath "$locale/$family"
                [void][System.IO.Directory]::CreateDirectory($folder)
                $filename = ('{0:D2}-{1}.png' -f ($index+1),$route)
                $path = Join-Path $folder $filename
                $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
                $exports.Add(@{file="$locale/$family/$filename"; locale=$locale; family=$family; width=$width; height=$height; nativeSource=$capture[0].file; sourceSha256=$capture[0].sha256; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()})
                $footerFont.Dispose(); $frame.Dispose(); $headline.Dispose(); $format.Dispose(); $brand.Dispose(); $teal.Dispose(); $muted.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
            } finally { $native.Dispose() }
        }
    }
}
@{source='Real Xcode 27.1 simulator captures; original UI preserved with proportional scaling'; fictionalDemoData=$true; captures=$exports} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputPath 'manifest.json') -Encoding UTF8
Write-Output "Exported $($exports.Count) validated native storefront screenshots."
