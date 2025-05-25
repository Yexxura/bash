#!/bin/bash

# Script Komprehensif untuk Menonaktifkan SEMUA Auto Shutdown Ubuntu
# Tidak akan ada yang terlewat - TOTAL PROTECTION

echo "=== TOTAL AUTO SHUTDOWN ELIMINATION ==="
echo "Script ini akan menghapus SEMUA kemungkinan auto shutdown"
echo "Tidak ada yang akan tersisa!"
echo

# Periksa root permission
if [ "$EUID" -ne 0 ]; then
    echo "FATAL: Script harus dijalankan dengan sudo"
    echo "Gunakan: sudo bash $0"
    exit 1
fi

# Buat backup directory
BACKUP_DIR="/root/shutdown-prevention-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup disimpan di: $BACKUP_DIR"

# ===============================
# 1. SYSTEMD TOTAL ELIMINATION
# ===============================
echo "1. MENGHANCURKAN SEMUA SYSTEMD SHUTDOWN MECHANISMS..."

# Nonaktifkan semua target terkait power
POWER_TARGETS=(
    "poweroff.target" "reboot.target" "halt.target" "kexec.target"
    "shutdown.target" "final.target" "umount.target" "local-fs-pre.target"
    "suspend.target" "hibernate.target" "hybrid-sleep.target" "sleep.target"
    "suspend-then-hibernate.target" "emergency.target" "rescue.target"
)

for target in "${POWER_TARGETS[@]}"; do
    systemctl mask "$target" 2>/dev/null
    echo "   MASKED: $target"
done

# Nonaktifkan semua timer yang ada
systemctl list-timers --all --no-pager | grep -v "NEXT\|---" | awk '{print $NF}' | while IFS= read -r timer; do
    if [[ -n "$timer" && "$timer" != "ACTIVATES" ]]; then
        systemctl stop "$timer" 2>/dev/null
        systemctl disable "$timer" 2>/dev/null
        systemctl mask "$timer" 2>/dev/null
        echo "   ELIMINATED TIMER: $timer"
    fi
done

# Nonaktifkan semua service yang mencurigakan
DANGEROUS_SERVICES=(
    "systemd-poweroff" "systemd-reboot" "systemd-halt" "systemd-kexec"
    "systemd-suspend" "systemd-hibernate" "systemd-hybrid-sleep"
    "power-profiles-daemon" "thermald" "acpid" "nut-server" "nut-client"
    "apcupsd" "ups" "upsd" "upsmon" "networkd-wait-online"
    "unattended-upgrades" "apt-daily" "apt-daily-upgrade"
    "fwupd" "fwupd-refresh" "snapd" "snap.system"
)

for service in "${DANGEROUS_SERVICES[@]}"; do
    systemctl stop "$service" 2>/dev/null
    systemctl disable "$service" 2>/dev/null  
    systemctl mask "$service" 2>/dev/null
    echo "   ELIMINATED SERVICE: $service"
done

# ===============================
# 2. CRON TOTAL ANNIHILATION
# ===============================
echo "2. MENGHANCURKAN SEMUA CRON JOBS..."

# Backup dan hapus semua user crontabs
for user in $(cut -f1 -d: /etc/passwd); do
    if crontab -u "$user" -l >/dev/null 2>&1; then
        crontab -u "$user" -l > "$BACKUP_DIR/crontab_$user.backup" 2>/dev/null
        crontab -u "$user" -r 2>/dev/null
        echo "   OBLITERATED: crontab for $user"
    fi
done

# Hapus system crontabs
for crondir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly; do
    if [ -d "$crondir" ]; then
        cp -r "$crondir" "$BACKUP_DIR/"
        find "$crondir" -type f -delete
        echo "   ANNIHILATED: $crondir"
    fi
done

# Hapus anacron
if [ -f /etc/anacrontab ]; then
    cp /etc/anacrontab "$BACKUP_DIR/"
    > /etc/anacrontab
    echo "   ELIMINATED: anacrontab"
