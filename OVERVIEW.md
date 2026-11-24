# Deploy and Host Agent Vault on Railway

Agent Vault is an open-source credential proxy and vault from Infisical. Your coding agents (Claude Code, Cursor, Codex, OpenCode or your own scripts) call APIs such as GitHub, Stripe or OpenAI through it, and Agent Vault adds the API key on the way out, so the agent never sees or leaks the key.

## About Hosting Agent Vault

This template runs Agent Vault v0.40.2 from the official image, built from a small public GitHub repo, with Railway Postgres holding all state: users, vaults, encrypted credentials, request logs and the proxy's certificate authority. A master password and the owner's password are generated at deploy. On first boot the start script creates the owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD` and switches on invite-only mode, so no stranger can claim the instance. The web UI and API get a public HTTPS domain. The credential proxy (port 14322) is plain HTTP, so it stays on Railway's private network for agents that run in the same project.

## Common Use Cases

* Let Claude Code, Cursor or Codex call GitHub, Stripe, OpenAI and other APIs without ever holding the API keys
* Give cloud-hosted agents in the same Railway project brokered, logged and revocable access to third-party APIs
* Review and approve an agent's requests for new credentials (proposals) from a web dashboard

## Dependencies for Agent Vault Hosting

* PostgreSQL (Railway Postgres, included in this template)
* An email address for the owner account (the only value you type at deploy)

### Deployment Dependencies

* Agent Vault source and releases: https://github.com/Infisical/agent-vault (release v0.40.2)
* Self-hosting docs: https://docs.agent-vault.dev/self-hosting/overview
* Template repo (Dockerfile and start script): https://github.com/aalfath/agent-vault-railway-template

### Implementation Details

**Services**

* **agent-vault**: the web UI and API on the public domain (health check `/health`), and the credential proxy on port 14322 inside the project's private network.
* **Postgres**: Railway's PostgreSQL with its own volume. Agent Vault keeps everything here, so a redeploy loses nothing.

**After deploy**

1. Open the `agent-vault` service's **Variables** tab and copy `ADMIN_PASSWORD`.
2. Open the public URL and sign in with `ADMIN_EMAIL` and that password. Change the password under your account settings if you like.
3. Add services and credentials to the `default` vault, then create an agent (**Agents > Add agent**) to get its token.

**Connect an agent**

On your own machine, install the CLI and log in to your instance:

```sh
agent-vault auth login --address https://YOUR-DOMAIN
agent-vault vault run -- claude
```

`vault run` points the agent's API calls at the proxy. The proxy port isn't exposed to the internet by this template, because upstream sends the agent token in cleartext on that port. Agents that run as services in the same Railway project reach it privately:

```sh
AGENT_VAULT_ADDR=http://${{agent-vault.RAILWAY_PRIVATE_DOMAIN}}:14321
HTTPS_PROXY=http://AGENT-TOKEN:default@${{agent-vault.RAILWAY_PRIVATE_DOMAIN}}:14322
HTTP_PROXY=http://AGENT-TOKEN:default@${{agent-vault.RAILWAY_PRIVATE_DOMAIN}}:14322
```

They also need to trust the proxy's root CA, which they can download from `/v1/mitm/ca.pem`. To reach the proxy from outside Railway, add a Railway TCP proxy for port 14322 yourself, and only over a network you trust.

**Optional settings:** add `AGENT_VAULT_SMTP_HOST`, `AGENT_VAULT_SMTP_PORT`, `AGENT_VAULT_SMTP_USERNAME`, `AGENT_VAULT_SMTP_PASSWORD` and `AGENT_VAULT_SMTP_FROM` for invite and verification emails. Telemetry is off by default (`AGENT_VAULT_TELEMETRY=false`). Container isolation (`--isolation=container`) is a client-side feature that needs Docker on your machine, not on Railway.

**Resources:** the app uses about 30–60 MB of RAM, so it fits Railway's Free plan (0.5 GB per service).

**Updates:** the service builds from the template repo. When we bump the pinned Agent Vault version there, Railway shows you an update notice. Read the repo's CHANGELOG.md, then apply it. Database migrations run automatically on start.

## Why Deploy Agent Vault on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Agent Vault on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
