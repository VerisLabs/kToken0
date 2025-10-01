# kOFT
[Git Source](https://github.com/VerisLabs/kToken/blob/106bb3d6000277e5445cb27a912aae110bd01f57/src/kOFT.sol)

**Inherits:**
OFTCoreUpgradeable

LayerZero OFT implementation for cross-chain token abstraction

*This contract is a wrapper around the OFTCoreUpgradeable contract to implement the kToken0 contract*


## State Variables
### token0
The token0 contract


```solidity
kToken0 public immutable token0;
```


## Functions
### constructor

Constructor to initialize the kOFT contract


```solidity
constructor(address lzEndpoint_, kToken0 kToken0_) OFTCoreUpgradeable(kToken0_.decimals(), lzEndpoint_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lzEndpoint_`|`address`|The LayerZero endpoint|
|`kToken0_`|`kToken0`|The token0 contract|


### initialize

Initializes the kOFT contract


```solidity
function initialize(address delegate_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`delegate_`|`address`|The address with admin rights (owner)|


### _debit

Debits tokens from the sender's balance (internal, override)


```solidity
function _debit(
    address _from,
    uint256 _amountLD,
    uint256 _minAmountLD,
    uint32 _dstEid
)
    internal
    virtual
    override
    returns (uint256 amountSentLD, uint256 amountReceivedLD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address from which to debit tokens|
|`_amountLD`|`uint256`|The amount to debit (local decimals)|
|`_minAmountLD`|`uint256`|The minimum amount to debit (local decimals)|
|`_dstEid`|`uint32`|The destination chain id|


### _credit

Credits tokens to the specified address (internal, override)


```solidity
function _credit(address _to, uint256 _amountLD, uint32) internal virtual override returns (uint256 amountReceivedLD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to credit tokens to|
|`_amountLD`|`uint256`|The amount to credit (local decimals)|
|`<none>`|`uint32`||


### approvalRequired

Indicates whether approval is required to send tokens (always false for OFT)


```solidity
function approvalRequired() external pure virtual returns (bool);
```

### token

Returns the address of the token (OFT pattern: self-address)


```solidity
function token() public view returns (address);
```

### buildMsgAndOptions

Builds the message and options for a send operation


```solidity
function buildMsgAndOptions(
    SendParam calldata _sendParam,
    uint256 _amountToCreditLD
)
    external
    view
    returns (bytes memory message, bytes memory options);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sendParam`|`SendParam`|The send parameter struct|
|`_amountToCreditLD`|`uint256`|The amount to credit (local decimals)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`message`|`bytes`|The encoded message|
|`options`|`bytes`|The encoded options|


## Errors
### ZeroAddress
Thrown when the address is the zero address


```solidity
error ZeroAddress();
```