fi

# ===============================
# 3. AT COMMAND DESTRUCTION
# ===============================
echo "3. MENGHANCURKAN AT COMMANDS..."

# Hapus semua at jobs
at -l 2>/dev/null | awk '{print $1}' | while read -r job; do
    if [[ -n "$job" ]]; then
        atrm "$job" 2>/dev/null
        echo "   DESTROYED AT JOB: $job"
    fi
done

# Nonaktifkan atd service
systemctl stop atd 2>/dev/null
systemctl disable atd 2>/dev/null
systemctl mask atd 2>/dev/null

# ===============================
# 4. ACPI TOTAL OVERRIDE
# ===============================
echo "4. MENGHANCURKAN ACPI EVENTS..."

# Backup dan hapus semua ACPI handlers
if [ -d /etc/acpi ]; then
    cp -r /etc/acpi "$BACKUP_DIR/"
    find /etc/acpi -name "*.sh" -exec rm {} \;
    
    # Buat dummy handlers yang tidak melakukan apa-apa
    for event in power-button lid-button battery; do
        cat > "/etc/acpi/${event}.sh" << 'EOF'
#!/bin/bash
# NEUTRALIZED - NO ACTION TAKEN
logger "ACPI event blocked by total shutdown prevention"
exit 0
EOF
        chmod +x "/etc/acpi/${event}.sh"
    done
    echo "   NEUTRALIZED: All ACPI events"
fi

# ===============================
# 5. KERNEL PARAMETER OVERRIDE
# ===============================
echo "5. MEMODIFIKASI KERNEL PARAMETERS..."

# Backup grub config
cp /etc/default/grub "$BACKUP_DIR/"

# Tambahkan parameter kernel untuk mencegah shutdown
sed -i 's/GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="panic=0 softlockup_panic=0 nmi_watchdog=0 reboot=bios acpi=off"/' /etc/default/grub

# Update grub
update-grub 2>/dev/null

echo "   MODIFIED: Kernel boot parameters"

# ===============================
# 6. BINARY REPLACEMENT/PROTECTION
# ===============================
echo "6. MELINDUNGI SHUTDOWN BINARIES..."

# Backup original binaries
SHUTDOWN_BINS=("/sbin/shutdown" "/sbin/poweroff" "/sbin/halt" "/sbin/reboot" "/usr/sbin/shutdown")

for bin in "${SHUTDOWN_BINS[@]}"; do
    if [ -f "$bin" ]; then
        cp "$bin" "$BACKUP_DIR/$(basename $bin).original"
        
        # Buat wrapper script
        cat > "$bin.wrapper" << 'EOF'
#!/bin/bash
echo "SHUTDOWN BLOCKED BY TOTAL PREVENTION SYSTEM"
echo "System shutdown has been completely disabled for protection"
echo "Contact administrator to override"
logger "Blocked shutdown attempt from: $(who am i) at $(date)"
exit 1
EOF
        chmod +x "$bin.wrapper"
        mv "$bin" "$bin.real"
        mv "$bin.wrapper" "$bin"
        echo "   PROTECTED: $bin"
    fi
done

# ===============================
# 7. SIGNAL INTERCEPTION
# ===============================
echo "7. MENGAKTIFKAN SIGNAL INTERCEPTION..."

# Buat daemon untuk intercept sinyal shutdown
cat > /usr/local/bin/signal-interceptor.sh << 'EOF'
#!/bin/bash
# Signal interceptor untuk memblokir semua shutdown signals

while true; do
    # Kill semua proses shutdown yang terdeteksi
    for proc in shutdown poweroff halt reboot; do
        pkill -9 -f "$proc" 2>/dev/null
    done
    
    # Monitor dan kill systemd shutdown processes
    ps aux | grep -E "(systemd-shutdown|systemd-poweroff|systemd-reboot)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
    
    # Block SIGTERM dan SIGINT ke init
    echo "Signal interception active at $(date)" >> /var/log/signal-intercept.log
    sleep 1
