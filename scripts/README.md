# scripts/

Идемпотентные shell-скрипты для серверных операций. Claude запускает их по SSH;
они написаны так, чтобы повторный запуск был безопасен (no-op при уже настроенном состоянии).

| Файл | Назначение | Документация |
|------|------------|--------------|
| `bootstrap-vps.sh` | Разовая настройка свежего Ubuntu 22.04 / 24.04 VPS: deploy user, SSH hardening, ufw, fail2ban, swap, Node runtime + Caddy + PM2, папки. Под push-based deploy ни pnpm, ни git на VPS не ставит | `docs/server-manual-setup.md` |
| `rollback.sh` | Атомарный откат прода: переключает симлинк `~/prod/{site}/current → releases/<previous-sha>/` + `pm2 reload`. Без пересборки, миллисекунды. Подсказывает корректный `git revert` (с `-m 1` для merge-коммитов) | `docs/automation.md` |
| `sync-env.sh` | Fallback-инструмент: копирует локальный `~/projects/{site}/.env.production` на VPS, `chmod 600`, `pm2 restart --update-env`. В штатном flow `.env` пушит сам workflow из `PROD_ENV_FILE` Environment-секрета — sync-env.sh нужен только если Actions недоступны или надо подкинуть env между деплоями | `docs/automation.md` |
| `fetch-env.sh` | Зеркало `sync-env.sh`: тянет активный `.env` с VPS в локальный `~/projects/{site}/.env.production`. Используется когда настраиваешь свежее устройство (новый Mac, потерял ноут) — VPS всегда содержит свежий файл из последнего workflow. Бэкапит существующий локальный файл перед перезаписью, `chmod 600`, печатает имена переменных (без значений) | `docs/automation.md` |

## Принципы

1. **Idempotency.** Проверяй перед действием: `[ ! -f X ]`, `if ! id user`, `grep -q`, etc. Повторный запуск не должен ломать существующее состояние.
2. **Non-interactive by default.** `DEBIAN_FRONTEND=noninteractive`, `ufw --force`, `adduser --disabled-password --gecos ""`, `ssh-keygen -N ""`, и т.п. Никаких prompt'ов.
3. **Fail fast on errors.** `set -euo pipefail` в шапке.
4. **Verify inline.** Там, где критично (sshd config, visudo, Caddyfile), — `sshd -t`, `visudo -c`, `caddy validate` перед apply.
5. **Secrets out of band.** Скрипты не должны ожидать секреты через stdin / argv. Параметры передаются через env vars (`DEPLOY_PUBKEY=...`) или читаются из уже существующего состояния (`/root/.ssh/authorized_keys`).
6. **Updates go in docs first.** Нашёл delta между реальным VPS и скриптом? Правь и то, и другое — в одном коммите.

## Тестировано на

- `bootstrap-vps.sh`: Ubuntu 24.04.4 LTS, Timeweb VPS (2 CPU, 4 GB RAM), 2026-04-24.
