#!/usr/bin/env bash
set -euo pipefail

##
## Codex macOS -> Manjaro port helper (shareable)
## Pokreće se ovako:
##   bash ./codex-port-manjaro.sh
##

echo "=== [0] Brza provera sistema (nema hardcodovanih putanja za ovu mašinu) ==="

ARCH="$(uname -m 2>/dev/null || echo unknown)"
KERNEL="$(uname -r 2>/dev/null || echo unknown)"
OS_NAME="unknown"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_NAME="${NAME:-$ID}"
fi

echo "OS        : $OS_NAME"
echo "Kernel    : $KERNEL"
echo "Arch      : $ARCH"
echo "HOME      : $HOME"

echo
echo "Provera komandi:"
for cmd in pacman curl 7z node npm pnpm electron; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  - $cmd: OK ($(command -v "$cmd"))"
  else
    echo "  - $cmd: nije pronađen (skripta će ga instalirati ili nije obavezan)"
  fi
done

if [ "$ARCH" != "x86_64" ]; then
  echo
  echo "UPOZORENJE: arhitektura nije x86_64 (detektovano: $ARCH)."
  echo "Native moduli kao better-sqlite3 možda neće moći da se izgrade ispravno."
fi

echo

echo "=== [1] Preuzimanje Codex.dmg na ~/Downloads/codex-macos ==="
mkdir -p "$HOME/Downloads/codex-macos"
cd "$HOME/Downloads/codex-macos"

if [ ! -f Codex.dmg ]; then
  echo "Preuzimam Codex.dmg..."
  curl -L -o Codex.dmg "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
else
  echo "Codex.dmg već postoji, preskačem download."
fi

echo
echo "=== [2] Sistemski paketi (pacman) + pnpm + asar + electron ==="

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman nije pronađen. Izgleda da nisi na Manjaro/Arch sistemu." >&2
  exit 1
fi

echo "Instaliram osnovne pakete preko pacman (može da traži sudo lozinku)..."
sudo pacman -S --needed p7zip nodejs npm python base-devel git electron

echo
echo "Verzije nakon pacman instalacije:"
node -v || true
npm -v || true
electron --version || true

echo
echo "Proveravam pnpm..."
if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm nije instaliran, instaliram ga preko npm (jedini put kada koristimo npm)..."
  sudo npm i -g pnpm
fi

pnpm -v

# apsolutna putanja do pnpm binara
PNPM_BIN="$(command -v pnpm)"

# postavi PNPM_HOME tako da global bin ima gde da ide (i da bude predvidljiv)
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
mkdir -p "$PNPM_HOME"

echo
echo "Proveravam asar preko pnpm dlx (bez globalne instalacije)..."
"$PNPM_BIN" dlx asar --version || true

echo
echo "=== [3] Ekstrakcija DMG i app.asar u ~/apps/codex-port ==="

ROOT_APP_DIR="$HOME/apps/codex-port"
mkdir -p "$ROOT_APP_DIR"
cd "$ROOT_APP_DIR"

echo "Ekstrahujem Codex.dmg pomoću 7z (auto overwrite - A za sve)..."
7z x -y -aoa "$HOME/Downloads/codex-macos/Codex.dmg" -o./dmg_extracted

echo
echo "Tražim app.asar unutar dmg_extracted..."
APP_ASAR_PATH=$(find ./dmg_extracted -name "app.asar" -print | head -n 1 || true)

if [ -z "${APP_ASAR_PATH:-}" ]; then
  echo "Nisam pronašao app.asar unutar ./dmg_extracted." >&2
  exit 1
fi

echo "Nađeni app.asar: $APP_ASAR_PATH"

mkdir -p "$ROOT_APP_DIR/app_asar"
echo "Raspakujem app.asar u app_asar direktorijum (preko pnpm dlx asar)..."
"$PNPM_BIN" dlx asar extract "$APP_ASAR_PATH" "$ROOT_APP_DIR/app_asar"

echo
echo "=== [4] Rebuild native modula (better-sqlite3, node-pty) preko pnpm ==="

cd "$ROOT_APP_DIR/app_asar"

echo
echo "Čitam Electron verziju..."
ELECTRON_VERSION=$(electron --version | tr -d 'v' || true)

if [ -z "${ELECTRON_VERSION:-}" ]; then
  echo "Nisam uspeo da očitam Electron verziju. Proveri da li je electron ispravno instaliran." >&2
  exit 1
