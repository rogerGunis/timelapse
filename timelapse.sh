#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ENV_FIle=".timelapse.env"
if [[ -f "${ENV_FIle}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FIle}"
fi

# Config (override via environment or source an env file before running)
: "${FTP_SERVER:?FTP_SERVER not set}"
: "${FTP_USER:?FTP_USER not set}"
: "${FTP_PASS:?FTP_PASS not set}"
CAMERA="${CAMERA:-0}"

SCRIPT_NAME="$(basename "$0")"
PID_FILE="$HOME/${SCRIPT_NAME%.sh}.pid"
LOG_FILE="${HOME}/logs/timelapse.log"

DATE="$(date +'%Y%m%d_%H%M%S')"
DIR="$(date +'%Y%m')"
NAME="${DATE}.jpeg"

CURL_BASE_OPTS=(-C - -4 --retry 30 --retry-delay 10 --max-time 1000 --limit-rate 64k --user "${FTP_USER}:${FTP_PASS}")

cleanup() {
  rm -f "${NAME}" ip.txt battery.txt 2>/dev/null || true
  rm -f "${PID_FILE}" 2>/dev/null || true
}
trap cleanup EXIT

single_instance_guard() {
  if [[ -f "${PID_FILE}" ]]; then
    oldpid="$(<"${PID_FILE}")"
    if [[ "${oldpid}" =~ ^[0-9]+$ ]] && kill -0 "${oldpid}" 2>/dev/null; then
      if grep -q "${SCRIPT_NAME}" "/proc/${oldpid}/cmdline" 2>/dev/null; then
        echo "Already running (pid ${oldpid}). Exiting."
        exit 0
      else
        echo "Stale pid file (pid ${oldpid} not this script). Removing."
        rm -f "${PID_FILE}"
      fi
    else
      echo "Invalid or dead pid in pid file. Removing."
      rm -f "${PID_FILE}"
    fi
  fi
  echo $$ > "${PID_FILE}"
}

init_logging() {
  mkdir -p "$(dirname "${LOG_FILE}")"
  exec > >(tee "${LOG_FILE}") 2>&1
  echo
  echo "Start ${DATE}"
  echo "Script: ${SCRIPT_NAME}"
  echo "Camera: ${CAMERA}"
  echo "Remote dir: ${DIR}"
  echo "Image: ${NAME}"
}

require_tools() {
  for t in curl termux-camera-photo termux-battery-status termux-wifi-connectioninfo; do
    command -v "${t}" >/dev/null 2>&1 || { echo "Missing tool: ${t}"; exit 1; }
  done
}

capture_photo() {
  echo "Capturing photo"
  termux-camera-photo -c "${CAMERA}" "${NAME}"
}

ensure_remote_dir() {
  echo "Ensuring remote directory"
  curl "${CURL_BASE_OPTS[@]}" -Q "MKD ${DIR}" "ftp://${FTP_SERVER}/" || true
}

check_success_on_file_size() {
  local file="$1"
  local target_dir="$2"
  local local_size remote_size
  local_size=$(stat -c%s "${file}")
  remote_size=$(curl "${CURL_BASE_OPTS[@]}" -s --head "ftp://${FTP_SERVER}/${target_dir}/${file}" | grep -i '^Content-Length:' | awk '{print $2}' | tr -d '\r')
  if [[ "${local_size}" != "${remote_size}" ]]; then
    echo "File size mismatch for ${file}: local=${local_size}, remote=${remote_size}"
    upload_file "${file}" "${target_dir}"
  else
    echo "File size verified for ${file}: ${local_size} bytes"
  fi
}

upload_file() {
  local file="$1"
  local target_dir="$2"
  echo "Uploading ${file}"
  curl "${CURL_BASE_OPTS[@]}" -T "${file}" "ftp://${FTP_SERVER}/${target_dir}/${file}"
  # only on non txt files
  [[ "${file}" == *.txt ]] && return
  check_success_on_file_size "${file}" "${target_dir}"
}

refresh_status_files() {
  echo "Refreshing ip.txt & battery.txt"
  curl "${CURL_BASE_OPTS[@]}" -Q "-DELE ip.txt" -Q "-DELE battery.txt" "ftp://${FTP_SERVER}/" || true

  local ip
  ip="$(curl -s https://ipinfo.io/ip || echo unknown)"
  printf '%s\n' "${ip}" > ip.txt
  termux-battery-status > battery.txt
  termux-wifi-connectioninfo > wifi.txt

  upload_file ip.txt ""
  upload_file battery.txt ""
  upload_file "wifi.txt" ""
  rm -f ip.txt battery.txt wifi.txt
}

main() {
  single_instance_guard
  init_logging
  require_tools
  capture_photo
  if [[ -f "${NAME}" ]]; then
    ensure_remote_dir
    upload_file "${NAME}" "${DIR}"
    refresh_status_files
  else
    echo "Photo not found: ${NAME}"
    exit 1
  fi
  echo "Done"
}

main
