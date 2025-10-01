# OptimizedSafeCastLib
[Git Source](https://github.com/VerisLabs/kToken/blob/106bb3d6000277e5445cb27a912aae110bd01f57/src/vendor/solady/utils/OptimizedSafeCastLib.sol)

**Authors:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeCastLib.sol), Modified from OpenZeppelin
(https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)

Safe integer casting library that reverts on overflow.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary safe casting functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


## Functions
### toUint64

*Casts `x` to a uint64. Reverts on overflow.*


```solidity
function toUint64(uint256 x) internal pure returns (uint64);
```

### toUint128

*Casts `x` to a uint128. Reverts on overflow.*


```solidity
function toUint128(uint256 x) internal pure returns (uint128);
```

### toUint256

*Casts `x` to a uint256. Reverts on overflow.*


```solidity
function toUint256(int256 x) internal pure returns (uint256);
```

### _revertOverflow


```solidity
function _revertOverflow() private pure;
```

## Errors
### Overflow
*Unable to cast to the target type due to overflow.*


```solidity
error Overflow();
```

