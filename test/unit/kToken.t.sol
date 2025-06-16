// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kToken } from "../../src/kToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

interface IUpgrade {
    function upgradeTo(address newImplementation) external;
}

contract kTokenTest is Test {
    kToken public token;
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public minter = address(0x3);
    address public upgrader = address(0x4);
    address public user = address(0x5);

    string public constant NAME = "kUSD";
    string public constant SYMBOL = "kUSD";
    uint8 public constant DECIMALS = 6;

    function setUp() public {
        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, NAME, SYMBOL, DECIMALS, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));
    }

    function testInitialRolesAndOwner() public {
        assertEq(token.owner(), owner);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function testDecimals() public {
        assertEq(token.decimals(), DECIMALS);
    }

    function testMintByMinter() public {
        vm.prank(minter);
        token.mint(user, 1000);
        assertEq(token.balanceOf(user), 1000);
    }

    function testMintByNonMinterReverts() public {
        vm.expectRevert();
        token.mint(user, 1000);
    }

    function testMintToZeroAddressReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        token.mint(address(0), 1000);
    }

    function testBurnByMinter() public {
        vm.prank(minter);
        token.mint(user, 1000);
        vm.prank(minter);
        token.burn(user, 400);
        assertEq(token.balanceOf(user), 600);
    }

    function testBurnByNonMinterReverts() public {
        vm.expectRevert();
        token.burn(user, 100);
    }

    function testBurnFromZeroAddressReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        token.burn(address(0), 1000);
    }

    function testBurnFromZeroAddressBurnFromReverts() public {
        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(address(0), 1000);
    }

    function testMintEvent() public {
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit kToken.Minted(user, 123);
        token.mint(user, 123);
    }

    function testBurnEvent() public {
        vm.prank(minter);
        token.mint(user, 123);
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit kToken.Burned(user, 123);
        token.burn(user, 123);
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        token.initialize(NAME, SYMBOL, DECIMALS, owner, admin, minter);
    }

    function testBurnFromWithAllowance() public {
        vm.prank(minter);
        token.mint(user, 1000);
        vm.prank(user);
        token.approve(minter, 600);
        vm.prank(minter);
        token.burnFrom(user, 600);
        assertEq(token.balanceOf(user), 400);
    }

    function testBurnFromWithoutAllowanceReverts() public {
        vm.prank(minter);
        token.mint(user, 1000);
        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(user, 1000);
    }

    function testOnlyAdminCanPause() public {
        vm.expectRevert();
        token.pause(true);
        vm.prank(admin);
        token.pause(true);
        assertTrue(token.isPaused());
    }

    function testPauseStateEventEmitted() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit kToken.PauseState(true);
        token.pause(true);
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit kToken.PauseState(false);
        token.pause(false);
    }

    function testMintBurnBurnFromRevertWhenPaused() public {
        vm.prank(admin);
        token.pause(true);
        vm.prank(minter);
        vm.expectRevert();
        token.mint(user, 1000);
        vm.prank(minter);
        vm.expectRevert();
        token.burn(user, 1000);
        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(user, 1000);
    }

    function testMintBurnBurnFromWorkWhenUnpaused() public {
        vm.prank(admin);
        token.pause(true);
        vm.prank(admin);
        token.pause(false);
        vm.prank(minter);
        token.mint(user, 1000);
        assertEq(token.balanceOf(user), 1000);
        vm.prank(minter);
        token.burn(user, 500);
        assertEq(token.balanceOf(user), 500);
        vm.prank(user);
        token.approve(minter, 500);
        vm.prank(minter);
        token.burnFrom(user, 500);
        assertEq(token.balanceOf(user), 0);
    }

    function testOnlyOwnerCanUpgrade() public {
        kToken newImpl = new kToken();
        address notOwner = address(0xBEEF);
        vm.prank(notOwner);
        vm.expectRevert();
        IUpgrade(address(token)).upgradeTo(address(newImpl));
        vm.prank(owner);
        vm.expectRevert();
        IUpgrade(address(token)).upgradeTo(address(newImpl));
    }

    function testTotalSupplyEqualsSumOfBalances() public {
        address[] memory actors = new address[](5);
        actors[0] = owner;
        actors[1] = admin;
        actors[2] = minter;
        actors[3] = upgrader;
        actors[4] = user;
        // Mint to all actors
        vm.prank(minter);
        token.mint(owner, 100);
        vm.prank(minter);
        token.mint(admin, 200);
        vm.prank(minter);
        token.mint(minter, 300);
        vm.prank(minter);
        token.mint(upgrader, 400);
        vm.prank(minter);
        token.mint(user, 500);
        // Burn some from user
        vm.prank(minter);
        token.burn(user, 100);
        // Transfer from owner to user
        vm.prank(owner);
        token.transfer(user, 50);
        // Calculate sum of balances
        uint256 sum = 0;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += token.balanceOf(actors[i]);
        }
        assertEq(token.totalSupply(), sum, "Total supply should equal sum of all balances");
    }
}