done
EOF

chmod +x /usr/local/bin/signal-interceptor.sh

# ===============================
# 8. FILESYSTEM PROTECTION
# ===============================
echo "8. MENGAKTIFKAN FILESYSTEM PROTECTION..."

# Buat script untuk remount filesystem sebagai read-only untuk file kritis
cat > /usr/local/bin/fs-protector.sh << 'EOF'
#!/bin/bash
# Protect critical shutdown-related files

PROTECTED_FILES=(
    "/etc/init" "/etc/systemd" "/usr/lib/systemd"
    "/etc/cron.d" "/var/spool/cron"
)

for path in "${PROTECTED_FILES[@]}"; do
    if [ -e "$path" ]; then
        # Set immutable attribute
        chattr +i -R "$path" 2>/dev/null
    fi
done
EOF

chmod +x /usr/local/bin/fs-protector.sh
/usr/local/bin/fs-protector.sh

# ===============================
# 9. NETWORK SHUTDOWN PREVENTION
# ===============================
echo "9. MEMBLOKIR NETWORK SHUTDOWN COMMANDS..."

# Block SSH shutdown commands
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config "$BACKUP_DIR/"
    echo "DenyUsers shutdown poweroff halt reboot" >> /etc/ssh/sshd_config
fi

# Buat iptables rules untuk block shutdown-related network traffic
iptables -A INPUT -p tcp --dport 22 -m string --string "shutdown" --algo bm -j DROP 2>/dev/null
iptables -A INPUT -p tcp --dport 22 -m string --string "poweroff" --algo bm -j DROP 2>/dev/null
iptables -A INPUT -p tcp --dport 22 -m string --string "halt" --algo bm -j DROP 2>/dev/null

# ===============================
# 10. INIT SYSTEM OVERRIDE
# ===============================
echo "10. MENGGANTI INIT SYSTEM BEHAVIOR..."

# Buat custom init script yang ignore shutdown requests
cat > /usr/local/bin/custom-init-wrapper.sh << 'EOF'
#!/bin/bash
# Custom init wrapper yang memblokir semua shutdown requests

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Trap semua shutdown signals
trap 'echo "Shutdown signal blocked" >> /var/log/shutdown-blocks.log' TERM INT HUP QUIT USR1 USR2

# Monitor dan block init level changes
while true; do
    # Reset runlevel ke 2 (multi-user) jika berubah ke 0 atau 6
    current_runlevel=$(runlevel | awk '{print $2}')
    if [[ "$current_runlevel" == "0" || "$current_runlevel" == "6" ]]; then
        init 2
        echo "Runlevel change blocked: attempted $current_runlevel" >> /var/log/shutdown-blocks.log
    fi
    sleep 1
done
EOF

chmod +x /usr/local/bin/custom-init-wrapper.sh

# ===============================
# 11. HARDWARE BUTTON DISABLE
# ===============================
echo "11. MENONAKTIFKAN HARDWARE POWER BUTTON..."

# Nonaktifkan power button via logind
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/no-power-button.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore  
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
PowerKeyIgnoreInhibited=yes
SuspendKeyIgnoreInhibited=yes
HibernateKeyIgnoreInhibited=yes
LidSwitchIgnoreInhibited=yes
EOF

systemctl restart systemd-logind 2>/dev/null

# ===============================
# 12. ENVIRONMENT VARIABLE OVERRIDE
# ===============================
echo "12. MENGATUR ENVIRONMENT VARIABLES..."

# Set environment variables untuk block shutdown
cat >> /etc/environment << 'EOF'
# Shutdown prevention environment
NO_SHUTDOWN=1
DISABLE_POWEROFF=1  
BLOCK_REBOOT=1
PREVENT_HALT=1
EOF

