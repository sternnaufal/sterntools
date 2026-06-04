#!/bin/bash

OUTPUT_DIR="${1:-privesc_triage_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/privesc.log"

exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║    LINUX PRIVILEGE ESCALATION TRIAGE    ║"
echo "  ║         stern-privesc v1.0              ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}[*] Running on:${NC} $(uname -a)"
echo -e "${YELLOW}[*] User:${NC} $(whoami) (uid: $(id -u))"
echo -e "${YELLOW}[*] Hostname:${NC} $(hostname)"
echo -e "${YELLOW}[*] Output:${NC} $OUTPUT_DIR/"
echo ""

echo -e "${WHITE}  ┌──────────────────────────────────────────────┐${NC}"
echo -e "${WHITE}  │${NC}  Jalankan skrip ini DI SERVER TARGET       ${WHITE}  │${NC}"
echo -e "${WHITE}  │${NC}  Download via: wget/curl ke target        ${WHITE}  │${NC}"
echo -e "${WHITE}  └──────────────────────────────────────────────┘${NC}"
echo ""

# ──────────────────────────────────────────────
# 1. SYSTEM INFO
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  1. SYSTEM INFORMATION                   ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

SYS_FILE="$OUTPUT_DIR/system_info.txt"
{
    echo "=== KERNEL ==="
    uname -a
    echo ""
    echo "=== OS RELEASE ==="
    cat /etc/os-release 2>/dev/null || cat /etc/*release 2>/dev/null
    echo ""
    echo "=== ENV ==="
    env | sort
    echo ""
    echo "=== PATH ==="
    echo "$PATH"
} > "$SYS_FILE"

echo -e "  ${GREEN}[+]${NC} System info   -> $SYS_FILE"

# Kernel exploit suggester (CVE lookup based on uname)
KERNEL_VER=$(uname -r)
echo -e "  ${YELLOW}[i]${NC} Kernel version: $KERNEL_VER"
echo -e "  ${YELLOW}[i]${NC} Check https://exploit-db.com for kernel exploits"
echo ""

# ──────────────────────────────────────────────
# 2. SUID / SGID FINDER
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  2. SUID / SGID BINARIES                ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

SUID_FILE="$OUTPUT_DIR/suid_binaries.txt"
{
    echo "=== SUID (setuid) binaries ==="
    find / -perm -4000 -type f 2>/dev/null
    echo ""
    echo "=== SGID (setgid) binaries ==="
    find / -perm -2000 -type f 2>/dev/null
} > "$SUID_FILE"

SUID_COUNT=$(wc -l < "$SUID_FILE")
echo -e "  ${GREEN}[+]${NC} SUID/SGID list -> $SUID_FILE"

# Highlight well-known exploitable SUID binaries
echo -e "  ${YELLOW}[i]${NC} Check for exploitable SUIDs:"
for bin in nmap vim find nano less more cp mv python perl ruby bash sh vi php awk xauth; do
    if grep -q "$bin" "$SUID_FILE" 2>/dev/null; then
        echo -e "    ${RED}[!] $bin${NC} - Potentially exploitable SUID!"
    fi
done
echo ""

# ──────────────────────────────────────────────
# 3. WRITABLE FILES & DIRECTORIES
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  3. WRITABLE FILES (privilege escalation) ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

WRITABLE_FILE="$OUTPUT_DIR/writable_interesting.txt"
{
    echo "=== Writable /etc/passwd? ==="
    ls -la /etc/passwd 2>/dev/null
    test -w /etc/passwd && echo "*** /etc/passwd IS WRITABLE! ***"
    echo ""
    echo "=== Writable /etc/shadow? ==="
    ls -la /etc/shadow 2>/dev/null
    test -w /etc/shadow && echo "*** /etc/shadow IS WRITABLE! ***"
    echo ""
    echo "=== Writable /etc/sudoers? ==="
    ls -la /etc/sudoers 2>/dev/null
    test -w /etc/sudoers && echo "*** /etc/sudoers IS WRITABLE! ***"
    echo ""
    echo "=== Writable crontabs ==="
    find /etc/cron* -writable -type f 2>/dev/null
    find /var/spool/cron -writable -type f 2>/dev/null
    echo ""
    echo "=== Writable systemd timers/services ==="
    find /etc/systemd -writable -type f 2>/dev/null
    echo ""
    echo "=== Writable scripts in PATH ==="
    IFS=:
    for dir in $PATH; do
        find "$dir" -writable -type f 2>/dev/null
    done
} > "$WRITABLE_FILE"

echo -e "  ${GREEN}[+]${NC} Writable files -> $WRITABLE_FILE"
echo ""

# ──────────────────────────────────────────────
# 4. SUDO RIGHTS
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  4. SUDO PRIVILEGES                      ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

SUDO_FILE="$OUTPUT_DIR/sudo_privileges.txt"
sudo -l 2>/dev/null > "$SUDO_FILE" || echo "User cannot run sudo" > "$SUDO_FILE"

echo -e "  ${GREEN}[+]${NC} Sudo rights   -> $SUDO_FILE"

if grep -q "ALL" "$SUDO_FILE" 2>/dev/null; then
    echo -e "  ${RED}[!!!] USER CAN RUN ALL COMMANDS AS ROOT!${NC}"
    echo -e "  ${RED}       sudo su -${NC}"
fi
echo ""

# ──────────────────────────────────────────────
# 5. CRONJOBS
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  5. CRONJOBS & SCHEDULED TASKS           ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

CRON_FILE="$OUTPUT_DIR/cronjobs.txt"
{
    echo "=== /etc/crontab ==="
    cat /etc/crontab 2>/dev/null
    echo ""
    echo "=== /etc/cron.d/ ==="
    ls -la /etc/cron.d/ 2>/dev/null
    cat /etc/cron.d/* 2>/dev/null
    echo ""
    echo "=== User crontabs ==="
    ls -la /var/spool/cron/crontabs/ 2>/dev/null
} > "$CRON_FILE"

echo -e "  ${GREEN}[+]${NC} Cronjobs      -> $CRON_FILE"
echo ""

# ──────────────────────────────────────────────
# 6. INTERESTING FILES
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  6. INTERESTING FILES & CREDENTIALS      ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

INT_FILE="$OUTPUT_DIR/interesting_files.txt"
{
    echo "=== History files ==="
    find /home -name ".bash_history" -type f 2>/dev/null
    find /root -name ".bash_history" -type f 2>/dev/null
    echo ""
    echo "=== SSH keys ==="
    find /home -name "id_rsa" -o -name "id_ed25519" -o -name "authorized_keys" 2>/dev/null
    find /root -name "id_rsa" -o -name "id_ed25519" -o -name "authorized_keys" 2>/dev/null
    echo ""
    echo "=== Config files with passwords ==="
    grep -rli "password\|secret\|key" /etc/ 2>/dev/null | head -20
    echo ""
    echo "=== Database configs ==="
    find / -name "wp-config.php" -type f 2>/dev/null
    find / -name "config.php" -type f 2>/dev/null
    find / -name ".env" -type f 2>/dev/null
    echo ""
    echo "=== Backup files ==="
    find / -name "*.bak" -o -name "*.backup" -o -name "*.old" -type f 2>/dev/null | head -20
} > "$INT_FILE"

echo -e "  ${GREEN}[+]${NC} Interesting   -> $INT_FILE"
echo ""

# ──────────────────────────────────────────────
# 7. LINUX CAPABILITIES
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  7. LINUX CAPABILITIES                   ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

CAP_FILE="$OUTPUT_DIR/capabilities.txt"
getcap -r / 2>/dev/null > "$CAP_FILE" || echo "getcap not available" > "$CAP_FILE"
echo -e "  ${GREEN}[+]${NC} Capabilities  -> $CAP_FILE"
if grep -qi "cap_setuid\|cap_sys_admin\|cap_dac_override" "$CAP_FILE" 2>/dev/null; then
    echo -e "  ${RED}[!]${NC} Interesting capabilities found!"
fi
echo ""

# ──────────────────────────────────────────────
# QUICK FIND: world-writable directories
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  8. WORLD-WRITABLE DIRECTORIES           ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

WW_DIRS="$OUTPUT_DIR/world_writable_dirs.txt"
find / -type d -perm -o+w 2>/dev/null | grep -v proc | grep -v sys > "$WW_DIRS"
echo -e "  ${GREEN}[+]${NC} World-writable dirs -> $WW_DIRS"
echo ""

# ──────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  PRIVESC TRIAGE COMPLETE                 ${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

echo -e "${WHITE}  QUICK CHECKS:${NC}"
echo "  ┌────────────────────────────────────────────────────┐"
echo "  │ CHECK                                        │ STATUS │"
echo "  ├────────────────────────────────────────────────────┤"

# Kernel vuln check
echo -e "  │ Kernel: $(uname -r | cut -c1-30)                          │"

# SUID count
echo -e "  │ SUID binaries found: $(grep -c '.' "$SUID_FILE" 2>/dev/null || echo 0)                          │"

# Sudo check
if grep -q "ALL" "$SUDO_FILE" 2>/dev/null; then
    echo -e "  │ ${RED}sudo: ALL ACCESS (root me!)${NC}                 │"
elif grep -qv "cannot run sudo" "$SUDO_FILE" 2>/dev/null; then
    echo -e "  │ ${GREEN}sudo: restricted commands available${NC}             │"
else
    echo -e "  │ sudo: no access                                        │"
fi

# /etc/passwd writable
if [ -w /etc/passwd ] 2>/dev/null; then
    echo -e "  │ ${RED}/etc/passwd is WRITABLE!${NC}                             │"
fi

# Cron writable
if grep -q . "$OUTPUT_DIR/writable_interesting.txt" 2>/dev/null && grep -q "cron" "$OUTPUT_DIR/writable_interesting.txt" 2>/dev/null; then
    echo -e "  │ ${RED}Writable cron files found!${NC}                           │"
fi

echo "  └────────────────────────────────────────────────────┘"
echo ""
echo -e "${CYAN}[>] All results saved to: $OUTPUT_DIR/${NC}"
echo -e "${CYAN}[>] To copy back to host: tar czf privesc.tar.gz $OUTPUT_DIR/${NC}"
echo ""
echo -e "${YELLOW}[*] Recommended GTFOBins lookup:${NC}"
echo "    https://gtfobins.github.io"
