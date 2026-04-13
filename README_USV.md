# Online USV Xanto 1500R – Raspberry Pi Skript

> **Sprache / Language:** [Deutsch](#deutsch) | [English](#english)

---

## Deutsch

### Überblick

`usv_xanto_rpi.sh` ist ein Shell-Skript für den Raspberry Pi (Raspberry Pi OS / Debian-basiert), das mithilfe von **NUT (Network UPS Tools)** die USV
[Online USV Xanto 1500R](https://www.online-usv.de/produkte/19-usv-xanto-1500r) überwacht und das System bei Stromausfall automatisch herunterfährt.

### Voraussetzungen

| Anforderung | Detail |
|---|---|
| Betriebssystem | Raspberry Pi OS (Bullseye / Bookworm) oder ein anderes Debian-/Ubuntu-basiertes System |
| Rechte | Root-Zugriff (`sudo`) |
| Verbindung | USB-Kabel zwischen dem Raspberry Pi und dem USB-Port der Xanto 1500R |

### Installation & Erstkonfiguration

```bash
# 1. Skript ausführbar machen
chmod +x usv_xanto_rpi.sh

# 2. NUT installieren und Konfiguration schreiben
sudo bash usv_xanto_rpi.sh install
```

> **Passwörter ändern!**  
> Nach dem `install`-Schritt müssen die Standard-Passwörter in den folgenden Dateien geändert werden, bevor der Dienst gestartet wird:
> - `/etc/nut/upsd.users` → `admin_secret` und `upsmon_secret`
> - `/etc/nut/upsmon.conf` → `upsmon_secret`

### Befehle

| Befehl | Beschreibung |
|---|---|
| `sudo bash usv_xanto_rpi.sh install` | NUT installieren und für die Xanto 1500R konfigurieren |
| `sudo bash usv_xanto_rpi.sh start` | USV-Überwachung starten |
| `sudo bash usv_xanto_rpi.sh stop` | USV-Überwachung stoppen |
| `sudo bash usv_xanto_rpi.sh status` | Status der Dienste und USV-Variablen anzeigen |
| `sudo bash usv_xanto_rpi.sh test` | Notabschaltung (FSD) simulieren |
| `sudo bash usv_xanto_rpi.sh uninstall` | Konfigurationsdateien entfernen |

### Automatischer Start beim Booten

Die Dienste werden durch `install` + `start` automatisch in systemd aktiviert (`enable`).  
Sie starten damit nach jedem Neustart des Raspberry Pi selbstständig.

### Abschaltverhalten

Wenn die Batterie unter **30 %** Ladestand sinkt, sendet NUT den Befehl `shutdown -h now` an das System.  
Die Schwelle kann im Skript über die Variable `SHUTDOWNLEVEL` angepasst werden.

### Manuelle Abfrage der USV-Werte

```bash
upsc xanto1500r@localhost
```

---

## English

### Overview

`usv_xanto_rpi.sh` is a Raspberry Pi shell script that uses **NUT (Network UPS Tools)** to monitor the
[Online USV Xanto 1500R](https://www.online-usv.de/produkte/19-usv-xanto-1500r) UPS and automatically shut down the system on power loss.

### Requirements

| Requirement | Detail |
|---|---|
| OS | Raspberry Pi OS (Bullseye / Bookworm) or any Debian/Ubuntu-based system |
| Privileges | Root access (`sudo`) |
| Connection | USB cable between the Raspberry Pi and the Xanto 1500R USB port |

### Installation & Initial Setup

```bash
# 1. Make the script executable
chmod +x usv_xanto_rpi.sh

# 2. Install NUT and write configuration files
sudo bash usv_xanto_rpi.sh install
```

> **Change the passwords!**  
> After the `install` step, update the default passwords before starting the service:
> - `/etc/nut/upsd.users` → `admin_secret` and `upsmon_secret`
> - `/etc/nut/upsmon.conf` → `upsmon_secret`

### Commands

| Command | Description |
|---|---|
| `sudo bash usv_xanto_rpi.sh install` | Install NUT and configure it for the Xanto 1500R |
| `sudo bash usv_xanto_rpi.sh start` | Start UPS monitoring services |
| `sudo bash usv_xanto_rpi.sh stop` | Stop UPS monitoring services |
| `sudo bash usv_xanto_rpi.sh status` | Show service and UPS variable status |
| `sudo bash usv_xanto_rpi.sh test` | Simulate a forced shutdown (FSD) |
| `sudo bash usv_xanto_rpi.sh uninstall` | Remove NUT configuration files |

### Autostart on Boot

Running `install` + `start` enables the NUT systemd services so they start automatically on every reboot.

### Shutdown Behaviour

When the battery charge drops below **30 %**, NUT issues `shutdown -h now`.  
Adjust the threshold via the `SHUTDOWNLEVEL` variable at the top of the script.

### Manually Querying UPS Data

```bash
upsc xanto1500r@localhost
```

---

&copy; 2025 – [MIT License](LICENSE)
