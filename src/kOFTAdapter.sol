// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OFTCoreUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title kOFT
/// @notice LayerZero OFT implementation for cross-chain token abstraction
contract kOFTAdapter is Initializable, OFTCoreUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the address is the zero address
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            CUSTOM STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kToken.storage.kOFTAdapter
    struct kOFTAdapterStorage {
        IERC20 tokenContract;
    }

    // keccak256(abi.encode(uint256(keccak256("kToken.storage.kOFTAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KOFTADAPTER_STORAGE_LOCATION =
        0xc3cb0ef2eb152f0b1a817a5752040bce18ae72a8f914bcbf52be9c234c7ca300;

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
        _getkOFTAdapterStorage().tokenContract = IERC20(tokenContract_);
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
        // @dev Lock tokens by moving them into this contract from the caller.
        _getkOFTAdapterStorage().tokenContract.safeTransferFrom(_from, address(this), amountSentLD);
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
        // @dev Unlock the tokens and transfer to the recipient.
        _getkOFTAdapterStorage().tokenContract.safeTransfer(_to, _amountLD);
        // @dev In the case of NON-default OFTAdapter, the amountLD MIGHT not be == amountReceivedLD.
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

    /// @notice Returns the address of the token
    function token() public view returns (address) {
        return address(_getkOFTAdapterStorage().tokenContract);
    }

    /// @notice Indicates whether approval is required to send tokens (always false for OFT)
    function approvalRequired() external pure virtual returns (bool) {
        return true;
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
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    function _getkOFTAdapterStorage() private pure returns (kOFTAdapterStorage storage $) {
        assembly {
            $.slot := KOFTADAPTER_STORAGE_LOCATION
        }
    }
}