fi

echo "Electron verzija: $ELECTRON_VERSION"

echo
echo "Pravim izolovani projekat za build better-sqlite3 za Electron (da zaobiđem workspace i polovičan paket iz DMG)..."
TMP_BUILD_DIR="$ROOT_APP_DIR/_better-sqlite3-build"
rm -rf "$TMP_BUILD_DIR"
mkdir -p "$TMP_BUILD_DIR"

echo "Čitam verziju better-sqlite3 iz Codex app-a..."
BSQL_VERSION=$(node -p "require('$ROOT_APP_DIR/app_asar/node_modules/better-sqlite3/package.json').version" 2>/dev/null || echo "12.5.0")
echo "better-sqlite3 verzija: $BSQL_VERSION"

cd "$TMP_BUILD_DIR"
echo "Kreiram minimalni package.json za temp projekat..."
cat > package.json <<EOF
{
  "name": "better-sqlite3-electron-build",
  "version": "1.0.0",
  "private": true
}
EOF

pnpm add "better-sqlite3@$BSQL_VERSION"

echo
echo "Rebuildujem better-sqlite3 u izolovanom projektu za Electron $ELECTRON_VERSION..."
ELECTRON_REBUILD_CMD="$PNPM_BIN dlx electron-rebuild -v \"$ELECTRON_VERSION\" -f better-sqlite3"
echo "Komanda: $ELECTRON_REBUILD_CMD"
set +e
eval "$ELECTRON_REBUILD_CMD"
REB_RES=$?
set -e

if [ "$REB_RES" -ne 0 ]; then
  echo "UPOZORENJE: electron-rebuild (u izolovanom projektu) je pukao (exit code $REB_RES). Pokušavam ipak da kopiram modul."
fi

echo
echo "Kopiram bolje izgrađen modul better-sqlite3 u Codex app_asar..."
if [ -d "$TMP_BUILD_DIR/node_modules/better-sqlite3" ]; then
  rm -rf "$ROOT_APP_DIR/app_asar/node_modules/better-sqlite3"
  cp -a "$TMP_BUILD_DIR/node_modules/better-sqlite3" "$ROOT_APP_DIR/app_asar/node_modules/better-sqlite3"
  echo "better-sqlite3 je kopiran u app_asar/node_modules."
else
  echo "UPOZORENJE: u izolovanom projektu nije pronađen node_modules/better-sqlite3; preskačem kopiranje."
fi

echo
echo "=== [5] run-codex.sh skripta za pokretanje Codex-a ==="

cat > "$ROOT_APP_DIR/run-codex.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/app_asar"

export ELECTRON_FORCE_IS_PACKAGED=1
export NODE_ENV=production

# default CLI path na pnpm instalaciju; može da se override-uje spolja
export CODEX_CLI_PATH="${CODEX_CLI_PATH:-$HOME/.local/share/pnpm/codex}"

electron "$APP_DIR"
EOF

chmod +x "$ROOT_APP_DIR/run-codex.sh"

echo
echo "run-codex.sh je kreiran u: $ROOT_APP_DIR/run-codex.sh"
echo "Primer pokretanja (sa CODEX_CLI_PATH ako treba):"
echo "  CODEX_CLI_PATH=/neki/drugi/codex $ROOT_APP_DIR/run-codex.sh"

echo
echo "=== [6] Codex CLI instalacija preko pnpm (globalno) ==="

echo "Podesavam pnpm global okruzenje (pnpm setup)..."
"$PNPM_BIN" setup || true

# osiguraj da PNPM_HOME i global dir postoje (za izbegavanje ENOENT na pnpm-lock.yaml)
mkdir -p "$PNPM_HOME/global/5"

echo "Instaliram @openai/codex globalno za korisnika (pnpm -g, bez sudo)..."
"$PNPM_BIN" i -g @openai/codex || true

echo
echo "Proveravam codex CLI:"
PATH="$PNPM_HOME:$PATH" which codex || true
PATH="$PNPM_HOME:$PATH" codex --version || true

echo
echo "Ako 'which codex' ne pokazuje ništa, dodaj u ~/.zshrc ili ~/.bashrc linije:"
echo "  export PNPM_HOME=\"$PNPM_HOME\""
echo "  export PATH=\"\$PNPM_HOME:\$PATH\""

echo
echo "=== Gotovo. Codex port skripta je završena. ==="

