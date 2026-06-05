# Mini Linux Dağıtımı

Bu proje, `mini_linux_dagitimi_tasarimi.md` dosyasında anlatılan mini Linux dağıtımını çalıştırılabilir bir iskelete dönüştürür. Yani sadece teorik bir tasarım yok; BusyBox tabanlı bir RootFS hazırlanır, bu RootFS imaj haline getirilir ve QEMU üzerinde test edilebilir.

Projede özellikle gömülü sistemlerde kullanılan sade ve güvenilir bir yapı hedeflenmiştir. Sistem dosyaları read-only tutulur, kalıcı veriler ayrı bir writable data alanına yazılır ve güncelleme tarafında A/B slot mantığı örneklenir.

## Hedef Cihaz

Tasarımda hedef cihaz olarak ARM Cortex-A53 tabanlı, 64-bit AArch64 mimarisinde çalışan küçük bir gömülü sistem kabul edilmiştir.

```text
CPU       : ARM Cortex-A53, 64-bit AArch64
RAM       : 512 MB
Storage   : 512 MB eMMC
Bootloader: U-Boot SPL + U-Boot
RootFS    : squashfs, read-only
Data      : ext4, writable
Update    : rootfs_a / rootfs_b A/B model
```

Yerel denemelerde host makinedeki BusyBox kullanılırsa RootFS de host mimarisine göre oluşur. Bu ortamda host `x86_64` olduğu için yerel demo imajı `x86_64` çalışır. Gerçek ARM64 hedef veya ARM64 QEMU testi için proje ayrıca ARM64 BusyBox ve ARM64 kernel indirebilir.

## Projenin Ürettiği Çıktılar

Build tamamlandığında ana çıktılar `build/images/` altında oluşur:

```text
build/rootfs/                         Üretilen RootFS dizini
build/images/rootfs_a.squashfs        Read-only sistem imajı A slotu
build/images/rootfs_b.squashfs        Read-only sistem imajı B slotu
build/images/data.ext4                Writable data bölümü imajı
build/images/initramfs.cpio.gz        Yerel QEMU testi için initramfs
build/images/initramfs-arm64.cpio.gz  ARM64 QEMU testi için initramfs
build/images/boot.tar                 Örnek boot bölümü içeriği
build/images/checksums.sha256         İmajların bütünlük özetleri
```

`rootfs_a.squashfs` ve `rootfs_b.squashfs`, A/B güncelleme modelini göstermek için iki ayrı sistem slotu gibi kullanılır. `data.ext4` ise cihaz ayarları, loglar ve uygulama verileri için ayrılmış writable alanı temsil eder.

## Temel Komutlar

Önce gerekli araçların kurulu olup olmadığını kontrol etmek için:

```bash
make check
```

Sadece RootFS ağacını üretmek için:

```bash
make rootfs
```

SquashFS RootFS ve ext4 data imajlarını üretmek için:

```bash
make images
```

Initramfs üretmek için:

```bash
make initramfs
```

Tüm temel çıktıları tek seferde üretmek için:

```bash
make
```

## QEMU ile Çalıştırma

Bu proje kernel derlemez. QEMU testi için hazır bir Linux kernel imajı kullanılır.

WSL gibi `/boot/vmlinuz-*` dosyasının bulunmadığı ortamlarda yerel test kernelini proje altına indirmek için:

```bash
make qemu-kernel
```

Ardından yerel `x86_64` QEMU testini başlatmak için:

```bash
make run-qemu-local
```

Boot başarılıysa seri konsolda şu satırlar görülür:

```text
mini-linux: starting init sequence
mini-linux: boot complete
```

Login ekranında kullanıcı adı `root` olarak girilir. Şu an demo amaçlı root şifresi boştur; parola sormadan Enter ile giriş yapılabilir.

QEMU’dan çıkmak için:

```text
Ctrl+A
X
```

## ARM64 QEMU Testi

ARM64 hedefe daha yakın bir test yapmak için ARM64 BusyBox ve ARM64 kernel proje altına indirilebilir:

```bash
make arm64-assets
```

ARM64 RootFS üretip QEMU üzerinde çalıştırmak için:

```bash
make run-qemu-arm64
```

Bu hedef sistem dizinlerine paket kurmaz. Gerekli `.deb` dosyalarını Ubuntu ports deposundan indirir, içinden ARM64 BusyBox ve kernel imajını çıkarır, sonra bunlarla ARM64 initramfs üretir.

ARM64 testinde de başarılı boot çıktısı şu şekilde görünür:

```text
mini-linux: starting init sequence
mini-linux: boot complete
```

## A/B Güncelleme Simülasyonu

Gömülü sistemlerde güncelleme sırasında cihazın bozulmasını önlemek için A/B slot yaklaşımı kullanılır. Bu projede bu mantık basit bir simülasyon scriptiyle gösterilir.

Simülasyonu başlatmak için:

```bash
make update-init
```

Pasif slota yeni bir RootFS imajı kurmak için:

```bash
make update-install
```

Yeni sistem başarılı açılmış gibi onaylamak için:

```bash
make update-good
```

Güncelleme durumunu görmek için:

```bash
make update-status
```

Başarısız açılış ve rollback senaryosunu denemek için:

```bash
./scripts/simulate-update.sh mark-bad
```

Bu akışta önce aktif slot `a` olur. Güncelleme pasif slot olan `b` üzerine hazırlanır. Başarılı boot onaylanırsa aktif slot `b` olur. Başarısız boot senaryosunda ise sistem eski slota geri döner.

Simülasyon scripti artık kısa log satırları da üretir. Bu loglar özellikle hangi slotun aktif olduğunu, yeni imajın hangi slota hazırlandığını ve rollback kararının neden verildiğini takip etmek için eklendi. Çıktılar bilinçli olarak sade tutuldu; amaç gerçek bir cihazda seri konsoldan bakan kişinin ne olduğunu hızlıca anlamasıdır.

Örnek:

```text
[mini-update] Aktif slot 'a'. Yeni imaj pasif slot 'b' üzerine hazırlanıyor.
[mini-update] SHA256 özeti kaydedildi: ...
Güncelleme adayı simüle edilen 'b' slotuna kuruldu.
```

QEMU başlatma scripti de benzer şekilde kernel, initramfs ve hedef mimariyi çalıştırmadan önce yazar. Böylece yanlış kernel veya yanlış mimari kullanıldığında hata ayıklamak daha kolay olur.

## Proje Yapısı

```text
configs/              Hedef cihaz, boot ve bölümleme ayarları
data-template/        Writable data bölümü içine konacak ilk dosyalar
rootfs-overlay/       RootFS içine kopyalanacak init, ağ, log ve debug dosyaları
scripts/              Build, imaj üretme, QEMU ve update simülasyonu scriptleri
build/                Üretilen dosyalar
```

Özetle bu repo, mini Linux dağıtımı için hem teknik tasarımı hem de çalıştırılabilir örnek çıktıları içerir. RootFS üretimi, read-only sistem imajı, writable data alanı, QEMU testi ve A/B güncelleme simülasyonu aynı proje içinde gösterilmiştir.
