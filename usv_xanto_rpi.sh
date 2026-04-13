#!/usr/bin/env bash
# =============================================================================
# usv_xanto_rpi.sh
# Raspberry Pi – Start / Shutdown Script for
#   Online USV Xanto 1500R (online-usv.de)
#
# Depends on: NUT (Network UPS Tools)  –  https://networkupstools.org/
# Compatible OS: Raspberry Pi OS (Debian/Ubuntu-based)
#
# Usage:
#   sudo bash usv_xanto_rpi.sh install   # Install & configure NUT
#   sudo bash usv_xanto_rpi.sh start     # Start UPS monitoring
#   sudo bash usv_xanto_rpi.sh stop      # Stop UPS monitoring
#   sudo bash usv_xanto_rpi.sh status    # Show UPS status
#   sudo bash usv_xanto_rpi.sh test      # Trigger test shutdown sequence
#   sudo bash usv_xanto_rpi.sh uninstall # Remove NUT configuration
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
UPS_NAME="xanto1500r"
UPS_DRIVER="usbhid-ups"          # HID-USB driver, works with Xanto 1500R
UPS_PORT="auto"                  # Let NUT find the USB device automatically
UPS_DESC="Online USV Xanto 1500R"

NUT_CONF="/etc/nut/nut.conf"
UPS_CONF="/etc/nut/ups.conf"
UPSD_CONF="/etc/nut/upsd.conf"
UPSD_USERS="/etc/nut/upsd.users"
UPSMON_CONF="/etc/nut/upsmon.conf"

MONITOR_USER="upsmon"
MONITOR_PASS="upsmon_secret"     # MUST be changed before starting the service!
ADMIN_USER="admin"
ADMIN_PASS="admin_secret"        # MUST be changed before starting the service!

# Shutdown when battery charge drops below this percentage.
# Written to ups.conf as override.battery.charge.low so the usbhid-ups driver
# reports "low battery" at this level, which triggers upsmon's FSD sequence.
SHUTDOWNLEVEL=30

# Warn upsmon after this many seconds of continuous battery operation (0 = disable).
# When non-zero this sets the ONBATTERYTIME directive in upsmon.conf.
ONBATTERYTIME=0
# =============================================================================

# ── Helper functions ──────────────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."
}

require_nut() {
    command -v upsc &>/dev/null || die "NUT is not installed. Run: sudo bash $0 install"
}

# ── Guard: refuse to start with default passwords ────────────────────────────
check_default_passwords() {
    local passwords_changed=true
    if grep -q "upsmon_secret\|admin_secret" "$UPSD_USERS" 2>/dev/null; then
        passwords_changed=false
    fi
    if grep -q "upsmon_secret" "$UPSMON_CONF" 2>/dev/null; then
        passwords_changed=false
    fi
    if [[ "$passwords_changed" == "false" ]]; then
        die "Default passwords are still in use!
Please update the passwords in:
  $UPSD_USERS   (replace 'admin_secret' and 'upsmon_secret')
  $UPSMON_CONF  (replace 'upsmon_secret')
Then run: sudo bash $0 start"
    fi
}

