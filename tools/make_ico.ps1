Add-Type -AssemblyName System.Drawing

$inputPng  = "C:\Users\Maxi\Desktop\dev\coppolapavese\assets\images\logo.png"
$outputIco = "C:\Users\Maxi\Desktop\dev\coppolapavese\windows\runner\resources\app_icon.ico"

$sizes = @(16, 32, 48, 256)

$source = [System.Drawing.Image]::FromFile($inputPng)

$memStream     = New-Object System.IO.MemoryStream
$binaryWriter  = New-Object System.IO.BinaryWriter($memStream)

# --- ICO Header (6 bytes) ---
$binaryWriter.Write([uint16]0)              # Reserved = 0
$binaryWriter.Write([uint16]1)              # Type = 1 (ICO)
$binaryWriter.Write([uint16]$sizes.Count)  # Number of images

# --- Render each size to PNG bytes ---
$images = @()
foreach ($sz in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode    = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode        = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode      = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality   = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.CompositingMode      = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.DrawImage($source, 0, 0, $sz, $sz)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $images += @{ Size = $sz; Data = $ms.ToArray() }
    $ms.Dispose()
}

# --- Directory entries (16 bytes each) ---
$dataOffset = [uint32](6 + $sizes.Count * 16)
foreach ($img in $images) {
    $w = if ($img.Size -eq 256) { [byte]0 } else { [byte]$img.Size }
    $h = if ($img.Size -eq 256) { [byte]0 } else { [byte]$img.Size }
    $binaryWriter.Write($w)                          # Width  (0 = 256)
    $binaryWriter.Write($h)                          # Height (0 = 256)
    $binaryWriter.Write([byte]0)                     # ColorCount
    $binaryWriter.Write([byte]0)                     # Reserved
    $binaryWriter.Write([uint16]1)                   # Planes
    $binaryWriter.Write([uint16]32)                  # BitCount
    $binaryWriter.Write([uint32]$img.Data.Length)    # SizeInBytes
    $binaryWriter.Write($dataOffset)                 # FileOffset
    $dataOffset += [uint32]$img.Data.Length
}

# --- Image data ---
foreach ($img in $images) {
    $binaryWriter.Write($img.Data)
}

$binaryWriter.Flush()

[System.IO.File]::WriteAllBytes($outputIco, $memStream.ToArray())

$source.Dispose()
$memStream.Dispose()
$binaryWriter.Dispose()

$finalSize = (Get-Item $outputIco).Length
Write-Host "ICO multi-tamaño creado: $outputIco"
Write-Host "Tamaños incluidos: 16x16, 32x32, 48x48, 256x256"
Write-Host "Tamaño del archivo: $finalSize bytes"
