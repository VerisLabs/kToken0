// SPDX-License-Identifier: UNLICENSED
// due to the kToken license, this contract is UNLICENSED
// but all the code in this file (kToken0.sol) uses MIT license.
pragma solidity 0.8.30;

import { IERC7802 } from "./interfaces/IERC7802.sol";

import { kToken } from "./vendor/KAM/kToken.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title kToken0
/// @notice KAM Token0 contract for cross-chain token abstraction and LZ OFT implementation
/// @dev This contract is a wrapper around the kToken contract to implement the IERC7802 interface
/// @dev link: https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7802.md
contract kToken0 is kToken, IERC7802, IERC165 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new token is created
    /// @param token The address of the new token
    /// @param name The name of the new token
    /// @param symbol The symbol of the new token
    /// @param decimals The decimals of the new token
    event Token0Created(address indexed token, string name, string symbol, uint8 decimals);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor to initialize the kToken0 contract
    /// @param owner The owner of the token
    /// @param admin The admin of the token
    /// @param emergencyAdmin The emergency admin of the token
    /// @param kOFT The kOFT of the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The decimals of the token
    constructor(
        address owner,
        address admin,
        address emergencyAdmin,
        address kOFT,
        string memory name,
        string memory symbol,
        uint8 decimals
    )
        kToken(owner, admin, emergencyAdmin, kOFT, name, symbol, decimals)
    {
        emit Token0Created(address(this), name, symbol, decimals);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the OFT contract to mint tokens.
    /// @param _to Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
    function crosschainMint(address _to, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE) {
        _checkPaused();
        _mint(_to, _amount);
        emit Minted(_to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }

    /// @notice Allows the OFT contract to burn tokens.
    /// @param _from Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
    function crosschainBurn(address _from, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE) {
        _checkPaused();
        _burn(_from, _amount);
        emit Burned(_from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }

    /// @notice Checks if the contract supports an interface
    /// @param interfaceId The interface id to check
    /// @return True if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC7802).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
