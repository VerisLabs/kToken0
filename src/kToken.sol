// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title kToken
/// @notice Upgradeable ERC20 token with role-based mint/burn and UUPS upgradeability
/// @dev This contract extends LayerZero's OFT for chain abstraction
contract kToken is
    Initializable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the address is the zero address
    error ZeroAddress();
    /// @notice Thrown when the contract is paused
    error Paused();

    /*//////////////////////////////////////////////////////////////
                            CUSTOM STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kToken.storage.kToken
    struct kTokenStorage {
        uint8 _customDecimals;
        bool isPaused;
    }

    // keccak256(abi.encode(uint256(keccak256("kToken.storage.kToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KTOKEN_STORAGE_LOCATION =
        0x2fb0aec331268355746e3684d9eaaf2249f450cf0e491ca0657288d2091eea00;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for oracle privileges
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are minted
    event Minted(address indexed to, uint256 amount);
    /// @notice Emitted when tokens are burned
    event Burned(address indexed from, uint256 amount);
    /// @notice Emitted when the upgrade is authorized
    event UpgradeAuthorized(address indexed newImplementation, address indexed sender);
    /// @notice Emitted when the contract is paused
    event PauseState(bool isPaused);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (_getkTokenStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kToken contract
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param owner_ Owner address
    /// @param admin_ Admin role address
    /// @param minter_ Minter role address
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_,
        address admin_,
        address minter_
    )
        external
        initializer
    {
        if (owner_ == address(0) || admin_ == address(0) || minter_ == address(0)) {
            revert ZeroAddress();
        }

        kTokenStorage storage $ = _getkTokenStorage();
        $._customDecimals = decimals_;
        $.isPaused = false;

        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Ownable_init(owner_);
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, minter_);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses the contract
    function pause(bool _isPaused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        kTokenStorage storage $ = _getkTokenStorage();
        $.isPaused = _isPaused;
        emit PauseState(_isPaused);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints new tokens
    /// @dev Can only be called by addresses with the MINTER_ROLE
    /// @param _to The address to mint the tokens to
    /// @param _amount The amount of tokens to mint
    function mint(address _to, uint256 _amount) external nonReentrant whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    /// @notice Burns tokens
    /// @dev Can only be called by addresses with the MINTER_ROLE
    /// @param _from The address to burn the tokens from
    /// @param _amount The amount of tokens to burn
    function burn(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRole(MINTER_ROLE) {
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /// @notice Burns tokens from specified address (requires approval)
    /// @dev Can only be called by addresses with the MINTER_ROLE
    /// @param _from The address to burn the tokens from
    /// @param _amount The amount of tokens to burn
    function burnFrom(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRole(MINTER_ROLE) {
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Authorizes contract upgrades (only owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        emit UpgradeAuthorized(newImplementation, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the decimals of the token
    /// @dev Overrides the ERC20 decimals function
    /// @return The decimals of the token
    function decimals() public view virtual override returns (uint8) {
        return _getkTokenStorage()._customDecimals;
    }

    /// @notice Returns whether the contract is paused
    /// @return Whether the contract is paused
    function isPaused() public view returns (bool) {
        return _getkTokenStorage().isPaused;
    }

    /*//////////////////////////////////////////////////////////////
                        STORAGE GAP
    //////////////////////////////////////////////////////////////*/

    function _getkTokenStorage() private pure returns (kTokenStorage storage $) {
        assembly {
            $.slot := KTOKEN_STORAGE_LOCATION
        }
    }
}
