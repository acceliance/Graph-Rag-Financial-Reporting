#!/usr/bin/env bash
# =============================================================================
#  Acceliance Graph-RAG: one-shot deployment on a fresh Ubuntu server (24.04+).
#
#  Adapted from Graph-Rag-Deploy/scripts/deploy-debian.sh. Differences: Ubuntu
#  package sources, Cockpit on port 9090, one certificate shared by Apache and
#  Cockpit, and the Apache listener on port 80 is stopped before certbot runs.
#
#  Installs and configures, in this order:
#    1. Docker Engine + Compose plugin (Docker's apt repository, else Ubuntu's own packages)
#    2. The Graph-RAG stack under /opt/graphrag (scripts/up.sh, bound to 127.0.0.1)
#    3. Apache as reverse proxy on 443 ONLY, with a TLS certificate
#    4. Cockpit on 9090 (web administration of the server), with the same certificate
#    5. ufw firewall: deny all incoming except SSH, 443/tcp and 9090/tcp
#
#  Usage (as root, from a copy of this repository on the server):
#
#    sudo scripts/deploy-ubuntu.sh --domain graphdemo-finance.acceliance.fr --email you@example.com
#
#  Certificate modes (pick one):
#    (default)               Let's Encrypt via certbot. Needs a public DNS record
#                            pointing to this server. Port 80 is opened ONLY for
#                            the seconds an issuance/renewal takes (HTTP-01), then
#                            closed again: it is never left open.
#    --cert F --key F        Use your own certificate (PEM fullchain + private key).
#    --self-signed           Self-signed certificate (tests only; browsers warn).
#
#  Options:
#    --domain NAME           Public FQDN of the server (required)
#    --email ADDR            Let's Encrypt account e-mail (required in LE mode)
#    --ssh-port N            SSH port to keep open (default: detected from sshd, else 22)
#    --install-dir DIR       Where the stack lives (default: /opt/graphrag)
#    --staging               Use the Let's Encrypt staging CA (avoids rate limits)
#    --cockpit-allow CIDR    Only this source address or network may reach port 9090
#                            (default: anyone; Cockpit logs in with server accounts)
#    --no-cockpit            Do not install Cockpit
#    --max-pages N           GRAPHRAG_MAX_PAGES (default 600)
#    --max-upload-mb N       GRAPHRAG_MAX_UPLOAD_MB (default 60)
#
#  Idempotent: safe to run again. Data (./data) and secrets (.env) in the
#  install dir are never overwritten.
# =============================================================================
set -euo pipefail

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DOMAIN=""; EMAIL=""; SSH_PORT=""; INSTALL_DIR="/opt/graphrag"
CERT_MODE="letsencrypt"; USER_CERT=""; USER_KEY=""; LE_STAGING=0
COCKPIT=1; COCKPIT_ALLOW=""; MAX_PAGES=600; MAX_UPLOAD_MB=60

while [ $# -gt 0 ]; do
  case "$1" in
    --domain)         DOMAIN="${2:-}"; shift 2;;
    --email)          EMAIL="${2:-}"; shift 2;;
    --ssh-port)       SSH_PORT="${2:-}"; shift 2;;
    --install-dir)    INSTALL_DIR="${2:-}"; shift 2;;
    --cert)           USER_CERT="${2:-}"; CERT_MODE="custom"; shift 2;;
    --key)            USER_KEY="${2:-}"; CERT_MODE="custom"; shift 2;;
    --self-signed)    CERT_MODE="selfsigned"; shift;;
    --staging)        LE_STAGING=1; shift;;
    --cockpit-allow)  COCKPIT_ALLOW="${2:-}"; shift 2;;
    --no-cockpit)     COCKPIT=0; shift;;
    --max-pages)      MAX_PAGES="${2:-}"; shift 2;;
    --max-upload-mb)  MAX_UPLOAD_MB="${2:-}"; shift 2;;
    -h|--help)        sed -n '2,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *)                fail "unknown option: $1 (try --help)";;
  esac
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
[ "$(id -u)" = "0" ] || fail "run as root (sudo)."
[ -r /etc/os-release ] || fail "/etc/os-release not found."
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || fail "this script targets Ubuntu (detected: ${ID:-unknown}). Use deploy-debian.sh on Debian."
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"; [ -n "$CODENAME" ] || fail "cannot detect the Ubuntu codename."

