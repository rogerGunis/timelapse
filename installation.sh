#!/usr/bin/env bash
# install_sec_cam.sh
# Non-interaktives Installationsskript für Termux (installiert Abhängigkeiten + SecCam.py)
# Ziel: keine Benutzerinteraktion (-y / --no-input wo möglich)
set -euo pipefail

# Hilfsfunktionen
echoinfo(){ printf "\n[INFO] %s\n" "$*"; }
echowarn(){ printf "\n[WARN] %s\n" "$*"; }
echoerr(){ printf "\n[ERROR] %s\n" "$*" >&2; }

# Prüfen ob in Termux (PREFIX ist in Termux gesetzt)
if [ -z "${PREFIX:-}" ]; then
  echowarn "Es scheint nicht, dass dieses Script in Termux läuft. Fortfahren, aber Ergebnisse sind nicht garantiert."
fi

echoinfo "Update Paketlisten..."
# Debian/termux kompatibel: bevorzugt pkg (Termux)
if command -v pkg >/dev/null 2>&1; then
  PKG_CMD="pkg"
elif command -v apt >/dev/null 2>&1; then
  PKG_CMD="apt"
else
  echoerr "Kein Paketmanager gefunden (pkg/apt). Abbruch."
  exit 1
fi

# Non-interaktive Paketinstallation (Termux: pkg benutzt -y)
echoinfo "Installiere Systempakete (python, ffmpeg, curl, git, clang, make, libjpeg-turbo, termux-exec, termux-api)..."
if [ "$PKG_CMD" = "pkg" ]; then
  pkg update -y || true
  pkg upgrade -y || true
  pkg install -y python ffmpeg curl git clang make libjpeg-turbo termux-exec termux-api python-numpy || true
else
  # apt (falls in proot/other)
  apt update -y || true
  DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip ffmpeg curl git build-essential libjpeg-dev || true
fi

# Pip-Konfiguration (non-interaktive Installation)
echoinfo "Installiere Python-Pakete (Pillow, numpy falls nötig) ohne Eingabeaufforderung..."
export PIP_NO_INPUT=1
# Bei Termux Pillow braucht oft INCLUDE/LDFLAGS
if [ -n "${PREFIX:-}" ]; then
  export INCLUDE="$PREFIX/include"
  export LDFLAGS=" -lm"
fi

python3 -m pip install --upgrade pip setuptools wheel --no-input || true
python3 -m pip install --no-input Pillow || true
# numpy: falls systempaket nicht installiert
if ! python3 -c "import numpy" >/dev/null 2>&1; then
  # Versuche zuerst systempkg (pkg install python-numpy), ansonsten pip
  if command -v pkg >/dev/null 2>&1; then
    pkg install -y python-numpy || python3 -m pip install --no-input numpy || true
  else
    python3 -m pip install --no-input numpy || true
  fi
fi

# Stelle sicher, dass curl vorhanden ist
if ! command -v curl >/dev/null 2>&1; then
  echowarn "curl nicht gefunden. Versuche nochmal Paketinstallation."
  $PKG_CMD install -y curl || true
fi

# Lade SecCam.py (raw) vom GitHub-Repo
REPO_RAW="https://raw.githubusercontent.com/Damoon7/Security-Camera-Termux/refs/heads/main/SecCam.py"
TARGET="SecCam.py"
echoinfo "Lade SecCam.py von $REPO_RAW ..."
if curl -fsSL "$REPO_RAW" -o "$TARGET"; then
  echoinfo "Datei $TARGET erfolgreich heruntergeladen."
else
  echowarn "Konnte SecCam.py nicht herunterladen. Versuche git clone als Fallback..."
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/Damoon7/Security-Camera-Termux.git /tmp/SecCam_repo || true
    if [ -f /tmp/SecCam_repo/SecCam.py ]; then
      cp /tmp/SecCam_repo/SecCam.py .
      echoinfo "SecCam.py aus Git-Clone kopiert."
    else
      echoerr "Fail: SecCam.py nicht im geklonten Repo gefunden."
    fi
  else
    echoerr "Weder curl noch git funktionieren. Bitte manuell SecCam.py laden."
  fi
fi

# Setze Ausführungsrechte falls nötig (nicht zwingend, ist .py)
chmod a+r "$TARGET" || true

# Prüfe Termux:API Verfügbarkeit (termux-sms-send als Beispiel)
if command -v termux-sms-send >/dev/null 2>&1; then
  echoinfo "Termux:API-Befehle gefunden."
else
  echowarn "Termux:API scheint nicht installiert oder nicht im PATH. Installiere die Termux:API App von F-Droid (manuell) und erteile Berechtigungen."
  echowarn "Ohne Termux:API funktionieren SMS, Anrufe, Kamera-Kommandos u.ä. nicht."
fi

# Abschließende Hinweise
echoinfo "Installation abgeschlossen (oder soweit möglich)."
echoinfo "Vor der Ausführung: Stelle sicher, dass die App Termux:API installiert ist (F-Droid/GitHub) und Termux die benötigten Berechtigungen hat."
echoinfo "Um das Programm zu starten: python3 SecCam.py  (oder mit Optionen: python3 SecCam.py -h)"
echoinfo "Script Ende."
