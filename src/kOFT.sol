// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { OFTCoreUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { kToken0 } from "./kToken0.sol";


/// @title kOFT
/// @notice LayerZero OFT implementation for cross-chain token abstraction
contract kOFT is OFTCoreUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the address is the zero address
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    kToken0 public immutable token0;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address lzEndpoint_, kToken0 kToken0_) OFTCoreUpgradeable(kToken0_.decimals(), lzEndpoint_) {
        if (lzEndpoint_ == address(0) || address(kToken0_) == address(0)) {
            revert ZeroAddress();
        }
        
        token0 = kToken0_;
        
        _disableInitializers();
    }

    /// @notice Initializes the kOFT contract
    /// @param delegate_ The address with admin rights (owner)
    function initialize(address delegate_) external initializer {
        __OFTCore_init(delegate_);
        __Ownable_init(delegate_);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Debits tokens from the sender's balance (internal, override)
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        token0.crosschainBurn(_from, amountSentLD);
    }

    /// @dev Credits tokens to the specified address (internal, override)
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // @dev Default OFT mints on dst.
        token0.crosschainMint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Indicates whether approval is required to send tokens (always false for OFT)
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /// @notice Returns the address of the token (OFT pattern: self-address)
    function token() public view returns (address) {
        return address(token0);
    }   

    /// @notice Builds the message and options for a send operation
    /// @param _sendParam The send parameter struct
    /// @param _amountToCreditLD The amount to credit (local decimals)
    /// @return message The encoded message
    /// @return options The encoded options
    function buildMsgAndOptions(
        SendParam calldata _sendParam,
        uint256 _amountToCreditLD
    )
        external
        view
        returns (bytes memory message, bytes memory options)
    {
        return _buildMsgAndOptions(_sendParam, _amountToCreditLD);
    }
}
