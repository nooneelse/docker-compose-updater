#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    echo "Run this installer with sudo: sudo $0" >&2
    exit 1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

command -v docker >/dev/null || {
    echo "ERROR: Docker is not installed or not in PATH." >&2
    exit 1
}
docker compose version >/dev/null
command -v systemctl >/dev/null || {
    echo "ERROR: systemd is not available on this host." >&2
    exit 1
}

install -d -o root -g root -m 0750 /etc/docker-compose-updater
install -o root -g root -m 0750 \
    "$ROOT_DIR/scripts/docker-compose-weekly-update" \
    /usr/local/sbin/docker-compose-weekly-update
install -o root -g root -m 0644 \
    "$ROOT_DIR/systemd/docker-compose-weekly-update.service" \
    /etc/systemd/system/docker-compose-weekly-update.service
install -o root -g root -m 0644 \
    "$ROOT_DIR/systemd/docker-compose-weekly-update.timer" \
    /etc/systemd/system/docker-compose-weekly-update.timer

if [[ ! -e /etc/docker-compose-updater/projects ]]; then
    install -o root -g root -m 0640 \
        "$ROOT_DIR/config/projects.example" \
        /etc/docker-compose-updater/projects
    echo "Created /etc/docker-compose-updater/projects from the example list. Edit it before relying on scheduled updates."
else
    echo "Keeping existing /etc/docker-compose-updater/projects unchanged."
fi

systemctl daemon-reload
systemctl enable --now docker-compose-weekly-update.timer

echo
echo "Installed. Review the project allowlist before the first run:"
echo "  sudo nano /etc/docker-compose-updater/projects"
echo "Test manually with:"
echo "  sudo /usr/local/sbin/docker-compose-weekly-update"
echo "Check the schedule with:"
echo "  systemctl list-timers --all docker-compose-weekly-update.timer"
