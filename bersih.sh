#!/bin/bash

# Ubuntu Deep Cleaner
# Skrip pembersihan mendalam untuk Ubuntu desktop
# Simpan di /usr/local/bin/ubuntu-deep-cleaner.sh
# Pastikan chmod +x /usr/local/bin/ubuntu-deep-cleaner.sh

# Mengatur log
LOG_DIR="/var/log/deep-cleaner"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deep-clean-$(date +%Y-%m-%d).log"

# Fungsi logging
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Cek jika dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Skrip ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

log "====== MEMULAI PEMBERSIHAN SISTEM MENDALAM ======"

# 1. Pembersihan APT menyeluruh
log "1. Membersihkan cache APT dan paket-paket tidak terpakai"
apt clean -y >> "$LOG_FILE" 2>&1
apt autoclean -y >> "$LOG_FILE" 2>&1
apt autoremove --purge -y >> "$LOG_FILE" 2>&1

# 2. Menghapus paket-paket yang "obsolete" dan tidak digunakan
log "2. Mengidentifikasi dan menghapus paket obsolete"
if ! command -v deborphan &> /dev/null; then
    apt install -y deborphan >> "$LOG_FILE" 2>&1
fi
deborphan | xargs apt purge -y >> "$LOG_FILE" 2>&1

# 3. Membersihkan paket-paket konfigurasi yang sudah dihapus
log "3. Membersihkan paket konfigurasi residu"
dpkg --list | grep '^rc' | awk '{print $2}' | xargs apt purge -y >> "$LOG_FILE" 2>&1

# 4. Membersihkan kernel lama (menyimpan kernel saat ini dan satu cadangan)
log "4. Membersihkan kernel lama"
CURRENT_KERNEL=$(uname -r)
log "  Kernel saat ini: $CURRENT_KERNEL (akan dipertahankan)"
dpkg -l 'linux-image-*' 'linux-headers-*' | grep '^ii' | awk '{print $2}' | grep -v "$CURRENT_KERNEL" | sort -V | head -n -1 | xargs apt purge -y >> "$LOG_FILE" 2>&1

# 5. Membersihkan file log sistem
log "5. Membersihkan dan memperkecil log sistem"
journalctl --vacuum-time=3d >> "$LOG_FILE" 2>&1
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete
find /var/log -type f -name "*.old" -delete
find /var/log -type f -regex '.*\.[0-9]+$' -delete
echo "" > /var/log/wtmp
echo "" > /var/log/btmp
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null

