// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IKToken } from "./interfaces/IKToken.sol";
import { OFTCoreUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title kOFT
/// @notice LayerZero OFT implementation for cross-chain token abstraction
contract kOFT is Initializable, OFTCoreUpgradeable, UUPSUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the address is the zero address
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The token contract (mint/burn authority)
    IKToken public tokenContract;

    /// @notice The default decimals value for kOFT
    uint8 public constant DEFAULT_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the upgrade is authorized
    event UpgradeAuthorized(address indexed newImplementation, address indexed sender);

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address lzEndpoint_, uint8 decimals_) OFTCoreUpgradeable(decimals_, lzEndpoint_) {
        _disableInitializers();
    }

    /// @notice Initializes the kOFT contract
    /// @param delegate_ The address with admin rights (owner)
    /// @param tokenContract_ The address of the underlying token contract
    function initialize(address delegate_, address tokenContract_) external initializer {
        if (delegate_ == address(0) || tokenContract_ == address(0)) {
            revert ZeroAddress();
        }
        __OFTCore_init(delegate_);
        __Ownable_init(delegate_);
        __UUPSUpgradeable_init();
        tokenContract = IKToken(tokenContract_);
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
        tokenContract.burn(_from, amountSentLD);
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
        tokenContract.mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    /// @dev Authorizes contract upgrades (only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        emit UpgradeAuthorized(newImplementation, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the token (OFT pattern: self-address)
    function token() public view returns (address) {
        return address(this);
    }

    /// @notice Indicates whether approval is required to send tokens (always false for OFT)
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /// @notice View-only version of debit (does not mutate state)
    function debitView(
        uint256 _amountToSendLD,
        uint256 _minAmountToCreditLD,
        uint32 _dstEid
    )
        external
        view
        returns (uint256 amountDebitedLD, uint256 amountToCreditLD)
    {
        return _debitView(_amountToSendLD, _minAmountToCreditLD, _dstEid);
    }

    /// @notice Removes dust from the amount (for cross-chain decimal conversion)
    function removeDust(uint256 _amountLD) external view returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }

    /// @notice Converts shared decimals to local decimals
    function toLD(uint64 _amountSD) external view returns (uint256 amountLD) {
        return _toLD(_amountSD);
    }

    /// @notice Converts local decimals to shared decimals
    function toSD(uint256 _amountLD) external view returns (uint64 amountSD) {
        return _toSD(_amountLD);
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

    /*//////////////////////////////////////////////////////////////
                        STORAGE GAP
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage gap for future upgrades
    uint256[49] private __gap;
}
