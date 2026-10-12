# Docker Compose Updater

A small, allowlist-based automation for pulling Docker images and updating selected Docker Compose projects on a Linux VPS. It uses a Bash script and a systemd timer—no third-party updater container is required.

> **Production warning:** this performs deployments, not just image downloads. New images can introduce breaking changes, migrations, or downtime. Test first, pin versions for critical services, and maintain tested backups and a rollback plan. The script does **not** automatically roll back failed deployments.

## What it does

- Runs weekly (default: Sunday at 04:00 local server time, with up to 15 minutes of randomized delay).
- Updates only the project directories explicitly listed in `/etc/docker-compose-updater/projects`.
- Validates each Compose configuration before pulling images.
- Runs `docker compose pull --ignore-buildable` and then `docker compose up -d --wait`.
- Skips a project if its validation or image pull fails, and continues to the next project.
- Uses a lock to prevent overlapping runs and writes logs to the systemd journal.
- Returns a non-zero exit status if one or more projects fail.

It does not update images built locally from a `build:` section; those are skipped during `pull`. It also does not guarantee application-level health unless services have suitable Compose health checks.

## Requirements

- Linux with systemd (Ubuntu/Debian VPS is a typical target).
- Docker Engine and the Docker Compose v2 plugin (`docker compose`, not the legacy `docker-compose` command).
- Root/sudo access for installation and access to each project's Compose files, `.env` files, and secrets.
- Network access to the relevant image registries.

Check your versions:

```bash
docker --version
docker compose version
systemctl --version
```

The script uses `docker compose up --wait`; install a Compose version that supports `--wait`.

## Repository contents

```text
.
├── README.md
├── config/projects.example
├── scripts/docker-compose-weekly-update
├── systemd/docker-compose-weekly-update.service
├── systemd/docker-compose-weekly-update.timer
└── install.sh
```

## Install

Clone this repository on the VPS (or copy it to the server), then run:

```bash
sudo ./install.sh
```

The installer copies the script and systemd units into their system locations, creates `/etc/docker-compose-updater/projects` with commented examples if it does not exist, and enables the weekly timer. It does **not** overwrite an existing project allowlist. Add your real project paths before the first scheduled run; the initial allowlist intentionally contains no active paths.

## Configure the projects to update

Edit the allowlist:

```bash
sudo nano /etc/docker-compose-updater/projects
```

Add one **absolute directory path** per line. Each directory must contain one of these files: `compose.yaml`, `compose.yml`, `docker-compose.yaml`, or `docker-compose.yml`.

Example:

```text
# One Compose project directory per line
/opt/stacks/traefik
/opt/stacks/vaultwarden
/opt/stacks/monitoring
```

Blank lines and lines beginning with `#` are ignored. Only add projects that you intentionally want deployed automatically. If a project uses a non-standard Compose filename or multiple `-f` files, adapt the script to pass those files explicitly before adding it.

The Compose command runs from each project directory, so its default `.env` file and relative paths resolve from that directory. Keep secrets out of this repository and restrict access to production environment files.

## Test before the first scheduled run

Run it manually and inspect the output:

```bash
sudo /usr/local/sbin/docker-compose-weekly-update
```

Then test through systemd:

```bash
sudo systemctl start docker-compose-weekly-update.service
sudo systemctl status docker-compose-weekly-update.service
sudo journalctl -u docker-compose-weekly-update.service -n 200 --no-pager
```

See the timer and its next scheduled activation:

```bash
systemctl list-timers --all docker-compose-weekly-update.timer
```

Follow logs live:

```bash
sudo journalctl -fu docker-compose-weekly-update.service
```

## Schedule

Default schedule is Sunday at 04:00 in the server's local timezone, with up to 15 minutes of randomized delay. Edit `/etc/systemd/system/docker-compose-weekly-update.timer` to change it, then reload systemd:

```bash
sudo systemctl edit --full docker-compose-weekly-update.timer
sudo systemctl daemon-reload
sudo systemctl restart docker-compose-weekly-update.timer
systemctl list-timers --all docker-compose-weekly-update.timer
```

`Persistent=true` allows a missed calendar run to be triggered after the timer is activated again. It does not run every missed weekly occurrence.

## Common operations

```bash
# Run now
sudo systemctl start docker-compose-weekly-update.service

# Stop/disable the schedule
sudo systemctl disable --now docker-compose-weekly-update.timer

# Re-enable the schedule
sudo systemctl enable --now docker-compose-weekly-update.timer

# Check service result
sudo systemctl status docker-compose-weekly-update.service

# View this boot's logs
sudo journalctl -u docker-compose-weekly-update.service -b --no-pager
```

## Security notes

- Docker daemon access is effectively root-level access. Keep the script, systemd units, and allowlist owned by root and not writable by untrusted users.
- Do not expose the Docker API over unauthenticated TCP.
- Use least-privilege registry credentials and rotate them as needed.
- Pin versions or image digests for databases and other critical services; avoid blindly tracking `latest` in production.
- Back up persistent data and test restore procedures. A container update can be successful while an application or data migration is not.
- `up --wait` waits for services to be running/healthy where supported. Add meaningful `healthcheck` definitions to important services.
- This script does not roll back an update after a failed health check. Use maintenance windows and a documented rollback procedure for critical services.

## Troubleshooting

**No timer listed:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now docker-compose-weekly-update.timer
```

**Compose configuration fails:** run `docker compose config` from the affected project directory and check `.env` files, variable interpolation, and file permissions.

**Image pull fails:** check registry credentials, network/DNS, rate limits, and image names/tags.

**Service times out:** check the service logs and health checks. A service without a health check may be considered ready once started, which is not the same as application-level validation.

## References

- [Docker Compose `pull`](https://docs.docker.com/reference/cli/docker/compose/pull/)
- [Docker Compose `up`](https://docs.docker.com/reference/cli/docker/compose/up/)
- [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
