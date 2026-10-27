#!/usr/bin/env bash
# Minimal, auditable Hysteria 2 server setup.
# Does NOT touch Xray, the kernel, or iptables rules. Downloads only the official installer.
# Usage: sudo bash setup.sh [UDP_PORT] [SNI]    (defaults: 8443 www.bing.com)
set -euo pipefail

PORT="${1:-8443}"
SNI="${2:-www.bing.com}"
CONF_DIR=/etc/hysteria
CONF="$CONF_DIR/config.yaml"

[[ "$EUID" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "Invalid port: $PORT" >&2; exit 1; }
[[ "$SNI" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid SNI: $SNI" >&2; exit 1; }

if ss -H -lun "sport = :$PORT" | grep -q .; then
  echo "UDP port $PORT is already in use." >&2
  exit 1
fi

if ! command -v hysteria >/dev/null 2>&1; then
  tmp="$(mktemp)"
  curl -fsSL https://get.hy2.sh/ -o "$tmp"
  echo "Official installer saved to $tmp"
  sha256sum "$tmp"
  read -r -p "Review the file if you wish, then press Enter to run it (Ctrl+C to abort): " _
  bash "$tmp"
  rm -f "$tmp"
fi

id -u hysteria >/dev/null 2>&1 || { echo "User 'hysteria' not found; installer layout may have changed. Aborting." >&2; exit 1; }

install -d -m 755 "$CONF_DIR"
if [[ -e "$CONF" ]]; then
  cp -a "$CONF" "$CONF.bak.$(date +%Y%m%d-%H%M%S)"
fi

openssl ecparam -genkey -name prime256v1 -noout -out "$CONF_DIR/server.key"
openssl req -new -x509 -days 3650 -key "$CONF_DIR/server.key" -out "$CONF_DIR/server.crt" -subj "/CN=$SNI"
chown hysteria:hysteria "$CONF_DIR/server.key" "$CONF_DIR/server.crt"
chmod 600 "$CONF_DIR/server.key"
chmod 644 "$CONF_DIR/server.crt"

PASSWORD="$(openssl rand -hex 24)"
install -m 600 -o hysteria -g hysteria /dev/null "$CONF"
cat > "$CONF" <<EOF
listen: :$PORT

tls:
  cert: $CONF_DIR/server.crt
  key: $CONF_DIR/server.key

auth:
  type: password
  password: $PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://$SNI/
    rewriteHost: true
EOF

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "^Status: active"; then
  ufw allow "${PORT}/udp"
fi

systemctl enable --now hysteria-server.service
sleep 2
if ! systemctl is-active --quiet hysteria-server.service; then
  journalctl -u hysteria-server.service -n 30 --no-pager
  exit 1
fi

FP="$(openssl x509 -noout -fingerprint -sha256 -in "$CONF_DIR/server.crt" | cut -d= -f2)"
echo
echo "Hysteria 2 is running on UDP $PORT."
echo "Password   : $PASSWORD   (also stored in $CONF; do not commit or share it)"
echo "SNI        : $SNI"
echo "Cert SHA256: $FP"
echo "If your provider panel has a network firewall, also allow UDP $PORT there."
