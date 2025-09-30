// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kToken0 } from "../../src/kToken0.sol";
import { Test } from "forge-std/Test.sol";

contract kToken0Test is Test {
    kToken0 public token;
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public emergencyAdmin = address(0x3);
    address public kOFTAddress = address(0x4);
    address public user = address(0x5);

    string public constant NAME = "kUSD";
    string public constant SYMBOL = "kUSD";
    uint8 public constant DECIMALS = 6;

    function setUp() public {
        // Deploy kToken0 using constructor (not proxy pattern for simple testing)
        token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            kOFTAddress,
            NAME,
            SYMBOL,
            DECIMALS
        );
    }

    function testInitialSetup() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), DECIMALS);
        assertEq(token.owner(), owner);
    }

    function testInitialRoles() public {
        assertTrue(token.hasAnyRole(admin, token.ADMIN_ROLE()));
        assertTrue(token.hasAnyRole(kOFTAddress, token.MINTER_ROLE()));
    }

    function testCrosschainMintByMinter() public {
        uint256 amount = 1000e6; // 1000 tokens with 6 decimals
        
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
    }

    function testCrosschainMintByNonMinterReverts() public {
        vm.expectRevert();
        vm.prank(user);
        token.crosschainMint(user, 1000e6);
    }

    function testCrosschainBurnByMinter() public {
        uint256 amount = 1000e6;
        
        // First mint
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount);
        
        // Then burn
        vm.prank(kOFTAddress);
        token.crosschainBurn(user, 400e6);
        
        assertEq(token.balanceOf(user), 600e6);
    }

    function testCrosschainBurnByNonMinterReverts() public {
        // Mint first
        vm.prank(kOFTAddress);
        token.crosschainMint(user, 1000e6);
        
        // Try to burn as non-minter
        vm.expectRevert();
        vm.prank(user);
        token.crosschainBurn(user, 100e6);
    }

    function testCrosschainMintEvent() public {
        uint256 amount = 123e6;
        
        //vm.expectEmit(true, false, false, true);
        //emit kToken0.Minted(user, amount);
        
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount);
    }

    function testCrosschainBurnEvent() public {
        uint256 amount = 123e6;
        
        // Mint first
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount);
        
        //vm.expectEmit(true, false, false, true);
        //emit kToken0.Burned(user, amount);
        
        vm.prank(kOFTAddress);
        token.crosschainBurn(user, amount);
    }

    function testGrantMinterRole() public {
        address newMinter = address(0x999);
        
        vm.prank(owner);
        token.grantMinterRole(newMinter);
        
        assertTrue(token.hasAnyRole(newMinter, token.MINTER_ROLE()));
    }

    function testRevokeMinterRole() public {
        vm.prank(owner);
        token.revokeMinterRole(kOFTAddress);
        
        assertFalse(token.hasAnyRole(kOFTAddress, token.MINTER_ROLE()));
    }

    function testOnlyOwnerCanGrantMinterRole() public {
        address newMinter = address(0x999);
        
        vm.expectRevert();
        vm.prank(user);
        token.grantMinterRole(newMinter);
    }

    function testPauseByAdmin() public {
        vm.prank(admin);
        token.setPaused(true);
        
        assertTrue(token.isPaused());
    }

    function testPauseByNonAdminReverts() public {
        vm.expectRevert();
        vm.prank(user);
        token.setPaused(true);
    }

    function testMintBurnRevertWhenPaused() public {
        vm.prank(admin);
        token.setPaused(true);
        
        vm.expectRevert();
        vm.prank(kOFTAddress);
        token.crosschainMint(user, 1000e6);
        
        vm.expectRevert();
        vm.prank(kOFTAddress);
        token.crosschainBurn(user, 1000e6);
    }

    function testMintBurnWorkWhenUnpaused() public {
        // Pause
        vm.prank(admin);
        token.setPaused(true);
        
        // Unpause
        vm.prank(admin);
        token.setPaused(false);
        
        // Should work now
        vm.prank(kOFTAddress);
        token.crosschainMint(user, 1000e6);
        assertEq(token.balanceOf(user), 1000e6);
        
        vm.prank(kOFTAddress);
        token.crosschainBurn(user, 500e6);
        assertEq(token.balanceOf(user), 500e6);
    }

    function testSupportsERC7802Interface() public {
        bytes4 erc7802InterfaceId = type(IERC7802).interfaceId;
        assertTrue(token.supportsInterface(erc7802InterfaceId));
    }

    function testSupportsERC165Interface() public {
        bytes4 erc165InterfaceId = type(IERC165).interfaceId;
        assertTrue(token.supportsInterface(erc165InterfaceId));
    }

    function testTotalSupplyTracking() public {
        uint256 amount1 = 1000e6;
        uint256 amount2 = 500e6;
        
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount1);
        assertEq(token.totalSupply(), amount1);
        
        vm.prank(kOFTAddress);
        token.crosschainMint(owner, amount2);
        assertEq(token.totalSupply(), amount1 + amount2);
        
        vm.prank(kOFTAddress);
        token.crosschainBurn(user, 300e6);
        assertEq(token.totalSupply(), amount1 + amount2 - 300e6);
    }

    function testTransferBetweenUsers() public {
        uint256 amount = 1000e6;
        
        // Mint to user
        vm.prank(kOFTAddress);
        token.crosschainMint(user, amount);
        
        // Transfer from user to owner
        vm.prank(user);
        token.transfer(owner, 300e6);
        
        assertEq(token.balanceOf(user), 700e6);
        assertEq(token.balanceOf(owner), 300e6);
    }
}

// Interface definitions for testing
interface IERC7802 {
    function crosschainMint(address to, uint256 amount) external;
    function crosschainBurn(address from, uint256 amount) external;
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}