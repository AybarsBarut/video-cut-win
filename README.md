# Video Cut Win

**Windows için tek komutla çalışan PowerShell video kırpma aracı.** FFmpeg
kullanarak MP4 ve diğer yaygın video dosyalarını hassas biçimde kırpar veya
yeniden kodlama yapmadan hızlıca böler.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-required-007808?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows/)

## Hızlı Başlangıç

Videonun bulunduğu klasörde PowerShell açın ve çalıştırın:

```powershell
irm -useb "https://raw.githubusercontent.com/AybarsBarut/video-cut-win/main/win-video-cut.ps1" | iex
win iex x.mp4 1.00 3.33
```

Bu komut `x.mp4` dosyasının `1.00` ile `3.33` saniyeleri arasını kırpar ve
aynı klasöre şuna benzer bir dosya kaydeder:

```text
x_cut_1_00-3_33.mp4
```

## Özellikler

- Windows PowerShell 5.1 ve PowerShell 7+ desteği
- FFmpeg ile kare hassasiyetine yakın video kırpma
- `-Fast` ile yeniden kodlama olmadan hızlı stream copy
- Nokta (`3.33`) ve virgül (`3,33`) ile ondalıklı süre desteği
- Eksik argümanlar için interaktif kullanım
- FFmpeg yoksa `winget` üzerinden otomatik kurulum
- Boşluk içeren dosya yollarıyla güvenli çalışma
- Mevcut dosyaların üzerine yazmadan benzersiz çıktı adı üretme
- H.264 video, AAC ses ve web oynatımı için fast-start çıktısı

## Kullanım

### Hassas kırpma

Varsayılan mod videoyu H.264, sesi AAC olarak yeniden kodlar:

```powershell
win iex video.mp4 10.5 25.75
```

`iex`, `cut` ve `trim` alt komutları aynı kırpma işlemini yapar:

```powershell
win cut video.mp4 10.5 25.75
win trim video.mp4 10.5 25.75
```

### Hızlı kırpma

```powershell
win iex video.mp4 10.5 25.75 -Fast
```

`-Fast` modu stream copy kullanır. Yeniden kodlama yapmadığı için çok hızlıdır
ve kalite kaybı oluşturmaz. Kesim noktası videodaki en yakın keyframe'e
bağlı olduğundan başlangıç veya bitiş zamanı hassas mod kadar kesin olmayabilir.

### İnteraktif kullanım

Süreleri yazmazsanız araç başlangıç ve bitiş değerlerini sorar:

```powershell
win iex video.mp4
```

Dosya adını da interaktif olarak girebilirsiniz:

```powershell
win iex
```

### Virgüllü ondalık süre

Türkçe bölgesel ayarlarla virgüllü süreler doğrudan kullanılabilir:

```powershell
win iex video.mp4 1,00 3,33
```

Dosya yolunda boşluk varsa yolu tırnak içine alın:

```powershell
win iex "tatil videosu.mp4" 5.25 18.50
```

## Komut Yapısı

```text
win <iex|cut|trim> <video-dosyası> <başlangıç-saniyesi> <bitiş-saniyesi> [-Fast]
```

| Argüman | Açıklama |
| --- | --- |
| `iex`, `cut`, `trim` | Desteklenen alt komutlar |
| `video-dosyası` | Kırpılacak videonun yolu |
| `başlangıç-saniyesi` | Kesimin başlayacağı saniye |
| `bitiş-saniyesi` | Kesimin sona ereceği saniye |
| `-Fast` | İsteğe bağlı hızlı stream-copy modu |

## FFmpeg Kurulumu

Araç önce sistemde `ffmpeg` komutunu arar. FFmpeg bulunamazsa ve `winget`
kullanılabiliyorsa aşağıdaki paketi otomatik kurmayı dener:

```powershell
winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
```

Kurulumdan sonra FFmpeg hâlâ bulunamazsa PowerShell'i kapatıp yeniden açın.
`winget` bulunmayan sistemlerde [FFmpeg'i manuel kurun](https://ffmpeg.org/download.html)
ve kurulum klasörünü `PATH` değişkenine ekleyin.

## Çıktı Adlandırma

Kırpılan video kaynak dosyayla aynı klasöre kaydedilir:

```text
video_cut_1_00-3_33.mp4
```

Aynı isimde bir dosya varsa mevcut dosyanın üzerine yazılmaz:

```text
video_cut_1_00-3_33_1.mp4
video_cut_1_00-3_33_2.mp4
```

## Örnekler

```powershell
# 1 ile 3 saniye arasını hassas kırp
win iex x.mp4 1 3

# Ondalıklı sürelerle kırp
win iex x.mp4 1.00 3.33

# Türkçe ondalık ayracı kullan
win iex x.mp4 1,00 3,33

# Yeniden kodlama olmadan hızlı kırp
win iex x.mp4 1.00 3.33 -Fast
```

## Sorun Giderme

**Video dosyası bulunamadı**

PowerShell'in video dosyasının bulunduğu klasörde açık olduğundan emin olun
veya dosyanın tam yolunu verin.

**FFmpeg kuruldu ancak bulunamıyor**

PowerShell penceresini kapatıp yeniden açın, ardından yükleme ve kırpma
komutlarını tekrar çalıştırın.

**Hızlı mod tam istenen noktadan başlamıyor**

Bu durum stream-copy modundaki keyframe sınırlarından kaynaklanır. Hassas
kesim için komutu `-Fast` olmadan çalıştırın.

## Execution Policy

Script `irm | iex` ile mevcut PowerShell oturumuna yüklendiği için execution
policy ayarını değiştirmeniz gerekmez. Yeni bir PowerShell oturumu açtığınızda
yükleme komutunu yeniden çalıştırın.

> İnternetten alınan scriptleri çalıştırmadan önce içeriğini incelemek iyi bir
> güvenlik uygulamasıdır.

## Lisans

Bu proje [MIT Lisansı](LICENSE) ile sunulur.

---

English: A lightweight Windows PowerShell video cutter and FFmpeg video
trimmer with precise re-encoding, fast stream-copy mode, interactive input,
decimal timestamp support, and automatic FFmpeg installation through winget.
