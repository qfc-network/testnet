#!/usr/bin/env bash
# QFC Inference Miner — One-click start script
# Provides AI compute to the QFC network and earns rewards.
#
# Usage:
#   ./scripts/start-miner.sh              # First run: generates wallet + starts miner
#   ./scripts/start-miner.sh --status     # Check miner status
#
# Supports: macOS (Intel/Apple Silicon), Linux (x86_64)
# Requirements: Rust toolchain (rustup.rs)

set -euo pipefail

REPO_URL="https://github.com/qfc-network/qfc-core.git"
INSTALL_DIR="${QFC_MINER_DIR:-$HOME/.qfc-miner}"
WALLET_FILE="$INSTALL_DIR/wallet.json"
RPC_URL="${QFC_MINER_RPC_URL:-https://rpc.testnet.qfc.network}"
BINARY="$INSTALL_DIR/qfc-core/target/release/qfc-miner"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Check status ---
if [[ "${1:-}" == "--status" ]]; then
    echo "=== QFC Miner Status ==="
    if [[ -f "$WALLET_FILE" ]]; then
        ADDR=$(grep '"address"' "$WALLET_FILE" | cut -d'"' -f4)
        echo "Wallet: $ADDR"
        echo ""
        echo "Balance:"
        curl -s "$RPC_URL" -X POST -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x$ADDR\",\"latest\"],\"id\":1}" | python3 -m json.tool 2>/dev/null || echo "(RPC unavailable)"
        echo ""
        echo "Node info:"
        curl -s "$RPC_URL" -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"qfc_nodeInfo","params":[],"id":1}' | python3 -m json.tool 2>/dev/null || echo "(RPC unavailable)"
    else
        echo "No wallet found. Run ./scripts/start-miner.sh first."
    fi
    exit 0
fi

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   QFC Inference Miner Setup           ║"
echo "  ║   Earn rewards by providing AI compute║"
echo "  ╚═══════════════════════════════════════╝"
echo ""

# --- Step 1: Check Rust toolchain ---
info "Checking Rust toolchain..."
if ! command -v cargo &>/dev/null; then
    warn "Rust not found. Installing via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi
ok "Rust $(rustc --version | awk '{print $2}')"

# --- Step 2: Detect platform ---
OS=$(uname -s)
ARCH=$(uname -m)
FEATURES="candle"

if [[ "$OS" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        FEATURES="metal,candle"
        ok "Platform: macOS Apple Silicon (Metal GPU)"
    else
        FEATURES="candle"
        ok "Platform: macOS Intel (CPU only)"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v nvidia-smi &>/dev/null; then
        FEATURES="cuda,candle"
        ok "Platform: Linux with NVIDIA GPU (CUDA)"
    else
        FEATURES="candle"
        ok "Platform: Linux (CPU only)"
    fi
else
    err "Unsupported OS: $OS"
fi

# --- Step 3: Clone / update qfc-core ---
mkdir -p "$INSTALL_DIR"

if [[ -d "$INSTALL_DIR/qfc-core" ]]; then
    info "Updating qfc-core..."
    cd "$INSTALL_DIR/qfc-core"
    git pull --ff-only origin main 2>/dev/null || true
else
    info "Cloning qfc-core (this may take a minute)..."
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR/qfc-core"
    cd "$INSTALL_DIR/qfc-core"
fi

# --- Step 4: Build miner ---
info "Building qfc-miner (features: $FEATURES)..."
info "This may take a few minutes on first build..."
cargo build --release --features "$FEATURES" --bin qfc-miner 2>&1 | tail -3
ok "Build complete: $BINARY"

# --- Step 5: Generate wallet (if needed) ---
if [[ -f "$WALLET_FILE" ]]; then
    ADDR=$(grep '"address"' "$WALLET_FILE" | cut -d'"' -f4)
    KEY=$(grep '"private_key"' "$WALLET_FILE" | cut -d'"' -f4)
    ok "Wallet loaded: $ADDR"
else
    info "Generating new miner wallet..."
    WALLET_OUTPUT=$("$BINARY" --generate-wallet 2>&1)

    # Parse output — format: "Address: <hex>\nPrivate Key: <hex>"
    ADDR=$(echo "$WALLET_OUTPUT" | grep -i "address" | awk '{print $NF}' | tr -d '[:space:]')
    KEY=$(echo "$WALLET_OUTPUT" | grep -i "private" | awk '{print $NF}' | tr -d '[:space:]')

    if [[ -z "$ADDR" || -z "$KEY" ]]; then
        # Fallback: try to parse differently
        ADDR=$(echo "$WALLET_OUTPUT" | head -1 | awk '{print $NF}')
        KEY=$(echo "$WALLET_OUTPUT" | tail -1 | awk '{print $NF}')
    fi

    cat > "$WALLET_FILE" <<EOJSON
{
  "address": "$ADDR",
  "private_key": "$KEY"
}
EOJSON
    chmod 600 "$WALLET_FILE"
    ok "Wallet created: $ADDR"
    ok "Saved to: $WALLET_FILE"
    echo ""
    warn "BACKUP your private key! If lost, your rewards are gone."
    echo ""
fi

# --- Step 6: Request faucet tokens ---
info "Requesting testnet tokens from faucet..."
FAUCET_RESP=$(curl -sf "$RPC_URL" -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"qfc_requestFaucet\",\"params\":[\"0x$ADDR\"],\"id\":1}" 2>/dev/null || echo "")

if echo "$FAUCET_RESP" | grep -q "result"; then
    ok "Faucet tokens received"
elif echo "$FAUCET_RESP" | grep -q "cooldown\|already"; then
    ok "Faucet: already funded (24h cooldown)"
else
    warn "Faucet request failed (node may be unavailable). You can try later."
fi

# --- Step 7: Determine backend ---
BACKEND="cpu"
if [[ "$FEATURES" == *"metal"* ]]; then
    BACKEND="metal"
elif [[ "$FEATURES" == *"cuda"* ]]; then
    BACKEND="cuda"
fi

# --- Step 8: Start miner ---
echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Starting QFC Inference Miner            │"
echo "  │  Wallet:  ${ADDR:0:16}...                │"
echo "  │  Backend: $BACKEND                            │"
echo "  │  RPC:     $RPC_URL   │"
echo "  │                                         │"
echo "  │  Press Ctrl+C to stop                   │"
echo "  └─────────────────────────────────────────┘"
echo ""

exec "$BINARY" \
    --wallet "$ADDR" \
    --private-key "$KEY" \
    --validator-rpc "$RPC_URL" \
    --backend "$BACKEND"
