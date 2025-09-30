// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OFTAdapterUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

/// @title kOFT
/// @notice LayerZero OFT implementation for cross-chain token abstraction
contract kOFTAdapter is OFTAdapterUpgradeable {
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address _delegate) external initializer {
        __OFTAdapter_init(_delegate);
        __Ownable_init(_delegate);
    }
}
