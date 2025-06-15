# kUSD Smart Contracts

## Overview

kUSD is a cross-chain token system leveraging LayerZero's OFT (Omnichain Fungible Token) standard. The contracts are upgradeable and use robust role-based access control for minting, burning, and upgrades. This repository includes:

- `kToken`: Upgradeable ERC20 token with role-based mint/burn and UUPS upgradeability.
- `kOFT`: LayerZero OFT implementation for cross-chain abstraction, upgradeable via UUPS.
- Deployment scripts for both contracts using Foundry.

## Directory Structure

- `src/` — Main contract sources
- `src/interfaces/` — Contract interfaces
- `test/unit/` — Unit tests
- `test/mocks/` — Mock contracts for testing
- `test/fork/` — Fork/integration tests
- `script/` — Deployment scripts

## Deployment

kUSD contracts can be deployed to various networks using the deployment scripts in the `script/` directory.

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

## Testing

Run all tests with:

```sh
forge test
```

## Security

- Never use a private key with real funds for deployment or testing.
- All upgradeable contracts use UUPS and are protected by role-based access control.
- Review and test thoroughly before deploying to production networks.

## Credits

- LayerZero Labs for OFT standard
- OpenZeppelin for upgradeable contracts
- Patrick Collins for secure deployment patterns
