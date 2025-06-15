// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IKToken
/// @notice Interface for the kToken contract (mint/burn authority for kOFT)
/// @dev This contract defines the mint and burn interface for the underlying token
interface IKToken {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Mints tokens to a destination address.
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @dev Burns tokens from a source address.
     */
    function burn(address _from, uint256 _amount) external;
}