[ -n "$DOMAIN" ] || fail "--domain is required."
[[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || fail "invalid domain: $DOMAIN"
case "$CERT_MODE" in
  letsencrypt) [ -n "$EMAIL" ] || fail "--email is required for Let's Encrypt.";;
  custom)      [ -r "$USER_CERT" ] && [ -r "$USER_KEY" ] || fail "--cert and --key must both be given and readable.";;
esac
[[ "$MAX_PAGES" =~ ^[0-9]+$ ]] || fail "invalid --max-pages: $MAX_PAGES"
[[ "$MAX_UPLOAD_MB" =~ ^[0-9]+$ ]] || fail "invalid --max-upload-mb: $MAX_UPLOAD_MB"
if [ -n "$COCKPIT_ALLOW" ]; then
  [[ "$COCKPIT_ALLOW" =~ ^[0-9A-Fa-f:.]+(/[0-9]+)?$ ]] || fail "invalid --cockpit-allow (address or CIDR expected): $COCKPIT_ALLOW"
fi
[ -f "$SRC_ROOT/docker-compose.yaml" ] || fail "docker-compose.yaml not found in $SRC_ROOT (run from the repository)."

# SSH port: explicit > sshd effective config > 22. Opening the wrong one would lock us out.
if [ -z "$SSH_PORT" ]; then
  SSH_PORT="$( (sshd -T 2>/dev/null || true) | awk '$1=="port"{print $2; exit}')"
  SSH_PORT="${SSH_PORT:-22}"
fi
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ] || fail "invalid SSH port: $SSH_PORT"

say "Deploying Graph-RAG for https://$DOMAIN  (Ubuntu $CODENAME, cert: $CERT_MODE, ssh port: $SSH_PORT, dir: $INSTALL_DIR, cockpit: $([ "$COCKPIT" = 1 ] && echo "9090${COCKPIT_ALLOW:+ from $COCKPIT_ALLOW}" || echo off))"
if [ "$CERT_MODE" = "letsencrypt" ]; then
  echo "    DNS for $DOMAIN must already point to this server, or issuance will fail."
fi

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Packages and Docker Engine
# ---------------------------------------------------------------------------
say "Installing base packages"
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl gnupg openssl rsync ufw apache2
[ "$CERT_MODE" = "letsencrypt" ] && apt-get install -y --no-install-recommends certbot
[ "$COCKPIT" = 1 ] && apt-get install -y --no-install-recommends cockpit

# Apache starts on port 80 as soon as it is installed. Stop it: certbot needs port 80 free,
# and the final configuration listens on 443 only.
systemctl stop apache2 2>/dev/null || true

if ! docker compose version >/dev/null 2>&1; then
  say "Installing Docker Engine"
  install_docker_official() {
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  }
  if ! install_docker_official; then
    warn "Docker's repository has no package for Ubuntu '$CODENAME' yet: using Ubuntu's own docker.io and docker-compose-v2."
    rm -f /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker.io docker-compose-v2
  fi
fi
systemctl enable --now docker
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is not available after installation."

# ---------------------------------------------------------------------------
# 2. Graph-RAG stack: copy the kit, configure .env, start via scripts/up.sh
# ---------------------------------------------------------------------------
say "Installing the stack in $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
if [ "$(readlink -f "$SRC_ROOT")" != "$(readlink -f "$INSTALL_DIR")" ]; then
  rsync -a --exclude '.git' --exclude '/data' --exclude '/.env' --exclude '/samples/real-reports/downloads' \
    "$SRC_ROOT"/ "$INSTALL_DIR"/
fi
cd "$INSTALL_DIR"

set_env() { # set_env KEY VALUE: replace the line, or append it
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else printf '%s=%s\n' "$1" "$2" >> .env; fi
}

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 600 .env
  set_env NEO4J_PASSWORD "$(openssl rand -base64 33 | tr -d '+/=\n' | cut -c1-32)"
  set_env QDRANT_API_KEY "$(openssl rand -base64 33 | tr -d '+/=\n' | cut -c1-32)"
