# Security Policy

This project runs as root and controls the Docker daemon, so security reports are taken seriously.

## Supported versions

Only the latest commit on `main` is supported. Please confirm an issue still exists there before reporting it.

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

Report it privately through GitHub: open the repository's **Security** tab and choose **Report a vulnerability**. Include:

- what the issue is and what an attacker could do with it;
- the steps or configuration needed to reproduce it;
- the commit you tested and your Docker, Docker Compose, and systemd versions.

You can expect an acknowledgement within a week. Once a fix is available, the report is disclosed together with the fix.

## Scope

In scope:

- the updater script, the installer, and the systemd units in this repository;
- ways an unprivileged local user could make the updater run commands or deploy projects it should not.

Out of scope:

- vulnerabilities in Docker, Docker Compose, systemd, or the container images you choose to deploy;
- problems that require an attacker who already has root or Docker daemon access on the host.
