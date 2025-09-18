# Obsidian Volcanic Vault Smart Contract

A mystical Clarity smart contract for the Stacks blockchain that manages donation matching rounds through volcanic-themed funding epochs. This contract enables quadratic funding mechanisms where contributions to projects are amplified through matching pools.

## Overview

The Obsidian Volcanic Vault implements a sophisticated donation matching system where:
- **Volcanic Epochs** represent funding rounds with time-bounded donation periods
- **Obsidian Shrines** represent projects that can receive donations
- **Offerings** are donations made by patrons to shrines during active epochs
- **Amplification** is the matching fund distribution based on proportional allocation

## Key Features

### 🌋 Volcanic Epochs (Funding Rounds)
- Create time-bounded funding rounds with configurable parameters
- Set minimum/maximum donation amounts and patron caps
- Manage amplification pools for matching funds
- Control epoch lifecycle: ignition → burning → extinction → sealing

### 🏛️ Obsidian Shrines (Projects)
- Register projects with custom inscriptions
- Guardian-controlled project management
- Track total offerings and amplified amounts
- Blessing system for epoch participation

### 💎 Offering System (Donations)
- Make donations to blessed shrines during active epochs
- Automatic validation of donation limits and caps
- Proportional amplification calculation
- Harvest amplified funds after epoch completion

### 🔐 Access Control
- Keeper-controlled administrative functions
- Guardian-controlled shrine management
- Patron-controlled offering and harvesting

## Contract Functions

### Administrative Functions (Keeper Only)
- `forge-volcanic-epoch` - Create new funding rounds
- `ignite-epoch` - Start a funding round
- `extinguish-epoch` - End a funding round
- `seal-amplification` - Finalize matching calculations
- `bless-shrine-for-epoch` - Allow projects to participate in rounds

### Public Functions
- `consecrate-shrine` - Register a new project
- `make-offering` - Donate to a project during active rounds
- `harvest-amplified-magma` - Claim matched funds (guardians only)
- `feed-volcanic-reserves` - Add funds to the contract treasury

### Read-Only Functions
- `get-epoch-info` - Retrieve funding round details
- `get-shrine-info` - Get project information
- `get-offering-info` - Check donation details
- `get-vault-stats` - View contract statistics

## Usage Flow

1. **Setup Phase**
   - Deploy contract and call `awaken-vault`
   - Fund the volcanic reserves using `feed-volcanic-reserves`
   - Create projects with `consecrate-shrine`

2. **Funding Round Creation**
   - Forge a new epoch with `forge-volcanic-epoch`
   - Infuse amplification pool with `infuse-amplification-pool`
   - Bless participating shrines with `bless-shrine-for-epoch`

3. **Active Funding**
   - Ignite the epoch with `ignite-epoch`
   - Patrons make offerings using `make-offering`
   - Monitor donations and epoch progress

4. **Round Completion**
   - Extinguish epoch with `extinguish-epoch`
   - Seal amplification calculations with `seal-amplification`
   - Calculate individual amplifications with `calculate-amplification`
   - Guardians harvest matched funds with `harvest-amplified-magma`

## Error Codes

- `ERR-NOT-AUTHORIZED (100)` - Insufficient permissions
- `ERR-INACTIVE-EPOCH (101)` - Epoch not currently active
- `ERR-INSUFFICIENT-MAGMA (102)` - Insufficient contract balance
- `ERR-EXCEEDS-MAX-OFFERING (103)` - Donation exceeds maximum
- `ERR-BELOW-MIN-OFFERING (104)` - Donation below minimum
- `ERR-INVALID-SHRINE (105)` - Invalid or unblessed shrine
- `ERR-PATRON-CAP-REACHED (110)` - Patron donation limit exceeded
- `ERR-ALREADY-HARVESTED (111)` - Funds already claimed

## Security Features

- Time-bounded funding rounds prevent manipulation
- Patron caps limit individual influence
- Guardian-only harvesting prevents fund theft
- Keeper-controlled administrative functions
- Input validation and overflow protection