# ── Install & configure NUT ───────────────────────────────────────────────────
cmd_install() {
    require_root
    log "Updating package list …"
    apt-get update -qq

    log "Installing NUT packages …"
    apt-get install -y nut nut-client nut-server

    log "Writing NUT configuration files …"

    # /etc/nut/nut.conf – operating mode
    cat > "$NUT_CONF" <<EOF
# NUT operating mode
MODE=standalone
EOF

    # /etc/nut/ups.conf – UPS driver definition
    cat > "$UPS_CONF" <<EOF
# Online USV Xanto 1500R
[$UPS_NAME]
    driver  = $UPS_DRIVER
    port    = $UPS_PORT
    desc    = "$UPS_DESC"
    # Polling interval in seconds (default: 2)
    pollinterval = 2
    # Override the battery low-charge threshold reported to upsmon.
    # When battery.charge drops to or below this value the driver signals
    # "low battery", causing upsmon to initiate a forced shutdown (FSD).
    override.battery.charge.low = $SHUTDOWNLEVEL
EOF

    # /etc/nut/upsd.conf – network daemon settings (localhost only)
    cat > "$UPSD_CONF" <<EOF
LISTEN 127.0.0.1 3493
LISTEN ::1 3493
EOF

    # /etc/nut/upsd.users – user accounts
    cat > "$UPSD_USERS" <<EOF
[$ADMIN_USER]
    password  = $ADMIN_PASS
    actions   = SET
    instcmds  = ALL

[$MONITOR_USER]
    password  = $MONITOR_PASS
    upsmon    = primary
EOF

    # /etc/nut/upsmon.conf – monitoring & shutdown rules
    cat > "$UPSMON_CONF" <<EOF
# Monitor the UPS (primary = this machine is directly connected)
MONITOR ${UPS_NAME}@localhost 1 ${MONITOR_USER} ${MONITOR_PASS} primary

# Minimum number of power supplies that must be online to avoid shutdown
MINSUPPLIES 1

# Command executed to shut down the system
SHUTDOWNCMD "/sbin/shutdown -h now"

# Notify settings (log + wall message)
NOTIFYCMD /sbin/upssched
NOTIFYMSG ONLINE    "UPS %s: Netzspannung wiederhergestellt (power restored)"
NOTIFYMSG ONBATT    "UPS %s: Batteriebetrieb gestartet (on battery power)"
NOTIFYMSG LOWBATT   "UPS %s: Batterie schwach – Herunterfahren (low battery – shutting down)"
NOTIFYMSG FSD       "UPS %s: Forced shutdown in progress"
NOTIFYMSG COMMOK    "UPS %s: Kommunikation hergestellt (communication established)"
NOTIFYMSG COMMBAD   "UPS %s: Kommunikationsfehler (communication lost)"
NOTIFYMSG SHUTDOWN  "Auto-Abschaltung wird ausgeführt (auto shutdown executing)"
NOTIFYMSG REPLBATT  "UPS %s: Batterie austauschen (replace battery)"
NOTIFYMSG NOCOMM    "UPS %s: Nicht erreichbar (not reachable)"
NOTIFYMSG NOPARENT  "upsmon parent process died – shutdown impossible"

NOTIFYFLAG ONLINE   SYSLOG+WALL
NOTIFYFLAG ONBATT   SYSLOG+WALL
NOTIFYFLAG LOWBATT  SYSLOG+WALL
NOTIFYFLAG FSD      SYSLOG+WALL
NOTIFYFLAG COMMOK   SYSLOG
NOTIFYFLAG COMMBAD  SYSLOG+WALL
NOTIFYFLAG SHUTDOWN SYSLOG+WALL
NOTIFYFLAG REPLBATT SYSLOG+WALL
NOTIFYFLAG NOCOMM   SYSLOG+WALL
NOTIFYFLAG NOPARENT SYSLOG+WALL

# Polling frequency (seconds)
POLLFREQ 5
POLLFREQALERT 5

# Grace period before shutdown (seconds)
HOSTSYNC 15
DEADTIME 15

# How often (seconds) to warn about a battery that needs replacement.
# RBWARNTIME is not a charge % threshold; it controls how frequently the
# REPLBATT notification is repeated (default: 43200 s = 12 hours).
RBWARNTIME 43200
# Warn once per 5 minutes when the UPS is unreachable
NOCOMMWARNTIME 300

POWERDOWNFLAG /etc/killpower
EOF

    # Append ONBATTERYTIME only when explicitly requested (non-zero)
    if [[ "$ONBATTERYTIME" -gt 0 ]]; then
        echo "# Initiate shutdown after this many seconds on battery power" >> "$UPSMON_CONF"
        echo "ONBATTERYTIME $ONBATTERYTIME"                                  >> "$UPSMON_CONF"
    fi

    # Fix permissions
    chown root:nut "$NUT_CONF" "$UPS_CONF" "$UPSD_CONF" "$UPSD_USERS" "$UPSMON_CONF"
    chmod 640       "$NUT_CONF" "$UPS_CONF" "$UPSD_CONF" "$UPSD_USERS" "$UPSMON_CONF"

    # Add nut user to dialout group for USB access (some systems need it)
    usermod -aG dialout nut 2>/dev/null || true

    log "NUT configuration written."
    log ""
    log "*** IMPORTANT ***"
    log "Before starting the service, change the default passwords in:"
    log "  $UPSD_USERS  (ADMIN_PASS, MONITOR_PASS)"
    log "  $UPSMON_CONF (MONITOR_PASS)"
    log "Then run:  sudo bash $0 start"
}