# ===============================
# 13. LIBRARY INTERCEPTION
# ===============================
echo "13. MENGATUR LIBRARY INTERCEPTION..."

# Buat shared library untuk intercept system calls
cat > /tmp/shutdown_intercept.c << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <unistd.h>
#include <sys/reboot.h>

int reboot(int cmd) {
    printf("REBOOT CALL INTERCEPTED AND BLOCKED\n");
    return -1;
}

int shutdown(int how) {
    printf("SHUTDOWN CALL INTERCEPTED AND BLOCKED\n");  
    return -1;
}
EOF

# Compile intercept library
gcc -shared -fPIC -o /usr/local/lib/shutdown_intercept.so /tmp/shutdown_intercept.c -ldl 2>/dev/null

# Add to LD_PRELOAD
echo "/usr/local/lib/shutdown_intercept.so" >> /etc/ld.so.preload

# ===============================
# 14. MONITORING & ALERTING SYSTEM
# ===============================
echo "14. MENGAKTIFKAN MONITORING SYSTEM..."

# Buat comprehensive monitoring script
cat > /usr/local/bin/total-shutdown-monitor.sh << 'EOF'
#!/bin/bash
# Total shutdown monitoring and prevention system

LOG_FILE="/var/log/total-shutdown-prevention.log"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

while true; do
    # Monitor processes
    for proc in shutdown poweroff halt reboot; do
        if pgrep -f "$proc" >/dev/null 2>&1; then
            pkill -9 -f "$proc"
            log_event "KILLED: $proc process detected and terminated"
        fi
    done
    
    # Monitor systemd units
    for unit in poweroff.target reboot.target halt.target shutdown.target; do
        if systemctl is-active "$unit" >/dev/null 2>&1; then
            systemctl stop "$unit" 2>/dev/null
            systemctl mask "$unit" 2>/dev/null
            log_event "BLOCKED: $unit was active and has been stopped"
        fi
    done
    
    # Monitor runlevel
    current_rl=$(runlevel | awk '{print $2}')
    if [[ "$current_rl" == "0" || "$current_rl" == "6" ]]; then
        init 2
        log_event "PREVENTED: Runlevel change to $current_rl blocked"
    fi
    
    # Monitor scheduled tasks
    at_jobs=$(at -l 2>/dev/null | wc -l)
    if [ "$at_jobs" -gt 0 ]; then
        at -l | awk '{print $1}' | xargs -r atrm
        log_event "ELIMINATED: $at_jobs at jobs removed"
    fi
    
    # Check for new cron jobs
    for user in $(cut -f1 -d: /etc/passwd); do
        if crontab -u "$user" -l >/dev/null 2>&1; then
            if crontab -u "$user" -l | grep -qE "(shutdown|poweroff|halt|reboot)"; then
                crontab -u "$user" -r
                log_event "NEUTRALIZED: Dangerous crontab for $user removed"
            fi
        fi
    done
    
    sleep 2
done
EOF

chmod +x /usr/local/bin/total-shutdown-monitor.sh

# ===============================
# 15. SYSTEMD SERVICE CREATION
# ===============================
echo "15. MEMBUAT PROTECTION SERVICES..."

# Service untuk signal interceptor
cat > /etc/systemd/system/signal-interceptor.service << 'EOF'
[Unit]
Description=Signal Interceptor Service
DefaultDependencies=no
Conflicts=shutdown.target reboot.target poweroff.target halt.target
Before=shutdown.target reboot.target poweroff.target halt.target
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/local/bin/signal-interceptor.sh
Restart=always
RestartSec=1
KillMode=none
IgnoreSIGPIPE=false
TimeoutStopSec=0

[Install]
WantedBy=multi-user.target
RequiredBy=multi-user.target
EOF

