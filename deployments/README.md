# kToken Deployment System

This directory contains the deployment configuration and output management system for the kToken project, implementing a **hub-and-spoke architecture** for cross-chain token operations.

## Architecture Overview

### Hub-and-Spoke Model
- **Mainnet (Hub)**: Uses existing `kToken` + new `kOFTAdapter` for locking/releasing tokens
- **Other EVM chains (Spokes)**: Use `kToken0` + `kOFT` for burning/minting between chains

### Token Flow
1. **Lock on Hub**: Users lock tokens on mainnet via kOFTAdapter
2. **Mint on Spoke**: Tokens are minted on spoke chains via kOFT
3. **Burn on Spoke**: Users burn tokens on spoke chains via kOFT
4. **Release on Hub**: Tokens are released on mainnet via kOFTAdapter

## Directory Structure

```
deployments/
├── config/           # Network configuration files
│   ├── localhost.json
│   ├── sepolia.json
│   ├── mainnet.json      # Hub deployment
│   ├── polygon.json      # Spoke deployment
│   └── arbitrum.json     # Spoke deployment
├── output/           # Deployment output files (auto-generated)
│   └── {network}/
│       └── addresses.json
└── README.md
```

## Configuration Files

Each network configuration file contains:

- **network**: Network name
- **chainId**: Chain ID for the network
- **deploymentType**: Either "hub" or "spoke"
- **roles**: Address configuration for different roles
  - `owner`: Contract owner
  - `admin`: Admin role holder
  - `emergencyAdmin`: Emergency admin role holder
- **layerZero**: LayerZero configuration
  - `lzEndpoint`: LayerZero endpoint address
  - `lzEid`: LayerZero endpoint ID

## Usage

### 1. Set Up Environment Variables

Copy the environment example file and configure your RPC URLs and addresses:

```bash
# Copy environment template
cp deployments/env.example .env

# Edit with your values
nano .env
```

Set your RPC URLs and addresses:
```bash
# RPC URLs
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_ARBITRUM=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_OPTIMISM=https://opt-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# Addresses for each network
OWNER_MAINNET=0xYourMainnetOwnerAddress
ADMIN_MAINNET=0xYourMainnetAdminAddress
EMERGENCY_ADMIN_MAINNET=0xYourMainnetEmergencyAdminAddress
```

### 2. Configure Network Settings

Edit the appropriate configuration file in `deployments/config/` for your target network:

```json
{
  "network": "sepolia",
  "chainId": 11155111,
  "deploymentType": "spoke",
  "roles": {
    "owner": "0xYourOwnerAddress",
    "admin": "0xYourAdminAddress",
    "emergencyAdmin": "0xYourEmergencyAdminAddress"
  },
  "layerZero": {
    "lzEndpoint": "0x6EDCE65403992e310A62460808c4b910D972f10f",
    "lzEid": 40161
  }
}
```

### 3. Deploy Contracts

#### Using Makefile (Recommended)
```bash
# Deploy kOFTAdapter to mainnet (using existing kToken)
make deploy-hub

# Deploy spokes to other chains
make deploy-spoke CHAIN=polygon
make deploy-spoke CHAIN=arbitrum
make deploy-spoke CHAIN=optimism
make deploy-spoke CHAIN=optimism-sepolia
make deploy-spoke CHAIN=bsc
make deploy-spoke CHAIN=avalanche
make deploy-spoke CHAIN=sepolia
make deploy-spoke CHAIN=localhost

# Or use convenience targets
make deploy-polygon
make deploy-arbitrum
make deploy-optimism
make deploy-optimism-sepolia
make deploy-bsc
make deploy-avalanche
make deploy-sepolia
make deploy-localhost

# Show help
make help
```

#### Using Deployment Script
```bash
# Make script executable
chmod +x scripts/deploy.sh

# Deploy to specific chains
./scripts/deploy.sh mainnet
./scripts/deploy.sh polygon
./scripts/deploy.sh localhost
```

#### Manual Deployment (Advanced)
```bash
# Deploy kOFTAdapter for mainnet (using existing kToken)
forge script script/DeployMainnetAdapter.s.sol --rpc-url $RPC_MAINNET --broadcast --verify

# Deploy kToken0 + kOFT for Polygon
forge script script/DeploySpoke.s.sol --rpc-url $RPC_POLYGON --broadcast --verify
```

