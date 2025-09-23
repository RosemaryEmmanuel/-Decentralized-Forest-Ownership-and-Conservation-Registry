A Clarity smart contract that tokenizes forest plots as NFTs and enables transparent conservation tracking through verifiable milestones and reward incentives.

## 🔥 Problem

- Forest lands are mismanaged or illegally sold
- No transparent record of forest ownership or reforestation efforts
- Lack of incentives for conservation efforts

## ✅ Solution

A blockchain-based registry that:
- 🏷️ Tokenizes forest plots as NFTs
- 📋 Links NFTs to conservation commitments
- 💰 Enables micro-investments into forest preservation
- 🎯 Enforces milestones through smart contracts

## ⚙️ Key Features

- 🎨 **NFT Ownership**: Each forest plot is an NFT tied to conservation contracts
- 🌱 **Milestone Tracking**: Reforestation and preservation milestones enforced by smart contracts
- 🛒 **Marketplace**: Trading system for forest conservation rights
- 🏆 **Token Rewards**: Incentives for verified tree planting and conservation efforts

## 🚀 Usage

### Register a Forest Plot
```clarity
(contract-call? .forest-registry register-forest-plot 
  "Amazon Rainforest Sector 42" 
  u100 
  "Preservation")
```

### Add Conservation Milestone
```clarity
(contract-call? .forest-registry add-conservation-milestone 
  u1 
  "Plant 500 native trees" 
  u1000000 
  "Satellite imagery verification" 
  u50)
```

### List Plot for Sale
```clarity
(contract-call? .forest-registry list-for-sale u1 u1000000)
```

### Buy Forest NFT
```clarity
(contract-call? .forest-registry buy-forest-nft u1)
```

### Verify Milestone (Owner Only)
```clarity
(contract-call? .forest-registry verify-milestone u1 u0)
```

## 📊 Read-Only Functions

- `get-forest-plot` - Get plot details
- `get-milestone` - Get milestone information  
- `get-conservation-progress` - View completion rates
- `get-listing` - Check marketplace listings
- `get-token-balance` - View reward token balance

## 🔧 Contract Structure

### Data Maps
- **forest-plots**: Store NFT metadata and conservation data
- **conservation-milestones**: Track individual milestones per plot
- **marketplace-listings**: Handle NFT sales
- **token-balances**: Manage reward tokens

### Error Codes
- `u100`: Owner only operation
- `u101`: Not token owner
- `u102`: Token not found
- `u103`: Not listed for sale
- `u104`: Insufficient funds
- `u105`: Milestone not met
- `u106`: Already verified
- `u107`: Invalid milestone

## 🏗️ Development

### Prerequisites
- Clarinet CLI installed
- Node.js for testing

### Setup
```bash
clarinet new forest-registry
cd forest-registry
# Copy contract code to contracts/
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 🌍 Conservation Impact

This registry enables:
- **Transparent Ownership**: Immutable records of forest ownership
- **Verified Conservation**: Milestone-based proof of environmental impact
- **Economic Incentives**: Token rewards for conservation efforts
- **Global Trading**: Marketplace for conservation rights
- **Micro-investments**: Small-scale forest preservation funding

## 📝 License

MIT License - Feel free to contribute to forest conservation! 🌲

---

*Building a sustainable future, one tokenized forest at a time* 🌳✨

## 🆕 New Feature: Forest Plot Leasing

- 🏠 **Plot Leasing**: Owners can lease their forest plots for temporary access, enabling short-term conservation activities, research, or eco-tourism.
- 💸 **Rental Revenue**: Earn STX fees from leasing, providing additional incentives for plot ownership and maintenance.
- ⏳ **Time-Based Access**: Flexible duration-based rentals with automatic expiration and secure on-chain tracking.

### Lease a Forest Plot
```clarity
(contract-call? .forest-registry offer-lease 
  u1 
  u1440 
  u50000)
```

### Rent an Available Lease
```clarity
(contract-call? .forest-registry rent-plot u1)
```

### End Lease (Owner or Auto-Expire)
```clarity
(contract-call? .forest-registry end-lease u1)
```

## 📊 Updated Read-Only Functions

- `get-lease` - Retrieve lease details for a plot

## 🔧 Updated Contract Structure

### Data Maps
- **plot-leases**: Track leasing information including lessor, lessee, duration, fee, and start time

### Error Codes
- `u111`: Lease not found
- `u112`: Lease already active
- `u113`: Invalid duration
- `u114`: Not authorized to end lease

## 🌍 Enhanced Conservation Impact

This leasing feature expands the platform's reach by:
- **Temporary Access**: Facilitate research and monitoring without permanent transfers
- **Revenue Generation**: Additional funding streams for conservation maintenance
- **Flexible Utilization**: Support diverse use cases from scientific studies to educational visits
- **Community Engagement**: Broader participation in forest stewardship activities

---

*Empowering global conservation through innovative blockchain leasing* 🌿🔗
