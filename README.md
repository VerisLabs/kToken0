# kToken Smart Contracts

## Usage

kToken comes with a comprehensive set of tests written in Solidity, which can be executed using Foundry.

To install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```bash
foundryup
```

To clone the repo:

```bash
git clone https://github.com/your-org/kToken.git && cd kToken
```

## Installing Dependencies

The project uses Soldeer for dependency management. To install all dependencies:

```bash
soldeer install
```

This will install all dependencies specified in soldeer.lock.

## Testing

### in default mode

To run the tests in a default mode:

```bash
forge test
```

### in coverage mode

```bash
forge coverage
```

### Using solx compiler (optional)

For faster compilation with the LLVM-based Solidity compiler, you can install and use solx:

Install solx:

```bash
curl -L https://raw.githubusercontent.com/matter-labs/solx/main/install-solx | bash
```

Use with forge:

```bash
forge build --use $(which solx)
forge test --use $(which solx)
```

## Smart Contracts Documentation

Generate and view the Foundry documentation:

```bash
forge doc --serve --port 4000
```

This will open the documentation at http://localhost:4000

## Protocol Documentation

- **Architecture** - Complete protocol architecture and operational flows
- **Interfaces** - Interface documentation for all protocol contracts  
- **Audit Scope** - Comprehensive audit scope and security considerations

## For Integrators

### Cross-Chain Operations

kToken enables seamless cross-chain token transfers using LayerZero's OFT standard:

- **kOFT.mint()** - Mints tokens on destination chain after cross-chain transfer
- **kOFT.burn()** - Burns tokens on source chain to initiate cross-chain transfer
- **kOFTAdapter.lock()** - Locks tokens for cross-chain transfer (adapter pattern)
- **kOFTAdapter.release()** - Releases locked tokens on destination chain

### Native vs Adapter Patterns

The protocol supports two OFT strategies:

**Native Pattern (kOFT):**

- Direct mint/burn operations
- Suitable for new token deployments
- Full control over token supply

**Adapter Pattern (kOFTAdapter):**

- Lock/release existing tokens
- Compatible with existing ERC20 tokens
- Maintains original token contract

### Role Hierarchy

| Role | Permissions | Contracts |
|------|-------------|-----------|
| OWNER | Ultimate control, upgrades | All |
| ADMIN_ROLE | Operational management | All |
| MINTER_ROLE | Mint/burn tokens | kToken0 |
| PAUSER_ROLE | Emergency pause | kToken0 |

### Deployment

Deploy contracts using the scripts in the `script/` directory:

```bash
# Create a secure keystore (recommended)
cast wallet import myKeystoreName --interactive

# Deploy contracts
forge script script/DeployHub.s.sol --rpc-url $RPC_URL --broadcast --verify --account myKeystoreName --sender <accountAddress>
forge script script/DeploySpoke.s.sol --rpc-url $RPC_URL --broadcast --verify --account myKeystoreName --sender <accountAddress>
```

**Required Environment Variables:**

- `OWNER`: Contract owner address
- `ADMIN`: Admin role address  
- `MINTER`: Minter role address
- `LZ_ENDPOINT`: LayerZero endpoint address
- `KTOKEN_CONTRACT`: Deployed kToken0 contract address

## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using kToken to ensure it interacts correctly with your code.

## Known Limitations

- Cross-chain transfers require LayerZero endpoint configuration and fees
- Adapter pattern requires existing token contract cooperation
- Upgrade operations require proper access control and timelock considerations
- Gas costs vary significantly across different networks

## Contributing

The code is currently in active development. Please review the codebase thoroughly and test extensively before integration.

## License

(c) 2025 KAM Protocol

All rights reserved. This project uses a proprietary license.