#### Legacy Individual Deployments
```bash
# Deploy kToken0 first
forge script script/DeployKToken.s.sol --rpc-url <RPC_URL> --broadcast --verify

# Deploy kOFT (requires kToken0)
forge script script/DeployKOFT.s.sol --rpc-url <RPC_URL> --broadcast --verify

# Deploy kOFTAdapter (requires kToken0)
forge script script/DeployKOFTAdapter.s.sol --rpc-url <RPC_URL> --broadcast --verify
```

### 4. Deployment Output

After deployment, contract addresses are automatically saved to:
`deployments/output/{network}/addresses.json`

Example output:
```json
{
  "chainId": 11155111,
  "network": "sepolia",
  "timestamp": 1703123456,
  "contracts": {
    "kToken0": "0x1234567890123456789012345678901234567890",
    "kOFT": "0x2345678901234567890123456789012345678901",
    "kOFTAdapter": "0x3456789012345678901234567890123456789012",
    "kOFTImplementation": "0x4567890123456789012345678901234567890123",
    "kOFTAdapterImplementation": "0x5678901234567890123456789012345678901234"
  }
}
```

## Features

### Automatic Address Management
- Contract addresses are automatically saved to JSON files
- Previous deployments are read to enable incremental deployments
- Network-specific configuration prevents cross-chain deployment errors

### Role Management
- Automatic MINTER_ROLE management:
  - kOFT is granted MINTER_ROLE on kToken0
  - Owner's MINTER_ROLE is automatically revoked after kOFT deployment
- Role validation ensures all required addresses are configured

### Network Support
- Ethereum Mainnet
- Sepolia Testnet
- Polygon
- Arbitrum
- Optimism
- BSC
- Fantom
- Avalanche
- Localhost (for testing)

## Security Features

### MINTER_ROLE Management
The deployment system automatically handles MINTER_ROLE transitions:

1. **kToken0 Deployment**: Owner receives MINTER_ROLE temporarily
2. **kOFT Deployment**: kOFT receives MINTER_ROLE, owner's role is revoked
3. **Verification**: Only kOFT can mint/burn tokens after deployment

This ensures that only the kOFT contract can mint/burn tokens, removing the owner's minting privileges for security.

### Configuration Validation
- All required addresses must be non-zero
- LayerZero configuration is validated
- Network-specific settings prevent misconfigurations

## Environment Variables

The deployment system can use environment variables for sensitive configuration:

```bash
export PRODUCTION=true  # Enable production mode
```

## Troubleshooting

### Common Issues

1. **Config file not found**: Ensure the configuration file exists in `deployments/config/{network}.json`
2. **Missing addresses**: Check that all required addresses are configured in the network config
3. **Role management errors**: Ensure the deployer has the necessary permissions to grant/revoke roles

### Validation Errors

The system validates:
- All role addresses are non-zero
- LayerZero endpoint is configured
- Previous deployments exist when required
- Network configuration matches the current chain

## Example Deployment Commands

### Using Makefile (Recommended)
```bash
# Deploy kOFTAdapter on mainnet (using existing kToken)
make deploy-mainnet

# Deploy spokes on other chains
make deploy-polygon
make deploy-arbitrum
make deploy-optimism
make deploy-bsc
make deploy-avalanche

# Deploy to testnets
make deploy-sepolia
make deploy-localhost

# Deploy to all networks
make deploy-all

# Check deployment status
make status

# Show help
make help
```

### Using Deployment Script
```bash
# Make script executable
chmod +x scripts/deploy.sh

# Deploy to specific chains
./scripts/deploy.sh mainnet
./scripts/deploy.sh polygon
./scripts/deploy.sh localhost
```

### Manual Deployment (Advanced)
```bash
# Deploy kOFTAdapter on mainnet (using existing kToken)
forge script script/DeployMainnetAdapter.s.sol --rpc-url $RPC_MAINNET --broadcast --verify

# Deploy spoke on Polygon
forge script script/DeploySpoke.s.sol --rpc-url $RPC_POLYGON --broadcast --verify

# Deploy spoke on localhost
forge script script/DeploySpoke.s.sol --rpc-url http://localhost:8545 --broadcast
```
