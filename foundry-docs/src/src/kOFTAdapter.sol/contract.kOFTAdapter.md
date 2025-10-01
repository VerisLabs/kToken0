# kOFTAdapter
[Git Source](https://github.com/VerisLabs/kToken/blob/106bb3d6000277e5445cb27a912aae110bd01f57/src/kOFTAdapter.sol)

**Inherits:**
OFTAdapterUpgradeable

LayerZero OFT implementation for cross-chain token abstraction

*This contract is a wrapper around the OFTAdapterUpgradeable contract to implement the kToken0 contract*


## Functions
### constructor

Constructor to initialize the kOFTAdapter contract


```solidity
constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The token0 contract|
|`_lzEndpoint`|`address`|The LayerZero endpoint|


### initialize

Initializes the kOFTAdapter contract


```solidity
function initialize(address _delegate) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delegate`|`address`|The address with admin rights (owner)|