# 6. Membersihkan cache dan file sementara untuk semua pengguna
log "6. Membersihkan cache dan file temp untuk semua pengguna"
USERS=$(ls /home)
for USER in $USERS; do
    USER_ID=$(id -u "$USER" 2>/dev/null)
    if [ -d "/home/$USER" ] && [ ! -z "$USER_ID" ]; then
        log "  Membersihkan cache untuk pengguna: $USER"
        # Cache umum
        rm -rf /home/$USER/.cache/* 2>/dev/null
        
        # Cache browser
        # Firefox
        if [ -d "/home/$USER/.mozilla/firefox" ]; then
            find /home/$USER/.mozilla/firefox -name "Cache" -type d -exec rm -rf {} \; 2>/dev/null
            find /home/$USER/.mozilla/firefox -name "cache2" -type d -exec rm -rf {} \; 2>/dev/null
            find /home/$USER/.mozilla/firefox -name "thumbnails" -type d -exec rm -rf {} \; 2>/dev/null
            find /home/$USER/.mozilla/firefox -name "cookies.sqlite" -delete 2>/dev/null
            find /home/$USER/.mozilla/firefox -name "webappsstore.sqlite" -delete 2>/dev/null
            find /home/$USER/.mozilla/firefox -name "chromeappsstore.sqlite" -delete 2>/dev/null
        fi
        
        # Chrome/Chromium
        rm -rf /home/$USER/.config/google-chrome/Default/Cache/* 2>/dev/null
        rm -rf /home/$USER/.config/google-chrome/Default/Code\ Cache/* 2>/dev/null
        rm -rf /home/$USER/.config/chromium/Default/Cache/* 2>/dev/null
        rm -rf /home/$USER/.config/chromium/Default/Code\ Cache/* 2>/dev/null
        
        # Trash
        rm -rf /home/$USER/.local/share/Trash/* 2>/dev/null
        
        # Membersihkan thumbnail
        rm -rf /home/$USER/.thumbnails/* 2>/dev/null
        rm -rf /home/$USER/.cache/thumbnails/* 2>/dev/null
        
        # File sementara
        find /home/$USER -name "*.tmp" -type f -delete 2>/dev/null
        find /home/$USER -name "*.temp" -type f -delete 2>/dev/null
        
        # Cache aplikasi spesifik
        rm -rf /home/$USER/.config/*/Cache/* 2>/dev/null
        rm -rf /home/$USER/.cache/pip/* 2>/dev/null
        rm -rf /home/$USER/.npm/_cacache/* 2>/dev/null
        rm -rf /home/$USER/.gradle/caches/* 2>/dev/null
        rm -rf /home/$USER/.composer/cache/* 2>/dev/null
        
        # Membersihkan unduhan lama
        if [ -d "/home/$USER/Downloads" ]; then
            find /home/$USER/Downloads -type f -atime +30 -exec rm {} \; 2>/dev/null
        fi
        
        # Reset izin
        chown -R $USER:$USER /home/$USER/.cache 2>/dev/null
        chown -R $USER:$USER /home/$USER/.local 2>/dev/null
    fi
done

# 7. Membersihkan file temp dan swap
log "7. Membersihkan file temp sistem dan swap"
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null

# Jika swap file digunakan, bersihkan
if grep -q "swapfile" /etc/fstab; then
    log "  Membersihkan swap file"
    swapoff /swapfile 2>/dev/null
    swapon /swapfile 2>/dev/null
fi

# 8. Membersihkan cache font dan thumbnail sistem
log "8. Membersihkan cache font dan thumbnail sistem"
rm -rf /var/cache/fontconfig/* 2>/dev/null
rm -rf /var/lib/dpkg/available-old 2>/dev/null
rm -rf /var/lib/apt/lists/* 2>/dev/null
apt-get update >> "$LOG_FILE" 2>&1

# 9. Membersihkan cache snap (jika ada)
log "9. Membersihkan cache snap"
if command -v snap &> /dev/null; then
    # Mendapatkan daftar revisi snap yang tidak digunakan
    SNAPS_TO_CLEAN=$(snap list --all | awk '/disabled/{print $1" --revision="$3}')
    if [ ! -z "$SNAPS_TO_CLEAN" ]; then
        for SNAP in $SNAPS_TO_CLEAN; do
            log "  Menghapus snap tidak terpakai: $SNAP"
            snap remove $SNAP >> "$LOG_FILE" 2>&1
        done
    fi
    # Membersihkan cache snap
    rm -rf /var/lib/snapd/cache/* 2>/dev/null
fi

# 10. Membersihkan cache flatpak (jika ada)
log "10. Membersihkan cache flatpak"
if command -v flatpak &> /dev/null; then
    flatpak uninstall --unused -y >> "$LOG_FILE" 2>&1
fi

# 11. Membersihkan docker (jika terinstall)
log "11. Memeriksa dan membersihkan Docker"
if command -v docker &> /dev/null; then
    log "  Docker terinstall, membersihkan container, images, dan volume tidak terpakai"
    docker system prune -af >> "$LOG_FILE" 2>&1
fi

# 12. Membersihkan lokalisasi bahasa yang tidak digunakan
log "12. Membersihkan lokalisasi bahasa tidak digunakan"
if ! command -v localepurge &> /dev/null; then
    log "  Menginstall localepurge"
    echo "localepurge localepurge/nopurge multiselect en, id" | debconf-set-selections
    echo "localepurge localepurge/use-dpkg-feature boolean true" | debconf-set-selections
    apt-get install -y localepurge >> "$LOG_FILE" 2>&1
fi
localepurge >> "$LOG_FILE" 2>&1

# 13. BleachBit (jika terinstall)
log "13. Memeriksa dan menjalankan BleachBit"
if ! command -v bleachbit &> /dev/null; then
    log "  Menginstal BleachBit"
    apt install -y bleachbit >> "$LOG_FILE" 2>&1
fi

if command -v bleachbit &> /dev/null; then
    log "  Menjalankan BleachBit pembersihan mendalam"
    bleachbit --clean system.cache system.localizations system.trash system.tmp \
    system.rotated_logs apt.autoclean apt.autoremove apt.clean bash.history \
    deepscan.backup deepscan.tmp firefox.cache firefox.cookies firefox.download_history \
    firefox.forms google_chrome.cache google_chrome.cookies thumbnails.cache \
    --preset >> "$LOG_FILE" 2>&1
fi

# 14. Mengecek paket terkorupsi dan memperbaikinya
log "14. Memeriksa dan memperbaiki paket terkorupsi"
dpkg --configure -a >> "$LOG_FILE" 2>&1
apt install -f -y >> "$LOG_FILE" 2>&1

# 15. Membersihkan file duplikat besar
log "15. Memeriksa file duplikat besar"
if ! command -v fdupes &> /dev/null; then
    log "  Menginstall fdupes"
    apt install -y fdupes >> "$LOG_FILE" 2>&1
fi

if command -v fdupes &> /dev/null; then
    # Mencari file duplikat di beberapa lokasi umum
    log "  Mencari file duplikat di folder umum (hanya laporan, tidak menghapus)"
    fdupes -r -S -q /home /var/log /var/cache >> "$LOG_FILE" 2>&1
fi

# 16. Membersihkan cache thumbnails lama
log "16. Membersihkan thumbnail lama (> 30 hari)"
find /home -path "*/thumbnails/*" -type f -atime +30 -delete 2>/dev/null
find /home -path "*/.cache/thumbnails/*" -type f -atime +30 -delete 2>/dev/null

# 17. Membersihkan paket bahasa yang tidak digunakan
log "17. Membersihkan paket bahasa tidak digunakan"
apt remove -y \
    $(check-language-support -l en | grep -v "en\|id") \
    $(check-language-support | grep ":" | cut -d":" -f1) >> "$LOG_FILE" 2>&1

# 18. Mengoptimalkan database
log "18. Mengoptimalkan database sistem"
if ! command -v sqlite3 &> /dev/null; then
    log "  Menginstall sqlite3"
    apt install -y sqlite3 >> "$LOG_FILE" 2>&1
fi

if command -v sqlite3 &> /dev/null; then
    for USER in $USERS; do
        if [ -d "/home/$USER" ]; then
            log "  Mengoptimalkan database SQLite untuk pengguna $USER"
            find /home/$USER -name "*.sqlite" -type f 2>/dev/null | while read -r DB; do
                sqlite3 "$DB" "VACUUM;" 2>/dev/null
                sqlite3 "$DB" "REINDEX;" 2>/dev/null
            done
        fi
    done
fi

# 19. Menghapus tema dan ikon tidak digunakan
log "19. Membersihkan tema dan icon tidak digunakan"
CURRENT_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
CURRENT_ICONS=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")

log "  Tema saat ini: $CURRENT_THEME"
log "  Ikon saat ini: $CURRENT_ICONS"

# Tema default yang harus dipertahankan
DEFAULT_THEMES="Adwaita|Yaru|Ambiance|Radiance|HighContrast|$CURRENT_THEME"
DEFAULT_ICONS="Adwaita|Yaru|ubuntu-mono-dark|ubuntu-mono-light|HighContrast|$CURRENT_ICONS"

# Hapus tema custom yang tidak digunakan
if [ -d "/usr/share/themes" ]; then
    find /usr/share/themes -maxdepth 1 -type d | grep -v -E "$DEFAULT_THEMES" | tail -n +2 | while read -r THEME; do
        THEME_NAME=$(basename "$THEME")
        log "  Menghapus tema tidak digunakan: $THEME_NAME"
        rm -rf "$THEME" 2>/dev/null
    done
fi

# Hapus ikon custom yang tidak digunakan
if [ -d "/usr/share/icons" ]; then
    find /usr/share/icons -maxdepth 1 -type d | grep -v -E "$DEFAULT_ICONS" | tail -n +2 | while read -r ICON; do
        ICON_NAME=$(basename "$ICON")
        log "  Menghapus ikon tidak digunakan: $ICON_NAME"
        rm -rf "$ICON" 2>/dev/null
    done
fi

# 20. Membersihkan font tidak digunakan
log "20. Membersihkan font tidak digunakan"
# Simpan font default
DEFAULT_FONTS="dejavu|ubuntu|liberation|freefont|fonts-noto|ttf-mscorefonts"

# Cek font terinstall
dpkg -l | grep font | grep ^ii | awk '{print $2}' | grep -v -E "$DEFAULT_FONTS" > /tmp/font_list.txt

if [ -s /tmp/font_list.txt ]; then
    log "  Daftar font terinstall yang tidak standar:"
    cat /tmp/font_list.txt | tee -a "$LOG_FILE"
    # Note: Font tidak dihapus otomatis untuk menghindari masalah
    log "  Untuk menghapus font yang tidak digunakan, jalankan: apt purge font-name"
fi

# 21. Analisis ruang disk
log "21. Analisis penggunaan ruang disk"
log "  Penggunaan disk sebelum pembersihan:"
df -h / | awk 'NR==2 {print "    Digunakan: "$3 " dari " $2 " (" $5 ")"}' | tee -a "$LOG_FILE"

# 22. Opsional: Membersihkan folder unduhan lama (>30 hari)
# Dinonaktifkan secara default - aktifkan jika diinginkan
#log "22. Mencari file unduhan lama (>30 hari)"
#for USER in $USERS; do
#    if [ -d "/home/$USER/Downloads" ]; then
#        log "  File unduhan lama untuk $USER:"
#        find /home/$USER/Downloads -type f -atime +30 -exec ls -la {} \; | tee -a "$LOG_FILE"
#        # Hapus file unduhan lama (dinonaktifkan secara default)
#        # find /home/$USER/Downloads -type f -atime +30 -delete
#    fi
#done

# 23. Mengkompres log yang sudah dibersihkan
log "23. Mengkompres log"
find "$LOG_DIR" -name "*.log" -type f -mtime +7 -exec gzip {} \;

# 24. Rapikan file konfigurasi
log "24. Merapikan file konfigurasi sistem"
for DIR in /etc /var/lib; do
    find "$DIR" -name "*.dpkg-old" -o -name "*.dpkg-dist" -o -name "*.dpkg-new" -o -name "*.dpkg-tmp" -delete 2>/dev/null
done

# 25. Menghapus crash reports
log "25. Membersihkan laporan crash"
rm -rf /var/crash/* 2>/dev/null

# 26. Membersihkan core dumps
log "26. Membersihkan core dumps"
rm -f /core* 2>/dev/null
find /var -name "core" -delete 2>/dev/null
find / -xdev -name "core" -delete 2>/dev/null

# 27. Membersihkan folder .Trash di semua partisi
log "27. Membersihkan folder .Trash di semua partisi"
find /media -name ".Trash*" -type d -exec rm -rf {} \; 2>/dev/null
find /mnt -name ".Trash*" -type d -exec rm -rf {} \; 2>/dev/null

# 28. Update GRUB setelah pembersihan
log "28. Memperbarui GRUB"
update-grub >> "$LOG_FILE" 2>&1

# 29. Jalankan fstrim jika disupport
log "29. Menjalankan TRIM untuk SSD (jika didukung)"
if command -v fstrim &> /dev/null; then
    fstrim -av >> "$LOG_FILE" 2>&1
fi

# Final: Analisis ruang disk setelah pembersihan
log "=== PEMBERSIHAN SELESAI ==="
log "Penggunaan disk setelah pembersihan:"
df -h / | awk 'NR==2 {print "    Digunakan: "$3 " dari " $2 " (" $5 ")"}' | tee -a "$LOG_FILE"

# Hitung ruang yang dibebaskan
BEFORE=$(grep "Penggunaan disk sebelum" -A 1 "$LOG_FILE" | tail -n 1 | grep -oP '\(\K[^%]+')
AFTER=$(grep "Penggunaan disk setelah" -A 1 "$LOG_FILE" | tail -n 1 | grep -oP '\(\K[^%]+')
SAVED=$((BEFORE - AFTER))
log "Ruang yang dibebaskan: $SAVED% dari total disk"

log "Log pembersihan lengkap tersimpan di: $LOG_FILE"
echo ""
echo "Pembersihan mendalam selesai. Ruang disk yang dibebaskan: $SAVED%"
echo "Detail lengkap tersimpan dalam log: $LOG_FILE"
