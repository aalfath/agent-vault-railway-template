#!/bin/sh
# Start Agent Vault on Railway.
#  1. Refuse to start without a master password or a database (no passwordless mode, no SQLite on a
#     container disk that a redeploy would wipe).
#  2. On first boot, create the owner account from ADMIN_EMAIL/ADMIN_PASSWORD on a loopback-only
#     instance and switch on invite-only mode, so nobody else can claim the instance.
#  3. Run the real server: web UI and API on $PORT (public), credential proxy on 14322 (private network).
# Any failure exits non-zero, so Railway restarts the service.
set -eu

log() { echo "[railway-start] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

[ -n "${AGENT_VAULT_MASTER_PASSWORD:-}" ] || die "AGENT_VAULT_MASTER_PASSWORD is empty. Set it (the template generates one)."
[ -n "${DATABASE_URL:-}" ] || die "DATABASE_URL is empty. Point it at the Postgres service, e.g. \${{Postgres.DATABASE_URL}}."

PORT="${PORT:-14321}"
MITM_PORT="${AGENT_VAULT_MITM_PORT:-14322}"
BOOT_PORT=14399

# A public URL that resolved before the domain existed ends up as "https://": ignore it.
case "${AGENT_VAULT_ADDR:-}" in
  http://?*|https://?*) ;;
  *) [ -n "${AGENT_VAULT_ADDR:-}" ] && log "ignoring invalid AGENT_VAULT_ADDR '${AGENT_VAULT_ADDR}'"; unset AGENT_VAULT_ADDR ;;
esac

# Railway shows the host's CPU count inside a small service: size Go to the cgroup instead.
if [ -z "${GOMAXPROCS:-}" ] && [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r q p < /sys/fs/cgroup/cpu.max || true
  if [ "${q:-max}" != "max" ] && [ -n "${p:-}" ] && [ "$p" -gt 0 ]; then
    n=$(( (q + p - 1) / p )); [ "$n" -lt 2 ] && n=2
    export GOMAXPROCS="$n"
  fi
fi
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  m=$(cat /sys/fs/cgroup/memory.max)
  [ "$m" != "max" ] && export GOMEMLIMIT="$(( m / 100 * 80 ))B"
fi

mkdir -p "$HOME/.agent-vault"
rm -f "$HOME/.agent-vault/session.json" "$HOME/.agent-vault/agent-vault.pid"

status() { wget -qO- "http://127.0.0.1:${BOOT_PORT}/v1/status" 2>/dev/null || true; }

# ---- First-boot owner bootstrap (loopback only, proxy off) ----
attempt=0
while :; do
  attempt=$((attempt + 1))
  # The server unsets AGENT_VAULT_MASTER_PASSWORD from its own environment only, so the real server
  # below still sees it.
  agent-vault server --host 127.0.0.1 --port "$BOOT_PORT" --mitm-port 0 >/tmp/bootstrap.log 2>&1 &
  bpid=$!
  ready=0
  i=0
  while [ $i -lt 60 ]; do
    if ! kill -0 "$bpid" 2>/dev/null; then break; fi
    if wget -qO- "http://127.0.0.1:${BOOT_PORT}/health" >/dev/null 2>&1; then ready=1; break; fi
    i=$((i + 1)); sleep 1
  done
  [ "$ready" = 1 ] && break
  kill "$bpid" 2>/dev/null || true; wait "$bpid" 2>/dev/null || true
  log "bootstrap server not ready (attempt $attempt), last log lines:"
  tail -n 5 /tmp/bootstrap.log >&2 || true
  [ "$attempt" -ge 40 ] && die "could not start Agent Vault (database unreachable or wrong master password?)"
  sleep 3
done

stop_boot() { kill "$bpid" 2>/dev/null || true; wait "$bpid" 2>/dev/null || true; rm -f "$HOME/.agent-vault/session.json" "$HOME/.agent-vault/agent-vault.pid"; }

if status | grep -q '"initialized":true'; then
  log "owner account exists, skipping bootstrap"
else
  email="${ADMIN_EMAIL:-}"; pw="${ADMIN_PASSWORD:-}"
  if [ -z "$email" ] || [ "${#pw}" -lt 8 ]; then
    stop_boot; die "no owner account yet and ADMIN_EMAIL/ADMIN_PASSWORD (8+ characters) are not set; refusing to start with open sign-up"
  fi
  log "creating the owner account $email"
  if ! printf '%s\n' "$pw" | agent-vault auth register --address "http://127.0.0.1:${BOOT_PORT}" --email "$email" --password-stdin >/tmp/register.log 2>&1; then
    cat /tmp/register.log >&2; stop_boot; die "owner registration failed"
  fi
  if [ -f "$HOME/.agent-vault/session.json" ]; then
    # Only the first registration gets a session; switch self-registration off.
    agent-vault owner config set --invite-only >/tmp/config.log 2>&1 || { cat /tmp/config.log >&2; stop_boot; die "could not enable invite-only mode"; }
    log "owner created; invite-only mode on (change it under Manage Instance > Settings)"
  else
    log "another deploy created the owner first; nothing to do"
  fi
fi
stop_boot

# ---- Real server ----
log "starting Agent Vault: UI/API on :$PORT, credential proxy on :$MITM_PORT (private network)"
exec agent-vault server --host "" --port "$PORT" --mitm-port "$MITM_PORT"
