# Mintly Token Platform

## Overview
Mintly is a comprehensive fungible token platform built on the Stacks blockchain using Clarity smart contracts. It provides advanced token functionality including minting, burning, transfers, governance features, and token freezing capabilities.

## Features
- **Core Token Operations**
  - Custom token creation with defined properties
  - Minting and burning mechanisms
  - Secure transfer functions
  - Delegated spending through allowances

- **Governance System**
  - Token-based voting power
  - Automatic voting power adjustments
  - Transparent governance tracking

- **Advanced Features**
  - Token freezing/unfreezing capability
  - Detailed error handling
  - Owner-controlled administrative functions
  - Built-in decimals support (6 decimals)

## Token Details
- **Name**: Mintly Token
- **Symbol**: MNTLY
- **Decimals**: 6
- **Contract Owner**: Set at deployment

## Smart Contract Functions

### Read-Only Functions
```clarity
(get-name) -> (response string)
(get-symbol) -> (response string)
(get-decimals) -> (response uint)
(get-balance (account principal)) -> (response uint)
(get-allowance (owner principal) (spender principal)) -> (response uint)
```

### Public Functions
```clarity
(mint (amount uint) (recipient principal)) -> (response bool)
(transfer (amount uint) (recipient principal)) -> (response bool)
(approve (amount uint) (spender principal)) -> (response bool)
(transfer-from (amount uint) (owner principal) (recipient principal)) -> (response bool)
(burn (amount uint)) -> (response bool)
(freeze-tokens (amount uint)) -> (response bool)
(unfreeze-tokens (amount uint)) -> (response bool)
```

## Error Codes
- `ERR-NOT-AUTHORIZED (u100)`: Operation requires authorization
- `ERR-INSUFFICIENT-BALANCE (u101)`: Insufficient token balance
- `ERR-INVALID-AMOUNT (u102)`: Invalid token amount specified

## Installation & Deployment

### Prerequisites
- Stacks CLI tools installed
- A Stacks wallet with sufficient STX for deployment
- Node.js and NPM (for development environment)

### Deployment Steps
1. Clone the repository:
```bash
git clone https://github.com/your-username/mintly.git
cd mintly
```

2. Install dependencies:
```bash
npm install
```

3. Deploy the contract:
```bash
stacks deploy --network mainnet mintly-token.clar
```

## Usage Examples

### Minting Tokens
```clarity
;; Only contract owner can mint
(contract-call? .mintly mint u1000000 'SPAB...DRESS)
```

### Transferring Tokens
```clarity
;; Transfer tokens to another address
(contract-call? .mintly transfer u500000 'SP2B...DRESS)
```

### Freezing Tokens
```clarity
;; Freeze tokens
(contract-call? .mintly freeze-tokens u100000)
```

## Development

### Local Testing
1. Install Clarinet:
```bash
curl -L https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64.tar.gz | tar xz
```

2. Run tests:
```bash
clarinet test
```

### Security Considerations
- Always verify transaction signatures
- Check token balances before transfers
- Validate input parameters
- Use appropriate error handling

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request


## Acknowledgments
- Stacks Foundation
- Clarity Language Documentation
- Community Contributors
