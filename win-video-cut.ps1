function global:win {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Command,

        [Parameter(Position = 1)]
        [string] $VideoFile,

        [Parameter(Position = 2)]
        [string[]] $StartTime,

        [Parameter(Position = 3)]
        [string[]] $EndTime,

        [switch] $Fast
    )

    Set-StrictMode -Version Latest

    function Show-Usage {
        Write-Host ""
        Write-Host "Kullanım:"
        Write-Host "  win iex <video> <başlangıç> <bitiş> [-Fast]"
        Write-Host "  win cut <video> <başlangıç> <bitiş> [-Fast]"
        Write-Host "  win trim <video> <başlangıç> <bitiş> [-Fast]"
        Write-Host ""
        Write-Host "Örnekler:"
        Write-Host "  win iex x.mp4 1.00 3.33"
        Write-Host "  win iex x.mp4 1,00 3,33 -Fast"
        Write-Host "  win iex x.mp4"
    }

    function ConvertTo-TimeValue {
        param(
            [Parameter(Mandatory = $true)]
            [string[]] $Value,

            [Parameter(Mandatory = $true)]
            [string] $DisplayName
        )

        $arrayFileLabel = $null
        $valueParts = @($Value)
        $culture = [System.Globalization.CultureInfo]::InvariantCulture

        if ($valueParts.Count -eq 2) {
            $wholePart = [Convert]::ToString($valueParts[0], $culture)
            $fractionPart = [Convert]::ToString($valueParts[1], $culture)
            $valueText = "$wholePart,$fractionPart"

            # PowerShell, tırnaksız 1,00 değerini 1 ve 0 olarak aktarır.
            $fractionLabel = if ($fractionPart -eq "0") { "00" } else { $fractionPart }
            $arrayFileLabel = "$($wholePart.TrimStart('+'))_$fractionLabel"
        }
        elseif ($valueParts.Count -eq 1) {
            $valueText = [Convert]::ToString($valueParts[0], $culture)
        }
        else {
            throw "$DisplayName sayısal olmalı. Örnek: 1, 1.00, 3.33 veya 3,33."
        }

        $normalized = $valueText.Trim().Replace(",", ".")
        if ($normalized -notmatch '^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$') {
            throw "$DisplayName sayısal olmalı. Örnek: 1, 1.00, 3.33 veya 3,33."
        }

        $numberStyle = [System.Globalization.NumberStyles]::AllowLeadingSign -bor
            [System.Globalization.NumberStyles]::AllowDecimalPoint
        $parsed = [decimal]::Zero

        if (-not [decimal]::TryParse(
                $normalized,
                $numberStyle,
                $culture,
                [ref] $parsed
            )) {
            throw "$DisplayName sayısal olmalı. Örnek: 1, 1.00, 3.33 veya 3,33."
        }

        if ($parsed -lt 0) {
            throw "$DisplayName negatif olamaz."
        }

        if ($null -ne $arrayFileLabel) {
            $fileLabel = $arrayFileLabel
        }
        else {
            $fileLabel = $normalized.TrimStart("+")
            if ($fileLabel.StartsWith(".")) {
                $fileLabel = "0$fileLabel"
            }
            if ($fileLabel.EndsWith(".")) {
                $fileLabel = $fileLabel.TrimEnd(".")
            }
            $fileLabel = $fileLabel.Replace(".", "_")
        }

        [pscustomobject] @{
            Number    = $parsed
            Ffmpeg    = $parsed.ToString(
                "0.############################",
                $culture
            )
            FileLabel = $fileLabel
        }
    }

    function Get-AvailableOutputPath {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Directory,

            [Parameter(Mandatory = $true)]
            [string] $BaseName
        )

        $candidate = Join-Path -Path $Directory -ChildPath "$BaseName.mp4"
        $suffix = 1

        while (Test-Path -LiteralPath $candidate) {
            $candidate = Join-Path -Path $Directory -ChildPath "${BaseName}_$suffix.mp4"
            $suffix++
        }

        $candidate
    }

    function Get-FfmpegCommand {
        $ffmpeg = Get-Command -Name "ffmpeg" -CommandType Application `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $ffmpeg) {
            return $ffmpeg.Path
        }

        $winget = Get-Command -Name "winget" -CommandType Application `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $winget) {
            throw (
                "FFmpeg bulunamadı ve winget bu sistemde kullanılabilir değil. " +
                "FFmpeg'i manuel olarak kurup PATH'e ekleyin."
            )
        }

        Write-Host "FFmpeg bulunamadı. winget ile Gyan.FFmpeg kuruluyor..."
        $wingetArguments = @(
            "install",
            "-e",
            "--id", "Gyan.FFmpeg",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        & $winget.Path @wingetArguments
        $wingetExitCode = $LASTEXITCODE

        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = @($env:Path, $machinePath, $userPath) -join ";"

        $ffmpeg = Get-Command -Name "ffmpeg" -CommandType Application `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $ffmpeg) {
            return $ffmpeg.Path
        }

        if ($wingetExitCode -ne 0) {
            throw (
                "FFmpeg kurulumu tamamlanamadı (winget çıkış kodu: $wingetExitCode). " +
                "Kurulumu kontrol edip tekrar deneyin."
            )
        }

        throw (
            "FFmpeg kuruldu ancak bu PowerShell oturumunda henüz bulunamadı. " +
            "PowerShell'i kapatıp yeniden açın ve komutu tekrar çalıştırın."
        )
    }

    if ([string]::IsNullOrWhiteSpace($Command)) {
        Show-Usage
        return
    }

    $supportedCommands = @("iex", "cut", "trim")
    if ($supportedCommands -notcontains $Command.ToLowerInvariant()) {
        Write-Error "Geçersiz alt komut: '$Command'. Desteklenen komutlar: iex, cut, trim." `
            -ErrorAction Continue
        Show-Usage
        return
    }

    if ([string]::IsNullOrWhiteSpace($VideoFile)) {
        $VideoFile = Read-Host "Video dosyası"
    }
    if ($null -eq $StartTime -or $StartTime.Count -eq 0) {
        $StartTime = Read-Host "Başlangıç saniyesi"
    }
    if ($null -eq $EndTime -or $EndTime.Count -eq 0) {
        $EndTime = Read-Host "Bitiş saniyesi"
    }

    if ([string]::IsNullOrWhiteSpace($VideoFile)) {
        throw "Video dosyası belirtilmedi."
    }

    try {
        $resolvedPath = (Resolve-Path -LiteralPath $VideoFile -ErrorAction Stop).Path
    }
    catch {
        throw "Video dosyası bulunamadı: '$VideoFile'."
    }

    $inputItem = Get-Item -LiteralPath $resolvedPath -ErrorAction Stop
    if ($inputItem.PSIsContainer) {
        throw "Belirtilen yol bir video dosyası değil, klasör: '$resolvedPath'."
    }

    $start = ConvertTo-TimeValue -Value $StartTime -DisplayName "Başlangıç süresi"
    $end = ConvertTo-TimeValue -Value $EndTime -DisplayName "Bitiş süresi"

    if ($end.Number -le $start.Number) {
        throw "Bitiş süresi başlangıç süresinden büyük olmalı."
    }

    $durationNumber = $end.Number - $start.Number
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $duration = $durationNumber.ToString(
        "0.############################",
        $culture
    )

    $directory = $inputItem.DirectoryName
    $sourceBaseName = [System.IO.Path]::GetFileNameWithoutExtension($inputItem.Name)
    $outputBaseName = "{0}_cut_{1}-{2}" -f (
        $sourceBaseName,
        $start.FileLabel,
        $end.FileLabel
    )
    $outputPath = Get-AvailableOutputPath -Directory $directory -BaseName $outputBaseName
    $ffmpegPath = Get-FfmpegCommand

    Write-Host ""
    Write-Host "Video kırpma işlemi başlıyor..."
    Write-Host "Girdi     : $resolvedPath"
    Write-Host "Başlangıç : $($start.Ffmpeg) saniye"
    Write-Host "Bitiş     : $($end.Ffmpeg) saniye"
    Write-Host "Süre      : $duration saniye"
    Write-Host "Çıktı     : $outputPath"
    Write-Host "Mod       : $(if ($Fast) { 'Hızlı (stream copy)' } else { 'Hassas (yeniden kodlama)' })"
    Write-Host ""

    if ($Fast) {
        $ffmpegArguments = @(
            "-hide_banner",
            "-y",
            "-ss", $start.Ffmpeg,
            "-i", $resolvedPath,
            "-t", $duration,
            "-map", "0",
            "-c", "copy",
            $outputPath
        )
    }
    else {
        $ffmpegArguments = @(
            "-hide_banner",
            "-y",
            "-ss", $start.Ffmpeg,
            "-i", $resolvedPath,
            "-t", $duration,
            "-map", "0:v?",
            "-map", "0:a?",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "18",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            $outputPath
        )
    }

    & $ffmpegPath @ffmpegArguments
    $ffmpegExitCode = $LASTEXITCODE

    if ($ffmpegExitCode -ne 0) {
        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
        }
        throw "FFmpeg işlemi başarısız oldu (çıkış kodu: $ffmpegExitCode)."
    }

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "FFmpeg hata bildirmedi ancak çıktı dosyası oluşturulamadı."
    }

    Write-Host ""
    Write-Host "Video başarıyla kırpıldı."
    Write-Host "Çıktı: $outputPath"
}

Write-Host "Video cutter yüklendi."
Write-Host "Kullanım: win iex video.mp4 1.00 3.33"