fi
set_env GRAPHRAG_HTTP_BIND 127.0.0.1      # plain HTTP reachable from the host only
set_env GRAPHRAG_HTTP_PORT 8080
set_env AUTH_COOKIE_SECURE true           # we serve HTTPS
set_env GRAPHRAG_MAX_PAGES "$MAX_PAGES"
set_env GRAPHRAG_MAX_UPLOAD_MB "$MAX_UPLOAD_MB"
grep -q '^MCP_ALLOWED_HOSTS=.\+' .env || set_env MCP_ALLOWED_HOSTS "$DOMAIN,$DOMAIN:*"   # with and without a port, else clients get 421

bash scripts/up.sh

# ---------------------------------------------------------------------------
# 3a. Firewall: before exposing anything. SSH rule first so we never lock out.
# ---------------------------------------------------------------------------
say "Configuring the firewall (allow ${SSH_PORT}/tcp, 443/tcp$([ "$COCKPIT" = 1 ] && echo ", 9090/tcp"))"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment 'SSH'
ufw allow 443/tcp comment 'HTTPS Graph-RAG'
if [ "$COCKPIT" = 1 ]; then
  if [ -n "$COCKPIT_ALLOW" ]; then
    ufw allow from "$COCKPIT_ALLOW" to any port 9090 proto tcp comment 'Cockpit'
  else
    ufw allow 9090/tcp comment 'Cockpit'
  fi
fi
ufw --force enable
# Docker only publishes 127.0.0.1:8080 (see .env), so it never bypasses ufw.

# ---------------------------------------------------------------------------
# 3b. TLS certificate, shared by Apache and Cockpit
# ---------------------------------------------------------------------------
# Cockpit wants one file holding the certificate chain then the key, readable by its group.
install_cockpit_cert() { # install_cockpit_cert FULLCHAIN KEY
  [ "$COCKPIT" = 1 ] || return 0
  install -d -m 0755 /etc/cockpit/ws-certs.d
  rm -f /etc/cockpit/ws-certs.d/0-self-signed.cert /etc/cockpit/ws-certs.d/0-self-signed.key
  cat "$1" "$2" > /etc/cockpit/ws-certs.d/10-graphrag.cert
  chown root:cockpit-ws /etc/cockpit/ws-certs.d/10-graphrag.cert 2>/dev/null || true
  chmod 0640 /etc/cockpit/ws-certs.d/10-graphrag.cert
  systemctl restart cockpit.socket cockpit.service 2>/dev/null || true
}

# Apache must not listen on 80 while certbot's standalone server needs it.
cat > /etc/apache2/ports.conf <<EOF
# Managed by scripts/deploy-ubuntu.sh
Listen 443
EOF

case "$CERT_MODE" in
  letsencrypt)
    say "Requesting a Let's Encrypt certificate (port 80 open only during issuance)"
    TLS_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    TLS_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    # Renewal hook: runs after every issuance and renewal. Reloads Apache, refreshes Cockpit's copy.
    install -d /etc/letsencrypt/renewal-hooks/deploy
    cat > /etc/letsencrypt/renewal-hooks/deploy/graphrag.sh <<EOF
#!/bin/sh
# Managed by scripts/deploy-ubuntu.sh
systemctl reload apache2 2>/dev/null || true
if [ -d /etc/cockpit ]; then
  install -d -m 0755 /etc/cockpit/ws-certs.d
  rm -f /etc/cockpit/ws-certs.d/0-self-signed.cert /etc/cockpit/ws-certs.d/0-self-signed.key
  cat "$TLS_CERT" "$TLS_KEY" > /etc/cockpit/ws-certs.d/10-graphrag.cert
  chown root:cockpit-ws /etc/cockpit/ws-certs.d/10-graphrag.cert 2>/dev/null || true
  chmod 0640 /etc/cockpit/ws-certs.d/10-graphrag.cert
  systemctl restart cockpit.socket cockpit.service 2>/dev/null || true
