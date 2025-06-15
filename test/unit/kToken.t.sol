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
        assertTrue(token.hasRole(token.ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.UPGRADER_ROLE(), admin));
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

    function testUpgradeToZeroAddressReverts() public {
        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, NAME, SYMBOL, DECIMALS, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        kToken proxied = kToken(address(proxy));
        vm.prank(owner);
        vm.expectRevert();
        IUpgrade(address(proxied)).upgradeTo(address(0));
    }
}
