[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/agent-vault?utm_medium=integration&utm_source=button&utm_campaign=agent-vault)

# Agent Vault on Railway

One-click Railway template for [Agent Vault](https://github.com/Infisical/agent-vault) by Infisical: an open-source HTTP credential proxy and vault. Coding agents call APIs through it, and it adds your API keys on the way out, so the agents never see the keys.

**Version:** Agent Vault v0.40.2, official image `infisical/agent-vault:0.40.2@sha256:d09894c86c9b8df64ea37442ace9907dcdf82dabd2730b78b9e0c4c5e070e79a` (pinned in the `Dockerfile`).

## What the template deploys

| Service | Source | What it does |
|---|---|---|
| `agent-vault` | this repo (`Dockerfile` + `railway-start.sh`) | Web UI and API on the public domain (health check `/health`). Credential proxy on port 14322, on the private network only. |
| `Postgres` | Railway PostgreSQL, with a volume | All state: users, vaults, encrypted credentials, logs, the proxy's root CA. |

On first boot, `railway-start.sh` starts Agent Vault on loopback only. It creates the owner account from `ADMIN_EMAIL`/`ADMIN_PASSWORD` and switches on invite-only mode before the public listener opens, so the first visitor can't claim the instance. If that fails, the service exits non-zero and Railway restarts it. It never runs with open sign-up.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_EMAIL` | *(you enter it)* | Email for the owner account. The only prompt at deploy. |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Owner password. Read it in the service's Variables tab after deploy. Used only to create the owner on first boot. |
| `AGENT_VAULT_MASTER_PASSWORD` | `${{secret(48)}}` | Wraps the data encryption key. **Never change or lose it**: your stored credentials can't be decrypted without it. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private-network Postgres connection. |
| `AGENT_VAULT_ADDR` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public base URL, used in invite links and the agent setup screens. |
| `PORT` | `14321` | Web UI and API port. |

Fixed in the `Dockerfile` (you can override them as variables): `AGENT_VAULT_TELEMETRY=false`, `AGENT_VAULT_TRUSTED_PROXIES` (Railway's edge ranges), `AGENT_VAULT_MITM_PORT=14322`. The start script sets `GOMAXPROCS` and `GOMEMLIMIT` from the container's limits. The SMTP settings and the rest of upstream's [environment variables](https://docs.agent-vault.dev/self-hosting/environment-variables) are optional.

## The credential proxy

Upstream's proxy (port 14322) is plain HTTP and carries the agent token in the `Proxy-Authorization` header, so upstream says to keep it on a trusted network. This template doesn't expose it publicly. Agents in the same Railway project use `http://AGENT-TOKEN:default@${{agent-vault.RAILWAY_PRIVATE_DOMAIN}}:14322` as `HTTPS_PROXY`, and trust the CA from `/v1/mitm/ca.pem`. To reach it from elsewhere, add a Railway TCP proxy for 14322 yourself.

## Resources

About 30–60 MB of RAM when idle. It fits Railway's Free plan (0.5 GB per service).

## Updates

The `agent-vault` service builds from this repo's `main` branch. When we bump the pinned version here, Railway shows deployers an "update available" notice, and you choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Agent Vault runs its database migrations on start.

## Licence

This wrapper is MIT. Agent Vault is MIT, by Infisical (the repo's `ee/` clause doesn't apply: v0.40.2 has no `ee/` folder).
