// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OFTAdapterUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

/// @title kOFT
/// @notice LayerZero OFT implementation for cross-chain token abstraction
/// @dev This contract is a wrapper around the OFTAdapterUpgradeable contract to implement the kToken0 contract
contract kOFTAdapter is OFTAdapterUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor to initialize the kOFTAdapter contract
    /// @param _token The token0 contract
    /// @param _lzEndpoint The LayerZero endpoint
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the kOFTAdapter contract
    /// @param _delegate The address with admin rights (owner)
    function initialize(address _delegate) external initializer {
        __OFTAdapter_init(_delegate);
        __Ownable_init(_delegate);
    }
}
