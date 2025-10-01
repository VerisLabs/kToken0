# kToken0
[Git Source](https://github.com/VerisLabs/kToken/blob/106bb3d6000277e5445cb27a912aae110bd01f57/src/kToken0.sol)

**Inherits:**
[kToken](/src/vendor/KAM/kToken.sol/contract.kToken.md), [IERC7802](/src/interfaces/IERC7802.sol/interface.IERC7802.md), IERC165

KAM Token0 contract for cross-chain token abstraction and LZ OFT implementation

*This contract is a wrapper around the kToken contract to implement the IERC7802 interface*

*link: https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7802.md*


## Functions
### constructor

Constructor to initialize the kToken0 contract


```solidity
constructor(
    address owner,
    address admin,
    address emergencyAdmin,
    address kOFT,
    string memory name,
    string memory symbol,
    uint8 decimals
)
    kToken(owner, admin, emergencyAdmin, kOFT, name, symbol, decimals);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The owner of the token|
|`admin`|`address`|The admin of the token|
|`emergencyAdmin`|`address`|The emergency admin of the token|
|`kOFT`|`address`|The kOFT of the token|
|`name`|`string`|The name of the token|
|`symbol`|`string`|The symbol of the token|
|`decimals`|`uint8`|The decimals of the token|


### crosschainMint

Allows the OFT contract to mint tokens.


```solidity
function crosschainMint(address _to, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|Address to mint tokens to.|
|`_amount`|`uint256`|Amount of tokens to mint.|


### crosschainBurn

Allows the OFT contract to burn tokens.


```solidity
function crosschainBurn(address _from, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|Address to burn tokens from.|
|`_amount`|`uint256`|Amount of tokens to burn.|


### supportsInterface

Checks if the contract supports an interface


```solidity
function supportsInterface(bytes4 interfaceId) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|The interface id to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the contract supports the interface, false otherwise|


## Events
### Token0Created
Emitted when a new token is created


```solidity
event Token0Created(address indexed token, string name, string symbol, uint8 decimals);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the new token|
|`name`|`string`|The name of the new token|
|`symbol`|`string`|The symbol of the new token|
|`decimals`|`uint8`|The decimals of the new token|

