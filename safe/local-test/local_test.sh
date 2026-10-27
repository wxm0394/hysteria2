#!/usr/bin/env bash
# Loopback test: Hysteria 2 server + client on 127.0.0.1, fetching from a local HTTP server.
# Needs only the 'hysteria' binary (set HYSTERIA_BIN if it is not in PATH). Run as a normal user.
set -euo pipefail

HY="${HYSTERIA_BIN:-hysteria}"
command -v "$HY" >/dev/null 2>&1 || { echo "hysteria binary not found (set HYSTERIA_BIN)." >&2; exit 1; }

SERVER_PORT=18443
SOCKS_PORT=11080
HTTP_PORT=18080
WD="$(mktemp -d)"
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done
  rm -rf "$WD"
}
trap cleanup EXIT

PW="$(openssl rand -hex 16)"
openssl ecparam -genkey -name prime256v1 -noout -out "$WD/server.key"
openssl req -new -x509 -days 1 -key "$WD/server.key" -out "$WD/server.crt" -subj "/CN=localhost"
FP="$(openssl x509 -noout -fingerprint -sha256 -in "$WD/server.crt" | cut -d= -f2)"

cat > "$WD/server.yaml" <<EOF
listen: 127.0.0.1:$SERVER_PORT
tls:
  cert: $WD/server.crt
  key: $WD/server.key
auth:
  type: password
  password: $PW
EOF

cat > "$WD/client.yaml" <<EOF
server: 127.0.0.1:$SERVER_PORT
auth: $PW
tls:
  sni: localhost
  insecure: true
  pinSHA256: $FP
socks5:
  listen: 127.0.0.1:$SOCKS_PORT
EOF

mkdir -p "$WD/www"
echo ok > "$WD/www/ok.txt"
python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$WD/www" >"$WD/http.log" 2>&1 &
PIDS+=("$!")
"$HY" server -c "$WD/server.yaml" >"$WD/server.log" 2>&1 &
PIDS+=("$!")
sleep 1
"$HY" client -c "$WD/client.yaml" >"$WD/client.log" 2>&1 &
PIDS+=("$!")

for _ in $(seq 1 20); do
  if (exec 3<>"/dev/tcp/127.0.0.1/$SOCKS_PORT") 2>/dev/null; then break; fi
  sleep 0.5
done

RESULT="$(curl -fsS --max-time 10 --socks5-hostname "127.0.0.1:$SOCKS_PORT" "http://127.0.0.1:$HTTP_PORT/ok.txt" 2>/dev/null || true)"
if [[ "$RESULT" == "ok" ]]; then
  echo "PASS: client -> server tunnel works on loopback."
else
  echo "FAIL. Last log lines:" >&2
  tail -n 20 "$WD/server.log" "$WD/client.log" >&2
  exit 1
fi
