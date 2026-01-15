# Xero Protocol

> Privacy-Enhanced P2P Lending & Borrowing Marketplace on Mantle Network

**Xero Protocol** is a decentralized, trustless, and oracle-less peer-to-peer lending marketplace that combines **optional privacy**, **universal asset collateral** (including RWAs), and **cross-chain support** into a seamless DeFi experience on Mantle Network.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Mantle](https://img.shields.io/badge/Built%20on-Mantle-blue)](https://www.mantle.xyz/)
[![Testnet](https://img.shields.io/badge/Testnet-Live-green)](https://sepolia.mantlescan.xyz/)

---

## 🌟 Overview

Xero Protocol redefines P2P lending by giving users complete control over their financial privacy while supporting:

- **🔒 Optional Privacy** - Choose what to reveal using zero-knowledge proofs
- **💎 Universal Collateral** - ERC-20, NFTs, RWAs (OUSG, XAUM), or multi-asset bundles
- **🌉 Cross-Chain Support** - Use Ethereum mainnet assets as collateral on Mantle
- **⚡ No Liquidations** - Pre-agreed collateral terms eliminate cascade risks
- **🏆 On-Chain Reputation** - Build verifiable credit with ZK proofs
- **🎯 Custom Terms** - Fully flexible interest rates, durations, and conditions

## Mantle Testnet Deployments

```

      "FeeDistributor": "0xc7bB407B7c3b888efc63A94B449a97cEE55c0ccC"
      "Governance": "0x43374Eaca1d4C015E528E3AAF43Ccf305195644b",
      "ReputationRegistry": "0x524B6cC09696709Cd6D798A7F54519cD9db8c02c",
      "PrivacyModule": "0x2a1b190C16Cf7e607C5B302d156e6003558F0C39",
      "LoanCore": "0xEF8dc620694039fc80B60caF0Ee42a67b8505592",
      "OfferBook": "0xa5765B5161d1D913407376a975DBF63Eb74e2365"
```


    

---

## 🏗️ Architecture

```
xero-protocol/
├── contracts/              # Solidity smart contracts
│   ├── LoanCore.sol       # Main lending logic
│   ├── OfferBook.sol      # Order matching system
│   ├── PrivacyModule.sol  # ZK proof verification
│   ├── CrossChainBridge.sol # Ethereum ↔ Mantle bridge
│   ├── ReputationRegistry.sol # Credit scoring
│   └── ...
├── frontend/              # Next.js web app
│   ├── app/
│   ├── hooks/
│   ├── config/
│   └── providers/
├── privacy-service/       # SP1 ZK proof backend
│   ├── src/
│   ├── sp1-programs/
│   └── ...
└── scripts/               # Deployment & testing
```

---

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Hardhat
- Rust (for SP1 programs)
- Redis (for proof service)

### 1. Clone Repository

```bash
git clone https://github.com/uncletom29/xerolend.git
cd xerolend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env`:
```env
PRIVATE_KEY=your_private_key
RPC_URL=https://rpc.sepolia.mantle.xyz
NETWORK_NAME=mantle-testnet
ETHERSCAN_API_KEY=your_mantlescan_key
```

### 4. Deploy Contracts

```bash
# Compile contracts
npx hardhat compile

# Deploy to Mantle Sepolia
npx hardhat run scripts/deploy-contracts-simplified.js --network mantle-sepolia

# Setup test wallets
npx hardhat run scripts/setup-test-wallets.js --network mantle-sepolia

# Populate with sample data
npx hardhat run scripts/populate-data-simplified.js --network mantle-sepolia

# Verify on Mantlescan
npx hardhat run scripts/verify-contracts.js --network mantle-sepolia
```

### 5. Run Frontend

```bash
cd frontend
npm install
npm run dev
```

Visit `http://localhost:3000`

### 6. Run Privacy Service (Optional)

```bash
cd privacy-service
npm install

# Start Redis
redis-server

# Build SP1 programs
cd sp1-programs
./build-all.sh

# Start service
npm start
```

---

## 💡 Core Features

### 1. **Optional Privacy Mode**

Users can create loans in two modes:

**Public Mode** (Default):
- Fully transparent on-chain
- All terms visible
- Build public reputation

**Private Mode** (ZK-enabled):
- Loan amounts encrypted
- Collateral values hidden
- Interest rates confidential
- Reputation provable without disclosure

```solidity
// Create private loan
await loanCore.createLoanERC20(
  principalToken,
  principalAmount,
  interestRate,
  duration,
  collateralToken,
  collateralAmount,
  true,              // isPrivate = true
  privacyCommitment  // ZK commitment
);
```

### 2. **Universal Collateral Support**

Accept any tokenized asset:

- **Stablecoins**: USDC, DAI, USDT
- **Crypto**: WETH, WBTC, LINK, MNT
- **RWAs**: OUSG (US Treasuries), XAUM (Gold)
- **NFTs**: BAYC, Punks, any ERC-721
- **Bundles**: Combine multiple assets

Lower collateral ratios for stable RWAs (120% vs 150%)!

### 3. **Cross-Chain Collateral**

Use Ethereum mainnet NFTs and RWAs as collateral on Mantle:

```solidity
// Lock NFT on Ethereum, borrow on Mantle
await loanCore.createLoanCrossChain(
  principalToken,
  principalAmount,
  interestRate,
  duration,
  ethereumNFTAddress,
  tokenId,
  lockProofFromEthereum
);
```

### 4. **Advanced Offer Matching**

Smart order book with complex filters:

```javascript
// Find RWA-accepting lenders
const offers = await offerBook.findMatchingOffers(
  OfferType.Lend,
  USDC,
  10000,
  12%, // max rate
  userReputation,
  hasRWA: true,
  isCrossChain: false
);
```

### 5. **On-Chain Reputation**

Build credit without revealing history:

```javascript
// Prove reputation privately
const proof = await privacyService.generateProof('reputation', {
  userScore: 850,
  threshold: 700,
  nullifier: uniqueId,
  loanHistory: encryptedHistory
});

await reputationRegistry.verifyReputationProof(commitment, proof);
```

---

## 📊 Supported Assets

### Stablecoins
- USDC, DAI, USDT

### Crypto Assets
- WETH, WBTC, LINK
- MNT, METH, CMETH, WMNT

### Real World Assets (RWAs)
- **OUSG** - Ondo US Government Treasuries (~$1.00, 5.2% APY)
- **XAUM** - Matrixdock Gold (~$70/g, physically redeemable)

### NFTs
- BAYC, CryptoPunks
- Any ERC-721/ERC-1155

---

## 🔐 Privacy Technology

Powered by **Succinct's SP1** zkVM for efficient ZK proofs:

### Proof Types

1. **Collateral Value Proof**
   - Prove collateral > minimum without revealing exact amount

2. **Loan Amount Proof**
   - Prove amount within range without disclosure

3. **Reputation Proof**
   - Prove credit score > threshold with nullifiers

### Privacy Service API

```typescript
POST /api/proofs/generate
{
  "proofType": "collateral",
  "inputs": {
    "publicInputs": {
      "commitment": "0x...",
      "minValue": "15000"
    },
    "privateInputs": {
      "collateralValue": "20000",
      "salt": "random_salt"
    }
  }
}
```


## 🛣️ Roadmap

### ✅ Phase 1 (Complete)
- Core lending contracts
- Privacy module with SP1
- web app
- RWA integration (OUSG, XAUM)
- Cross-chain bridge
- Advanced matching engine
- Incentivized testnet

### 📅 Phase 2 - Q1 2026
- Mainnet launch
- Governance token launch
- Mobile app
- Institutional upgrades

---

## 🏆 Hackathon Submission

**Mantle Network Hackathon**

**Tracks:**
- ✅ RWA/RealFi Track
- ✅ DeFi & Composability Track
- ✅ ZK & Privacy Track
- ✅ Best Mantle Integration
- ✅ Best UX / Demo

**Key Innovations:**
1. First P2P lending protocol with **optional** privacy
2. Native RWA support (OUSG, XAUM) with lower collateral ratios
3. Cross-chain collateral (Ethereum ↔ Mantle)
4. No liquidations - pre-agreed collateral terms
5. SP1-powered ZK proofs for privacy
6. Advanced offer matching with complex filters


## 📄 License

MIT License - see [LICENSE](./LICENSE)

---

## 🔗 Links

- **Website**: https://mantle.xeroprotocol.com

**Built with ❤️ on Mantle Network**

*Privacy is a right, not a luxury.*