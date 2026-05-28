# VoltRide EV — Blockchain-Powered Supply Chain

> Hyperledger Fabric 2.5 private network for EV component procurement with ZKML proof verification

---

## Project Overview

VoltRide is an electric scooter manufacturer building a trustless supply chain on Hyperledger Fabric. Suppliers submit Zero-Knowledge Machine Learning (ZKML) proofs alongside their quality control data, allowing VoltRide to verify component quality without ever seeing raw supplier data — preserving commercial confidentiality while ensuring integrity on an immutable ledger.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VoltRide Network                        │
│                                                             │
│  ┌──────────────┐   batterychannel   ┌──────────────────┐  │
│  │  BatteryOrg  │◄──────────────────►│                  │  │
│  │  peer0:7051  │                    │   VoltRideOrg    │  │
│  └──────────────┘   motorchannel     │  peerbattery     │  │
│  ┌──────────────┐◄──────────────────►│  :11051          │  │
│  │   MotorOrg   │                    │  peermotor       │  │
│  │  peer0:9051  │   chassischannel   │  :12051          │  │
│  └──────────────┘◄──────────────────►│  peerchassis     │  │
│  ┌──────────────┐                    │  :13051          │  │
│  │  ChassisOrg  │                    └──────────────────┘  │
│  │ peer0:10051  │                                          │
│  └──────────────┘                                          │
│                    ┌─────────────────┐                     │
│                    │  OrdererOrg     │                     │
│                    │  EtcdRaft :7050 │                     │
│                    └─────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Blockchain | Hyperledger Fabric 2.5 |
| Consensus | EtcdRaft (single-node) |
| Smart Contracts | Go (fabric-contract-api-go v1.2.1) |
| Infrastructure | Docker Compose |
| Off-chain Storage | AWS S3 |
| ML Model | ANN (colleague's module) |
| ZK Proofs | ZKML (colleague's module) |
| Frontend | React.js (colleague's module) |
| Backend API | Node.js + Express (in progress) |

---

## Repository Structure

```
VoltRide-Network/
├── chaincode/
│   ├── battery/              # Battery supplier chaincode (Go)
│   ├── motor/                # Motor supplier chaincode (Go)
│   └── chassis/              # Chassis supplier chaincode (Go)
├── config/
│   └── core.yaml             # Fabric peer configuration
├── configtx/
│   ├── configtx.yaml         # Channel profiles and MSP definitions
│   ├── channel-artifacts/    # Genesis block, channel TXs, anchor TXs
│   └── system-genesis-block/
├── docker/
│   ├── docker-compose-ca.yaml       # 5 Fabric CAs
│   └── docker-compose-network.yaml  # Orderer + 6 peers
├── organizations/
│   ├── fabric-ca/               # CA server config per org
│   ├── ordererOrganizations/    # Orderer MSP + TLS certs
│   └── peerOrganizations/       # Peer MSP + TLS certs (all orgs)
├── scripts/
│   └── registerEnroll.sh        # CA enrollment script
├── ledger/                      # Runtime ledger data (gitignored)
├── deploy-and-test.sh           # One-shot deploy script
└── README.md
```

---

## Prerequisites

### 1. Docker
```bash
# Ubuntu
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Hyperledger Fabric Binaries
```bash
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.5
echo 'export PATH=$PATH:$HOME/fabric-samples/bin' >> ~/.bashrc
source ~/.bashrc
peer version   # should show: hyperledger fabric 2.5.x
```

### 3. Required Docker Images
```bash
docker pull hyperledger/fabric-peer:2.5
docker pull hyperledger/fabric-orderer:2.5
docker pull hyperledger/fabric-ca:latest
docker pull hyperledger/fabric-ccenv:2.5
docker pull hyperledger/fabric-baseos:2.5
```

### 4. Go (only needed if modifying chaincode)
```bash
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version
```

---

## Quick Start

### Step 1 — Clone
```bash
git clone https://github.com/vrd-cse/VoltRide_project.git
cd VoltRide_project
```

### Step 2 — Add DNS entries (CRITICAL — do not skip)
Chaincode containers need to resolve peer hostnames via the host machine.
Without this, every chaincode call will fail with a DNS error.
```bash
sudo bash -c 'cat >> /etc/hosts << EOF
127.0.0.1 peer0.battery.example.com
127.0.0.1 peer0.motor.example.com
127.0.0.1 peer0.chassis.example.com
127.0.0.1 peerbattery.voltride.example.com
127.0.0.1 peermotor.voltride.example.com
127.0.0.1 peerchassis.voltride.example.com
127.0.0.1 orderer0.example.com
EOF'
```

### Step 3 — Start CAs
```bash
docker compose -f docker/docker-compose-ca.yaml up -d
sleep 5
docker ps | grep ca_   # 5 CA containers should show Up
```

### Step 4 — Start Network
```bash
docker compose -f docker/docker-compose-network.yaml up -d
sleep 10
docker ps --format "table {{.Names}}\t{{.Status}}"
# Expected: 7 containers Up — orderer + 6 peers
```

### Step 5 — Deploy Everything
```bash
chmod +x deploy-and-test.sh
./deploy-and-test.sh 2>&1 | tee deploy-output.txt
```

This single script handles channel creation, peer joins, anchor peers, chaincode install, approve, commit, and smoke test.

**Success looks like:**
```
=============================================
 BLOCKCHAIN LAYER COMPLETE - ALL TESTS DONE
=============================================
```

---

## Order Lifecycle

```
VoltRide creates order
        │
        ▼
    [PENDING]
        │
        ├──── CancelOrder (VoltRide) ────► [CANCELLED]
        │
        ▼
Supplier fulfills with QC + ZK proof
        │
        ▼
    [FULFILLED]
        │
        ├──── VerifyAndAccept (VoltRide) ─► [ACCEPTED]
        │
        └──── RejectOrder (VoltRide) ─────► [REJECTED]
```

---

## ZKML Integration Flow

```
Supplier                    Blockchain              VoltRide
   │                            │                      │
   ├── measure 6 QC params      │                      │
   ├── upload raw data → S3     │                      │
   ├── compute SHA-256 hash     │                      │
   ├── run ZKML prover          │                      │
   ├── generate ZK proof        │                      │
   │                            │                      │
   ├── FulfillOrder ───────────►│                      │
   │   (QC params + hash +      │                      │
   │    ZK proof)               │◄── fetch proof ──────┤
   │                            │                      ├── run ZK verifier
   │                            │                      │   off-chain
   │                            │◄── VerifyAndAccept ──┤ (proof valid)
   │                            │◄── RejectOrder ──────┤ (proof invalid)
```

---

## QC Parameters Reference

### Battery (`batterychannel`)
| Parameter | Unit | Valid Range |
|---|---|---|
| nominalVoltage | V | 2.5 – 4.5 |
| internalResistance | mΩ | 0 – 500 |
| capacity | Ah | 1 – 500 |
| soh | % | 0 – 100 |
| selfDischargeRate | %/month | 0 – 10 |
| temperatureAtDelivery | °C | -40 – 85 |

### Motor (`motorchannel`)
| Parameter | Unit | Valid Range |
|---|---|---|
| ratedPower | kW | 0.1 – 100 |
| noLoadRpm | RPM | 100 – 20000 |
| phaseWindingResistance | Ω | 0.001 – 50 |
| torqueOutput | Nm | 0.1 – 500 |
| hallSensorOutput | V | 0 – 12 |
| efficiency | % | 0 – 100 |

### Chassis (`chassischannel`)
| Parameter | Unit | Valid Range |
|---|---|---|
| weldQuality | score | 0 – 100 |
| frameWeight | kg | 1 – 100 |
| dimensionalAccuracy | mm | 0 – 50 |
| materialGrade | string | non-empty |
| surfaceDefectCount | count | ≥ 0 |
| loadBearingCapacity | kg | 1 – 5000 |

---

## Chaincode API

### FulfillOrder — key call for ZKML integration
```json
{
  "function": "FulfillOrder",
  "Args": [
    "BAT-001",
    "BATCH-2024-001",
    "{\"nominalVoltage\":3.7,\"internalResistance\":25.0,\"capacity\":50.0,\"soh\":95.0,\"selfDischargeRate\":2.0,\"temperatureAtDelivery\":25.0}",
    "sha256_hex_of_s3_file",
    "base64_encoded_zk_proof"
  ]
}
```

### Full Function Reference
| Function | Caller | Transition |
|---|---|---|
| CreateOrder | VoltRideMSP | → PENDING |
| FulfillOrder | SupplierMSP | PENDING → FULFILLED |
| VerifyAndAccept | VoltRideMSP | FULFILLED → ACCEPTED |
| RejectOrder | VoltRideMSP | FULFILLED → REJECTED |
| CancelOrder | VoltRideMSP | PENDING → CANCELLED |
| GetOrder | Anyone | read only |
| GetAllOrders | Anyone | read only |
| GetOrderHistory | Anyone | full audit trail |

---

## Network Management

### Stop (preserves ledger state)
```bash
docker compose -f docker/docker-compose-network.yaml down
docker compose -f docker/docker-compose-ca.yaml down
```

### Restart without redeploying
```bash
docker compose -f docker/docker-compose-ca.yaml up -d
docker compose -f docker/docker-compose-network.yaml up -d
```

### Full wipe and redeploy from scratch
```bash
docker compose -f docker/docker-compose-network.yaml down
sudo rm -rf ledger/orderer0/* ledger/peer0.battery/* ledger/peer0.motor/* ledger/peer0.chassis/*
sudo rm -rf ledger/peerbattery.voltride/* ledger/peermotor.voltride/* ledger/peerchassis.voltride/*
docker compose -f docker/docker-compose-network.yaml up -d
sleep 10
./deploy-and-test.sh
```

---

## Port Reference

| Container | Peer Port | Chaincode Port |
|---|---|---|
| orderer0.example.com | 7050 | — |
| peer0.battery.example.com | 7051 | 7052 |
| peer0.motor.example.com | 9051 | 9052 |
| peer0.chassis.example.com | 10051 | 10052 |
| peerbattery.voltride.example.com | 11051 | 11052 |
| peermotor.voltride.example.com | 12051 | 12052 |
| peerchassis.voltride.example.com | 13051 | 13052 |

---

## Troubleshooting

**Chaincode exits with code 2**
DNS resolution failing inside chaincode container. Verify `/etc/hosts` has all 7 entries from Step 2.

**Orderer crashes on startup**
```bash
sudo rm -rf ledger/orderer0/*
docker compose -f docker/docker-compose-network.yaml restart orderer0.example.com
```

**"sequence must be N" on approve/commit**
```bash
export FABRIC_CFG_PATH=$PWD/config
export CORE_PEER_TLS_ENABLED=true
ORDERER_CA=$PWD/organizations/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/ca.crt
peer lifecycle chaincode querycommitted -C batterychannel -n battery --tls --cafile $ORDERER_CA
# Use returned sequence + 1 in your next approve/commit
```

**"ledger already exists" on channel create**
Peers already have ledger data — skip channel creation, proceed directly to chaincode install.

**Permission denied on git add**
```bash
sudo find organizations/ -type d -exec chmod 755 {} \;
sudo find organizations/ -type f -exec chmod 644 {} \;
```

---

## Team

| Module | Owner |
|---|---|
| Hyperledger Fabric Network | @vrd-cse |
| AWS S3 Off-chain Storage | @vrd-cse |
| Node.js REST API | Colleague |
| React.js Frontend | Colleague |
| ANN Model + ZKML Prover | Colleague |
| ZK Verifier Integration | Both |

---

*VoltRide EV Project — BIT Mesra, 2026*
