# kToken Smart Contracts

## Overview

kToken is a cross-chain token system leveraging LayerZero's OFT (Omnichain Fungible Token) standard. The contracts are upgradeable and use robust role-based access control for minting, burning, and upgrades. This repository includes:

- `kToken`: Upgradeable ERC20 token with role-based mint/burn, permit functionality, and UUPS upgradeability.
- `kOFT`: LayerZero OFT implementation for cross-chain abstraction, upgradeable via UUPS.
- Comprehensive testing suite including unit, invariant, and integration tests.

## Directory Structure

```
├── src/                    # Main contract sources
│   ├── interfaces/        # Contract interfaces
│   ├── kToken.sol        # Core token contract
│   └── kOFT.sol         # LayerZero OFT implementation
├── test/
│   ├── unit/            # Unit tests
│   ├── invariant/       # Invariant tests
│   │   ├── handlers/    # Test handlers
│   │   └── *.t.sol     # Invariant test suites
│   ├── fork/           # Fork/integration tests
│   ├── fuzz/           # Fuzz tests
│   └── mocks/          # Mock contracts
└── script/              # Deployment scripts
```

## Testing

The project uses a comprehensive testing approach:

### Unit Tests
```sh
# Run unit tests
forge test --match-contract "kToken|kOFT" --match-path "test/unit/*"
```

### Invariant Tests
The invariant tests are split into logical groups for better organization and maintainability:
- Supply and Balance (`kTokenInvariant_Supply.t.sol`)
- Access Control (`kTokenInvariant_Access.t.sol`)
- Transfer and Allowance (`kTokenInvariant_Transfer.t.sol`)
- State and Metadata (`kTokenInvariant_State.t.sol`)

```sh
# Run all invariant tests
forge test --match-contract "kTokenInvariant"

# Run specific invariant test groups
forge test --match-contract "kTokenInvariantSupplyTest"
forge test --match-contract "kTokenInvariantAccessTest"
forge test --match-contract "kTokenInvariantTransferTest"
forge test --match-contract "kTokenInvariantStateTest"
```

### Integration Tests
```sh
# Run fork tests
forge test --match-path "test/fork/*"
```

## Deployment

kToken contracts can be deployed to various networks using the deployment scripts in the `script/` directory.

### 1. Add Your Private Key Securely

**Do NOT add your private key to `.env` or commit it to version control.**

Instead, create a secure wallet keystore and use it with Foundry's `cast` and `forge` tools.

#### Create a new wallet keystore

```sh
cast wallet import myKeystoreName --interactive
```
- Enter your wallet's private key when prompted.
- Provide a password to encrypt the keystore file.

> ⚠️ **Recommendation:**
> Do not use a private key associated with real funds. Create a new wallet for deployment and testing.

### 2. Deploy the Smart Contracts

Use the keystore you created to sign transactions with `forge script`:

#### Deploy kToken

```sh
forge script script/DeployKToken.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --account myKeystoreName \
  --sender <accountAddress>
```

#### Deploy kOFT

```sh
forge script script/DeployKOFT.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --account myKeystoreName \
  --sender <accountAddress>
```

- `--account myKeystoreName`: Use the keystore you created.
- `--sender <accountAddress>`: The address corresponding to your keystore.

#### Environment Variables

The deployment scripts expect the following environment variables:
- `OWNER`: Address to be set as the contract owner
- `ADMIN`: (kToken) Address to be granted admin roles
- `MINTER`: (kToken) Address to be granted minter role
- `LZ_ENDPOINT`: (kOFT) LayerZero endpoint address
- `KTOKEN_CONTRACT`: (kOFT) Deployed kToken contract address

Set these in your shell or use a `.env` file (do not commit secrets).

## Key Features

- **ERC20 with Permit**: Supports gasless approvals via EIP-2612
- **Role-Based Access Control**: Fine-grained permissions for minting and administration
- **Upgradeable**: UUPS pattern for future improvements
- **Cross-Chain**: LayerZero OFT implementation for seamless cross-chain transfers
- **Comprehensive Testing**: Unit, fuzz, invariant, and integration tests
- **Pausable**: Emergency pause functionality for added security

## Security

- All upgradeable contracts use UUPS pattern and are protected by role-based access control
- Comprehensive invariant testing ensures system-wide properties hold under all conditions
- State consistency checks between operations
- Proper access control validation
- Review and test thoroughly before deploying to production networks

## Credits

- LayerZero Labs for OFT standard
- OpenZeppelin for upgradeable contracts
- Patrick Collins for secure deployment patterns
- Foundry for the testing framework