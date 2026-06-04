# STERNTOOLS v1.3

Digital Forensics & Penetration Testing Toolkit — untuk CTF, incident response, dan Boot2Root.

## Quick Start

```bash
cd ~/sterntools
bash install.sh        # Install semua dependencies (1x)
./sterntools.sh        # Jalankan menu utama
```

## Struktur

```
sterntools/
├── sterntools.sh      ← Menu utama
├── install.sh         ← Auto-installer dependencies
├── modules/           ← 9 modul forensics
├── plugins/           ← Plugin tambahan (auto-detect)
├── cases/             ← Case management (pisah tiap CTF)
│   ├── ctf_2025_01/
│   │   ├── input/
│   │   ├── output/
│   │   ├── logs/
│   │   ├── reports/
│   │   └── notes.txt
│   └── htb_machine/
├── README.md
└── HANDBOOK.md
```

## Menu

| Key | Modul | Fase |
|-----|-------|------|
| 1 | Recon & OSINT | ATTACK |
| 2 | Web Vuln Scanner + Reverse Shell | ATTACK |
| 3 | Linux Privesc Triage | ATTACK |
| 4 | File Forensics | FORENSICS |
| 5 | Memory Forensics (Volatility 3) | FORENSICS |
| 6 | Network Forensics (tshark) | FORENSICS |
| 7 | Log Forensics | FORENSICS |
| 8 | Build Master Timeline | REPORTS |
| 9 | Export All Reports | REPORTS |
| p1..pn | Auto-loaded dari plugins/ | PLUGINS |
| C | Create New Case | SYSTEM |
| S | Switch Case | SYSTEM |
| N | Edit Case Notes | SYSTEM |

## Fitur Baru v1.3

- **Case Management:** Setiap CTF punya folder sendiri di `cases/`. Input/output/logs/reports otomatis terisolasi.
- **Plugin System:** Taruh `.sh` file di `plugins/` dengan format `PLUGIN_NAME` + `plugin_main()`. Auto-detect, auto-masuk menu.
- **Dependency Checker:** Otomatis ngecek tools yang belum terinstall pas startup.
- **Auto Installer:** `bash install.sh` — install semua dependencies dalam 1 command.

## Buat Plugin Sendiri

```bash
# plugins/example_plugin.sh
PLUGIN_NAME="Nama Plugin"
PLUGIN_DESC="Deskripsi"

plugin_main() {
    echo "Plugin aku jalan!"
    # kode kamu di sini
    read -p "[Enter] kembali..."
}
```

## Dependencies

```bash
bash install.sh
```