fi
EOF
    chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/graphrag.sh
    LE_ARGS=(certonly --standalone --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN"
             --pre-hook  "/usr/sbin/ufw allow 80/tcp"
             --post-hook "/usr/sbin/ufw delete allow 80/tcp")
    [ "$LE_STAGING" = "1" ] && LE_ARGS+=(--staging)
    certbot "${LE_ARGS[@]}"
    install_cockpit_cert "$TLS_CERT" "$TLS_KEY"
    systemctl enable --now certbot.timer 2>/dev/null || true   # automatic renewal
    ;;
  custom)
    say "Installing the provided certificate"
    install -d -m 0750 /etc/graphrag/tls
    install -m 0644 "$USER_CERT" /etc/graphrag/tls/fullchain.pem
    install -m 0600 "$USER_KEY"  /etc/graphrag/tls/privkey.pem
    TLS_CERT=/etc/graphrag/tls/fullchain.pem; TLS_KEY=/etc/graphrag/tls/privkey.pem
    install_cockpit_cert "$TLS_CERT" "$TLS_KEY"
    ;;
  selfsigned)
    say "Generating a self-signed certificate (tests only)"
    install -d -m 0750 /etc/graphrag/tls
    if [ ! -f /etc/graphrag/tls/privkey.pem ]; then
      openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
        -keyout /etc/graphrag/tls/privkey.pem -out /etc/graphrag/tls/fullchain.pem \
        -subj "/CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN"
      chmod 600 /etc/graphrag/tls/privkey.pem
    fi
    TLS_CERT=/etc/graphrag/tls/fullchain.pem; TLS_KEY=/etc/graphrag/tls/privkey.pem
    install_cockpit_cert "$TLS_CERT" "$TLS_KEY"
    ;;
esac

# ---------------------------------------------------------------------------
# 3c. Apache reverse proxy: 443 only (nothing listens on 80)
# ---------------------------------------------------------------------------
say "Configuring Apache (listening on 443 only)"
a2enmod ssl proxy proxy_http headers >/dev/null
a2dissite 000-default default-ssl >/dev/null 2>&1 || true
LIMIT_BYTES=$(( (MAX_UPLOAD_MB + 10) * 1024 * 1024 ))   # upload limit plus multipart headroom
cat > /etc/apache2/sites-available/graphrag.conf <<EOF
# Managed by scripts/deploy-ubuntu.sh: edits are overwritten on the next run.
<VirtualHost *:443>
    ServerName $DOMAIN

    SSLEngine on
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    SSLCertificateFile    $TLS_CERT
    SSLCertificateKeyFile $TLS_KEY
    Header always set Strict-Transport-Security "max-age=31536000"

    # GRAPHRAG_MAX_UPLOAD_MB ($MAX_UPLOAD_MB) plus headroom, in bytes
    LimitRequestBody $LIMIT_BYTES

    # Keep Host (with port) for the MCP allow-list; long timeout for the agent loop.
    ProxyPreserveHost On
    ProxyTimeout 300
    RequestHeader set X-Forwarded-Proto "https"

    ProxyPass        / http://127.0.0.1:8080/ retry=0
    ProxyPassReverse / http://127.0.0.1:8080/
</VirtualHost>
EOF
a2ensite graphrag >/dev/null
apache2ctl configtest
systemctl enable apache2
systemctl restart apache2

# ---------------------------------------------------------------------------
# 4. Cockpit
# ---------------------------------------------------------------------------
if [ "$COCKPIT" = 1 ]; then
  say "Enabling Cockpit on port 9090"
  systemctl enable --now cockpit.socket
fi

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
say "Verifying"
ufw status verbose | sed 's/^/    /'
code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/" || echo 000)"
echo "    https://$DOMAIN/ -> HTTP $code (via 127.0.0.1)"
if [ "$COCKPIT" = 1 ]; then
  ccode="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve "$DOMAIN:9090:127.0.0.1" "https://$DOMAIN:9090/" || echo 000)"
  echo "    https://$DOMAIN:9090/ -> HTTP $ccode (via 127.0.0.1)"
fi
if [ "$CERT_MODE" = "letsencrypt" ]; then
  echo "    Certificate: $(openssl x509 -in "$TLS_CERT" -noout -issuer -enddate | tr '\n' ' ')"
fi
if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)80$'; then
  warn "something is listening on port 80 (blocked by the firewall, but check it)."
fi

say "Done:  https://$DOMAIN"
echo "    First visit: create the administrator account, then Admin > AI settings."
[ "$COCKPIT" = 1 ] && echo "    Cockpit: https://$DOMAIN:9090 (log in with a server account that has a password; root is refused by Cockpit)."
echo "    Secrets: $INSTALL_DIR/.env (mode 600): back it up. Data: $INSTALL_DIR/data (scripts/backup.sh)."
[ "$CERT_MODE" = "letsencrypt" ] && echo "    Certificate renews automatically (certbot.timer); port 80 opens only during renewal."
exit 0
