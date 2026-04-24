# scripts/

Идемпотентные shell-скрипты для серверных операций. Claude запускает их по SSH;
они написаны так, чтобы повторный запуск был безопасен (no-op при уже настроенном состоянии).

| Файл | Назначение | Документация |
|------|------------|--------------|
| `bootstrap-vps.sh` | Разовая настройка свежего Ubuntu 22.04 / 24.04 VPS: deploy user, SSH hardening, ufw, fail2ban, swap, Node/nginx/PM2/certbot, папки, deploy-ключ | `docs/server-manual-setup.md` |

## Принципы

1. **Idempotency.** Проверяй перед действием: `[ ! -f X ]`, `if ! id user`, `grep -q`, etc. Повторный запуск не должен ломать существующее состояние.
2. **Non-interactive by default.** `DEBIAN_FRONTEND=noninteractive`, `ufw --force`, `adduser --disabled-password --gecos ""`, `ssh-keygen -N ""`, и т.п. Никаких prompt'ов.
3. **Fail fast on errors.** `set -euo pipefail` в шапке.
4. **Verify inline.** Там, где критично (sshd config, visudo, nginx conf), — `sshd -t`, `visudo -c`, `nginx -t` перед apply.
5. **Secrets out of band.** Скрипты не должны ожидать секреты через stdin / argv. Параметры передаются через env vars (`DEPLOY_PUBKEY=...`) или читаются из уже существующего состояния (`/root/.ssh/authorized_keys`).
6. **Updates go in docs first.** Нашёл delta между реальным VPS и скриптом? Правь и то, и другое — в одном коммите.

## Тестировано на

- `bootstrap-vps.sh`: Ubuntu 24.04.4 LTS, Timeweb VPS (2 CPU, 4 GB RAM), 2026-04-24.