# ── Start monitoring ──────────────────────────────────────────────────────────
cmd_start() {
    require_root
    require_nut
    check_default_passwords
    log "Starting NUT driver …"
    systemctl enable nut-driver.service 2>/dev/null || true
    systemctl start  nut-driver.service

    log "Starting NUT server (upsd) …"
    systemctl enable nut-server.service 2>/dev/null || true
    systemctl start  nut-server.service

    log "Starting UPS monitor (upsmon) …"
    systemctl enable nut-monitor.service 2>/dev/null || true
    systemctl start  nut-monitor.service

    log "UPS monitoring is active."
    cmd_status
}

# ── Stop monitoring ───────────────────────────────────────────────────────────
cmd_stop() {
    require_root
    require_nut
    log "Stopping UPS monitor …"
    systemctl stop nut-monitor.service 2>/dev/null || true

    log "Stopping NUT server …"
    systemctl stop nut-server.service 2>/dev/null || true

    log "Stopping NUT driver …"
    systemctl stop nut-driver.service 2>/dev/null || true

    log "UPS monitoring stopped."
}

# ── Status ────────────────────────────────────────────────────────────────────
cmd_status() {
    require_nut
    log "=== NUT service status ==="
    for svc in nut-driver nut-server nut-monitor; do
        echo -n "  $svc: "
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            echo "running"
        else
            echo "stopped"
        fi
    done
    echo ""
    log "=== UPS variables (upsc) ==="
    upsc "${UPS_NAME}@localhost" 2>/dev/null || warn "Could not query UPS – is monitoring running?"
}

# ── Test shutdown ─────────────────────────────────────────────────────────────
cmd_test() {
    require_root
    require_nut
    warn "Simulating low-battery shutdown in 10 seconds …"
    warn "Press Ctrl-C within 10 seconds to abort."
    sleep 10
    log "Sending forced-shutdown (FSD) signal to upsmon …"
    upsmon -c fsd || die "Failed to send FSD signal. Is upsmon running?"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────
cmd_uninstall() {
    require_root
    warn "Removing NUT configuration …"
    cmd_stop 2>/dev/null || true
    for f in "$NUT_CONF" "$UPS_CONF" "$UPSD_CONF" "$UPSD_USERS" "$UPSMON_CONF"; do
        [[ -f "$f" ]] && rm -f "$f" && log "Removed $f"
    done
    log "Done. NUT packages are still installed. To remove them:"
    log "  sudo apt-get remove --purge nut nut-client nut-server"
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-help}" in
    install)   cmd_install   ;;
    start)     cmd_start     ;;
    stop)      cmd_stop      ;;
    status)    cmd_status    ;;
    test)      cmd_test      ;;
    uninstall) cmd_uninstall ;;
    *)
        echo "Online USV Xanto 1500R – Raspberry Pi Management Script"
        echo ""
        echo "Usage: sudo bash $0 <command>"
        echo ""
        echo "Commands:"
        echo "  install    Install & configure NUT for the Xanto 1500R"
        echo "  start      Start UPS monitoring services"
        echo "  stop       Stop UPS monitoring services"
        echo "  status     Show current UPS and service status"
        echo "  test       Simulate low-battery / forced-shutdown (FSD)"
        echo "  uninstall  Remove NUT configuration files"
        ;;
esac