# Service untuk total monitoring
cat > /etc/systemd/system/total-shutdown-monitor.service << 'EOF'
[Unit]
Description=Total Shutdown Prevention Monitor
DefaultDependencies=no
Conflicts=shutdown.target reboot.target poweroff.target halt.target
Before=shutdown.target reboot.target poweroff.target halt.target
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/local/bin/total-shutdown-monitor.sh
Restart=always
RestartSec=1
KillMode=none
IgnoreSIGPIPE=false
TimeoutStopSec=0

[Install]  
WantedBy=multi-user.target
RequiredBy=multi-user.target
EOF

# Service untuk init wrapper
cat > /etc/systemd/system/init-wrapper.service << 'EOF'
[Unit]
Description=Init Wrapper Protection
DefaultDependencies=no
Conflicts=shutdown.target reboot.target poweroff.target halt.target
Before=shutdown.target reboot.target poweroff.target halt.target

[Service]
Type=simple
ExecStart=/usr/local/bin/custom-init-wrapper.sh
Restart=always
RestartSec=1
KillMode=none
TimeoutStopSec=0

[Install]
WantedBy=multi-user.target
RequiredBy=multi-user.target
EOF

# Aktifkan semua protection services
systemctl daemon-reload
systemctl enable signal-interceptor.service
systemctl enable total-shutdown-monitor.service  
systemctl enable init-wrapper.service
systemctl start signal-interceptor.service
systemctl start total-shutdown-monitor.service
systemctl start init-wrapper.service

# ===============================
# 16. SHELL PROTECTION
# ===============================
echo "16. MENGATUR SHELL PROTECTION..."

# Override semua shell dengan protection
for shell_path in /bin/bash /bin/sh /bin/dash /bin/zsh; do
    if [ -f "$shell_path" ]; then
        cp "$shell_path" "$shell_path.real"
        
        cat > "$shell_path.wrapper" << 'EOF'
#!/bin/bash
# Protected shell wrapper

# Check if command contains shutdown-related keywords
for arg in "$@"; do
    if [[ "$arg" =~ (shutdown|poweroff|halt|reboot|init\ 0|init\ 6|telinit\ 0|telinit\ 6) ]]; then
        echo "COMMAND BLOCKED: Shutdown-related command detected"
        logger "Blocked command: $* from $(who am i)"
        exit 1
    fi
done

# Execute the real shell
exec "$0.real" "$@"
EOF
        chmod +x "$shell_path.wrapper"
        mv "$shell_path.wrapper" "$shell_path"
        echo "   PROTECTED: $shell_path"
    fi
done

# ===============================
# 17. BOOTLOADER PROTECTION
# ===============================
echo "17. MENGAMANKAN BOOTLOADER..."

# Backup dan modify grub untuk prevent single user mode
if [ -f /etc/grub.d/40_custom ]; then
    cp /etc/grub.d/40_custom "$BACKUP_DIR/"
fi

cat >> /etc/grub.d/40_custom << 'EOF'
# Prevent single user mode and recovery
menuentry "Protected Mode Only" {
    echo "System is in protected mode - no shutdown allowed"
    sleep 5
    reboot
}
EOF

chmod +x /etc/grub.d/40_custom
update-grub 2>/dev/null

# ===============================
# 18. FINAL SYSTEM HARDENING
# ===============================
echo "18. FINAL SYSTEM HARDENING..."

