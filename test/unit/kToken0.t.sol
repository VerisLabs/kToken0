// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kToken0 } from "../../src/kToken0.sol";
import { Test } from "forge-std/Test.sol";

/**
 * @title kToken0 Unit Tests
 * @notice Comprehensive unit tests for kToken0 contract
 */
contract kToken0UnitTest is Test {
    kToken0 public token;

    address public owner = address(0x1);
    address public admin = address(0x2);
    address public emergencyAdmin = address(0x3);
    address public minter = address(0x4);
    address public user1 = address(0x10);
    address public user2 = address(0x20);

    string constant NAME = "kUSD Token";
    string constant SYMBOL = "kUSD";
    uint8 constant DECIMALS = 6;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event CrosschainMint(address indexed to, uint256 amount, address indexed minter);
    event CrosschainBurn(address indexed from, uint256 amount, address indexed minter);
    event PauseState(bool paused);

    function setUp() public {
        // Deploy using constructor
        token = new kToken0(owner, admin, emergencyAdmin, minter, NAME, SYMBOL, DECIMALS);
    }

    // ============================================
    // INITIALIZATION TESTS
    // ============================================

    function test_Constructor_SetsNameCorrectly() public view {
        assertEq(token.name(), NAME);
    }

    function test_Constructor_SetsSymbolCorrectly() public view {
        assertEq(token.symbol(), SYMBOL);
    }

    function test_Constructor_SetsDecimalsCorrectly() public view {
        assertEq(token.decimals(), DECIMALS);
    }

    function test_Constructor_SetsOwnerCorrectly() public view {
        assertEq(token.owner(), owner);
    }

    function test_Constructor_GrantsAdminRole() public view {
        assertTrue(token.hasAnyRole(admin, token.ADMIN_ROLE()));
    }

    function test_Constructor_GrantsMinterRole() public view {
        assertTrue(token.hasAnyRole(minter, token.MINTER_ROLE()));
    }

    function test_Constructor_InitialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    // ============================================
    // CROSSCHAIN MINT TESTS
    // ============================================

    function test_CrosschainMint_Success() public {
        uint256 amount = 1000e6;

        vm.prank(minter);
        token.crosschainMint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_CrosschainMint_EmitsMintedEvent() public {
        uint256 amount = 1000e6;

        vm.expectEmit(true, false, false, true);
        emit Minted(user1, amount);

        vm.prank(minter);
        token.crosschainMint(user1, amount);
    }

    function test_CrosschainMint_EmitsCrosschainMintEvent() public {
        uint256 amount = 1000e6;

        vm.expectEmit(true, false, false, true);
        emit CrosschainMint(user1, amount, minter);

        vm.prank(minter);
        token.crosschainMint(user1, amount);
    }

    function test_CrosschainMint_RevertsForNonMinter() public {
        uint256 amount = 1000e6;

        vm.expectRevert();
        vm.prank(user1);
        token.crosschainMint(user1, amount);
    }

    function test_CrosschainMint_RevertsWhenPaused() public {
        vm.prank(emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert();
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);
    }

    function test_CrosschainMint_MultipleMintsAccumulate() public {
        vm.startPrank(minter);
        token.crosschainMint(user1, 500e6);
        token.crosschainMint(user1, 300e6);
        token.crosschainMint(user1, 200e6);
        vm.stopPrank();

        assertEq(token.balanceOf(user1), 1000e6);
    }

    // ============================================
    // CROSSCHAIN BURN TESTS
    // ============================================

    function test_CrosschainBurn_Success() public {
        uint256 amount = 1000e6;

        // Mint first
        vm.prank(minter);
        token.crosschainMint(user1, amount);

        // Burn
        vm.prank(minter);
        token.crosschainBurn(user1, 400e6);

        assertEq(token.balanceOf(user1), 600e6);
        assertEq(token.totalSupply(), 600e6);
    }

    function test_CrosschainBurn_EmitsBurnedEvent() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.expectEmit(true, false, false, true);
        emit Burned(user1, 400e6);

        vm.prank(minter);
        token.crosschainBurn(user1, 400e6);
    }

    function test_CrosschainBurn_EmitsCrosschainBurnEvent() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.expectEmit(true, false, false, true);
        emit CrosschainBurn(user1, 400e6, minter);

        vm.prank(minter);
        token.crosschainBurn(user1, 400e6);
    }

    function test_CrosschainBurn_RevertsForNonMinter() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.expectRevert();
        vm.prank(user1);
        token.crosschainBurn(user1, 100e6);
    }

    function test_CrosschainBurn_RevertsWhenPaused() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.prank(emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert();
        vm.prank(minter);
        token.crosschainBurn(user1, 100e6);
    }

    function test_CrosschainBurn_RevertsForInsufficientBalance() public {
        vm.prank(minter);
        token.crosschainMint(user1, 100e6);

        vm.expectRevert();
        vm.prank(minter);
        token.crosschainBurn(user1, 200e6);
    }

    // ============================================
    // ROLE MANAGEMENT TESTS
    // ============================================

    function test_GrantMinterRole_Success() public {
        address newMinter = address(0x999);

        vm.prank(admin);
        token.grantMinterRole(newMinter);

        assertTrue(token.hasAnyRole(newMinter, token.MINTER_ROLE()));
    }

    function test_GrantMinterRole_RevertsForNonOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        token.grantMinterRole(user1);
    }

    function test_RevokeMinterRole_Success() public {
        vm.prank(admin);
        token.revokeMinterRole(minter);

        assertFalse(token.hasAnyRole(minter, token.MINTER_ROLE()));
    }

    function test_RevokeMinterRole_RevertsForNonOwner() public {
        vm.expectRevert();
        vm.prank(user1);
        token.revokeMinterRole(minter);
    }

    function test_RevokedMinter_CannotMint() public {
        vm.prank(admin);
        token.revokeMinterRole(minter);

        vm.expectRevert();
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);
    }

    // ============================================
    // PAUSE FUNCTIONALITY TESTS
    // ============================================

    function test_SetPaused_Success() public {
        vm.prank(emergencyAdmin);
        token.setPaused(true);

        assertTrue(token.isPaused());
    }

    function test_SetPaused_EmitsPauseStateEvent() public {
        vm.expectEmit(false, false, false, true);
        emit PauseState(true);

        vm.prank(emergencyAdmin);
        token.setPaused(true);
    }

    function test_SetPaused_RevertsForNonAdmin() public {
        vm.expectRevert();
        vm.prank(user1);
        token.setPaused(true);
    }

    function test_SetUnpaused_Success() public {
        vm.prank(emergencyAdmin);
        token.setPaused(true);

        vm.prank(emergencyAdmin);
        token.setPaused(false);

        assertFalse(token.isPaused());
    }

    function test_Unpause_AllowsMinting() public {
        vm.prank(emergencyAdmin);
        token.setPaused(true);

        vm.prank(emergencyAdmin);
        token.setPaused(false);

        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        assertEq(token.balanceOf(user1), 1000e6);
    }

    // ============================================
    // ERC20 FUNCTIONALITY TESTS
    // ============================================

    function test_Transfer_Success() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.prank(user1);
        token.transfer(user2, 300e6);

        assertEq(token.balanceOf(user1), 700e6);
        assertEq(token.balanceOf(user2), 300e6);
    }

    function test_Approve_Success() public {
        vm.prank(user1);
        token.approve(user2, 500e6);

        assertEq(token.allowance(user1, user2), 500e6);
    }

    function test_TransferFrom_Success() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.prank(user1);
        token.approve(user2, 500e6);

        vm.prank(user2);
        token.transferFrom(user1, user2, 300e6);

        assertEq(token.balanceOf(user1), 700e6);
        assertEq(token.balanceOf(user2), 300e6);
        assertEq(token.allowance(user1, user2), 200e6);
    }

    // ============================================
    // INTERFACE SUPPORT TESTS
    // ============================================

    function test_SupportsInterface_ERC7802() public view {
        bytes4 interfaceId = type(IERC7802).interfaceId;
        assertTrue(token.supportsInterface(interfaceId));
    }

    function test_SupportsInterface_ERC165() public view {
        bytes4 interfaceId = type(IERC165).interfaceId;
        assertTrue(token.supportsInterface(interfaceId));
    }

    function test_SupportsInterface_InvalidInterface() public view {
        bytes4 invalidId = bytes4(0xffffffff);
        assertFalse(token.supportsInterface(invalidId));
    }

    // ============================================
    // SUPPLY TRACKING TESTS
    // ============================================

    function test_TotalSupply_UpdatesOnMint() public {
        assertEq(token.totalSupply(), 0);

        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        assertEq(token.totalSupply(), 1000e6);
    }

    function test_TotalSupply_UpdatesOnBurn() public {
        vm.prank(minter);
        token.crosschainMint(user1, 1000e6);

        vm.prank(minter);
        token.crosschainBurn(user1, 400e6);

        assertEq(token.totalSupply(), 600e6);
    }

    function test_TotalSupply_EqualsAllBalances() public {
        vm.startPrank(minter);
        token.crosschainMint(user1, 500e6);
        token.crosschainMint(user2, 300e6);
        token.crosschainMint(owner, 200e6);
        vm.stopPrank();

        uint256 totalBalances = token.balanceOf(user1) + token.balanceOf(user2) + token.balanceOf(owner);

        assertEq(token.totalSupply(), totalBalances);
    }

    // ============================================
    // FUZZ TESTS
    // ============================================

    function testFuzz_CrosschainMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, type(uint96).max);

        vm.prank(minter);
        token.crosschainMint(to, amount);

        assertEq(token.balanceOf(to), amount);
    }

    function testFuzz_CrosschainBurn(address user, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(user != address(0));
        mintAmount = bound(mintAmount, 1, type(uint96).max);
        burnAmount = bound(burnAmount, 1, mintAmount);

        vm.prank(minter);
        token.crosschainMint(user, mintAmount);

        vm.prank(minter);
        token.crosschainBurn(user, burnAmount);

        assertEq(token.balanceOf(user), mintAmount - burnAmount);
    }
}

// Minimal interfaces for testing
interface IERC7802 {
    function crosschainMint(address to, uint256 amount) external;
    function crosschainBurn(address from, uint256 amount) external;
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
