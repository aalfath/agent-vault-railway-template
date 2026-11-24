# Agent Vault for Railway: the official image, pinned by version and digest.
# Upstream: https://github.com/Infisical/agent-vault (MIT), release v0.40.2.
FROM infisical/agent-vault:0.40.2@sha256:d09894c86c9b8df64ea37442ace9907dcdf82dabd2730b78b9e0c4c5e070e79a

# Fixed settings for Railway. Deployers can still override any of them as service variables.
#  - telemetry off by default
#  - Railway's edge proxies (100.64.0.0/10 and 152.233.0.0/16) are trusted for X-Forwarded-For,
#    so login rate limits key on the real client IP
ENV AGENT_VAULT_TELEMETRY=false \
    AGENT_VAULT_TRUSTED_PROXIES=100.64.0.0/10,152.233.0.0/16 \
    AGENT_VAULT_MITM_PORT=14322

COPY --chmod=755 railway-start.sh /usr/local/bin/railway-start.sh

EXPOSE 14321 14322
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