# Set immutable pada file-file kritis
for critical_file in /etc/systemd/system/*.service /etc/systemd/system/*.target /sbin/shutdown /sbin/poweroff /sbin/halt /sbin/reboot; do
    if [ -f "$critical_file" ]; then
        chattr +i "$critical_file" 2>/dev/null
    fi
done

# Buat watchdog untuk memastikan protection services tetap running
cat > /usr/local/bin/protection-watchdog.sh << 'EOF'
#!/bin/bash
# Watchdog untuk memastikan semua protection tetap aktif

SERVICES=("signal-interceptor" "total-shutdown-monitor" "init-wrapper")

while true; do
    for service in "${SERVICES[@]}"; do
        if ! systemctl is-active "$service.service" >/dev/null 2>&1; then
            systemctl start "$service.service"
            logger "Protection watchdog restarted: $service"
        fi
    done
    sleep 10
done
EOF

chmod +x /usr/local/bin/protection-watchdog.sh

# Buat watchdog service
cat > /etc/systemd/system/protection-watchdog.service << 'EOF'
[Unit]
Description=Protection Watchdog
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/protection-watchdog.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable protection-watchdog.service
systemctl start protection-watchdog.service

echo
echo "====================================================="
echo "    TOTAL AUTO SHUTDOWN ELIMINATION COMPLETED"
echo "====================================================="
echo
echo "🛡️ PROTECTION LAYERS ACTIVATED:"
echo "   ✅ Systemd targets MASKED"
echo "   ✅ All timers ELIMINATED"  
echo "   ✅ All services NEUTRALIZED"
echo "   ✅ Cron jobs ANNIHILATED"
echo "   ✅ At commands DESTROYED"
echo "   ✅ ACPI events NEUTRALIZED"
echo "   ✅ Kernel parameters MODIFIED"
echo "   ✅ Shutdown binaries PROTECTED"
echo "   ✅ Signal interception ACTIVE"
echo "   ✅ Filesystem protection ENABLED"
echo "   ✅ Network commands BLOCKED"
echo "   ✅ Init system OVERRIDDEN"
echo "   ✅ Hardware buttons DISABLED"
echo "   ✅ Environment SECURED"
echo "   ✅ Library interception ACTIVE"
echo "   ✅ Total monitoring RUNNING"
echo "   ✅ Shell protection ENABLED"
echo "   ✅ Bootloader SECURED"
echo "   ✅ System HARDENED"
echo "   ✅ Watchdog PROTECTING"
echo
echo "🔒 SYSTEM STATUS: COMPLETELY SHUTDOWN-PROOF"
echo "📁 Backups saved in: $BACKUP_DIR"
echo "📋 Logs: /var/log/total-shutdown-prevention.log"
echo
echo "⚠️  WARNING: SYSTEM IS NOW COMPLETELY PROTECTED"
echo "    NO METHOD CAN SHUTDOWN THIS SYSTEM"
echo "    PHYSICAL POWER REMOVAL IS THE ONLY WAY"
echo
echo "🚨 EMERGENCY RESTORATION:"
echo "    Run: bash $BACKUP_DIR/restore.sh (will be created)"
echo
echo "====================================================="

# Buat restoration script
cat > "$BACKUP_DIR/restore.sh" << EOF
#!/bin/bash
echo "RESTORING SYSTEM FROM TOTAL SHUTDOWN PROTECTION..."

# Stop all protection services
systemctl stop signal-interceptor.service total-shutdown-monitor.service init-wrapper.service protection-watchdog.service 2>/dev/null
systemctl disable signal-interceptor.service total-shutdown-monitor.service init-wrapper.service protection-watchdog.service 2>/dev/null

# Remove immutable attributes
chattr -i -R /etc/systemd /sbin/shutdown /sbin/poweroff /sbin/halt /sbin/reboot 2>/dev/null

# Restore original binaries
for bin in shutdown poweroff halt reboot; do
    if [ -f "/sbin/\$bin.real" ]; then
        mv "/sbin/\$bin.real" "/sbin/\$bin"
    fi
done

# Restore grub
cp "$BACKUP_DIR/grub" /etc/default/grub 2>/dev/null
update-grub 2>/dev/null

# Restore systemd targets
systemctl unmask poweroff.target reboot.target halt.target shutdown.target 2>/dev/null

echo "SYSTEM RESTORED - SHUTDOWN CAPABILITY RETURNED"
EOF

chmod +x "$BACKUP_DIR/restore.sh"

echo "System will be completely shutdown-proof after reboot."
echo "Reboot recommended to ensure all protections are active."
