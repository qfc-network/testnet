# QFC Testnet

Join the QFC (Quantum-Flux Chain) public testnet.

## Network Info

| Item | Value |
|------|-------|
| Chain ID | `9000` |
| RPC | `https://rpc.testnet.qfc.network` |
| WebSocket | `wss://rpc.testnet.qfc.network/ws` |
| Explorer | `https://explorer.testnet.qfc.network` |
| Faucet | `https://faucet.testnet.qfc.network` |
| Block Time | ~3 seconds |
| Consensus | Proof of Contribution (PoC) |

## Quick Start (Docker)

```bash
# Download config files
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/docker-compose.yml
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/genesis.json

# Start a full node
docker compose up -d

# Check logs
docker logs -f qfc-node
```

That's it. Your node will connect to the bootnode and start syncing.

### Mining (optional)

Contribute compute power and earn the **20% compute contribution** score in PoC:

```bash
QFC_MINING_ENABLED=true QFC_MINING_THREADS=4 docker compose up -d
```

### Validator (requires stake)

Run a validator node (requires 10,000+ QFC staked):

```bash
QFC_VALIDATOR_KEY=<your-secret-key-hex> QFC_MINING_ENABLED=true docker compose up -d
```

## Build from Source

```bash
git clone https://github.com/qfc-network/qfc-core.git
cd qfc-core
cargo build --release

# Run full node
./target/release/qfc-node \
  --datadir ./data \
  --bootnodes "/ip4/bootnode.testnet.qfc.network/tcp/30303/p2p/<PEER_ID>"

# With mining
./target/release/qfc-node \
  --datadir ./data \
  --bootnodes "/ip4/bootnode.testnet.qfc.network/tcp/30303/p2p/<PEER_ID>" \
  --mine --threads 4
```

## Get Test Tokens

Visit the [Faucet](https://faucet.testnet.qfc.network) to get **100 QFC** (24h cooldown).

## Add to MetaMask

| Field | Value |
|-------|-------|
| Network Name | QFC Testnet |
| RPC URL | `https://rpc.testnet.qfc.network` |
| Chain ID | `9000` |
| Symbol | `QFC` |
| Explorer | `https://explorer.testnet.qfc.network` |

## Verify Your Node

```bash
# Current block height
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Node info & peer count
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"qfc_nodeInfo","params":[],"id":1}'
```

## Become a Validator

1. Get 10,000+ QFC from the faucet or community
2. Generate a validator key: `./target/release/qfc-node keygen`
3. Stake your QFC via the staking RPC
4. Start with `QFC_VALIDATOR_KEY=<key> QFC_MINING_ENABLED=true docker compose up -d`

## PoC Contribution Scores

Your validator priority is determined by 7 dimensions:

| Dimension | Weight | How to Earn |
|-----------|--------|-------------|
| Staking | 30% | Stake more QFC |
| Compute | 20% | Enable mining (`--mine`) |
| Uptime | 15% | Keep your node online |
| Accuracy | 15% | Don't miss assigned blocks |
| Network | 10% | Good P2P connectivity |
| Storage | 5% | Serve state snapshots |
| Reputation | 5% | Long-term honest behavior |

## Hardware Requirements

| Role | CPU | RAM | Disk | Network |
|------|-----|-----|------|---------|
| Full node | 2 cores | 4 GB | 50 GB SSD | 10 Mbps |
| Mining node | 4+ cores | 4 GB | 50 GB SSD | 10 Mbps |
| Validator | 4 cores | 8 GB | 100 GB SSD | 50 Mbps |

## Troubleshooting

**Node not syncing?**
- Check port `30303` is open (firewall / security group)
- Verify genesis.json matches (re-download if unsure)

**Reset node data:**
```bash
docker compose down -v
docker compose up -d
```

**Update to latest:**
```bash
docker compose pull
docker compose up -d
```

## Links

- [QFC Core](https://github.com/qfc-network/qfc-core) — Blockchain source code
- [Explorer](https://explorer.testnet.qfc.network) — Block explorer
- [Faucet](https://faucet.testnet.qfc.network) — Get test tokens
