# IERC7802
[Git Source](https://github.com/VerisLabs/kToken/blob/106bb3d6000277e5445cb27a912aae110bd01f57/src/interfaces/IERC7802.sol)

copied from https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7802.md reference implementation

Defines the interface for crosschain ERC20 transfers.


## Functions
### crosschainMint

Mint tokens through a crosschain transfer.


```solidity
function crosschainMint(address _to, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|    Address to mint tokens to.|
|`_amount`|`uint256`|Amount of tokens to mint.|


### crosschainBurn

Burn tokens through a crosschain transfer.


```solidity
function crosschainBurn(address _from, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|  Address to burn tokens from.|
|`_amount`|`uint256`|Amount of tokens to burn.|


## Events
### CrosschainMint
Emitted when a crosschain transfer mints tokens.


```solidity
event CrosschainMint(address indexed to, uint256 amount, address indexed sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|      Address of the account tokens are being minted for.|
|`amount`|`uint256`|  Amount of tokens minted.|
|`sender`|`address`|  Address of the caller (msg.sender) who invoked crosschainMint.|

### CrosschainBurn
Emitted when a crosschain transfer burns tokens.


```solidity
event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|    Address of the account tokens are being burned from.|
|`amount`|`uint256`|  Amount of tokens burned.|
|`sender`|`address`|  Address of the caller (msg.sender) who invoked crosschainBurn.|

