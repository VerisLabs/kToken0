// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { kToken0 } from "../../src/kToken0.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/Test.sol";

contract kOFTAdapterTest is Test {
    kToken0 public token;
    kOFTAdapter public oftAdapter;
    address public lzEndpoint;
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public emergencyAdmin = address(0x3);
    address public user = address(0x4);

    string public constant NAME = "kUSD";
    string public constant SYMBOL = "kUSD";
    uint8 public constant DECIMALS = 18;

    function setUp() public {
        // Deploy mock LayerZero endpoint
        lzEndpoint = address(0x1337);
        vm.etch(lzEndpoint, "mock");

        // Deploy kToken0 (hub deployment pattern)
        token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            address(this), // temporary - will grant to adapter later
            NAME,
            SYMBOL,
            DECIMALS
        );

        // Deploy kOFTAdapter
        kOFTAdapter implementation = new kOFTAdapter(address(token), lzEndpoint);
        bytes memory data = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        oftAdapter = kOFTAdapter(address(proxy));

        // Grant adapter minter role
        vm.prank(admin);
        token.grantMinterRole(address(oftAdapter));

        // Mint initial supply to admin for testing lock/release pattern
        vm.prank(admin);
        token.grantMinterRole(address(this));
        token.crosschainMint(admin, 1_000_000e18);
    }

    function testInitialSetup() public view {
        assertEq(oftAdapter.token(), address(token));
        assertEq(oftAdapter.owner(), owner);
    }

    function testApprovalRequiredIsTrue() public view {
        // OFTAdapter requires approval because it transfers tokens
        assertTrue(oftAdapter.approvalRequired());
    }

    function testTokenFunctionReturnsToken() public view {
        assertEq(oftAdapter.token(), address(token));
    }

    function testLockAndReleasePattern() public {
        uint256 lockAmount = 1000e18;

        // Owner approves adapter to transfer tokens
        vm.prank(admin);
        token.approve(address(oftAdapter), lockAmount);

        uint256 ownerBalanceBefore = token.balanceOf(admin);
        uint256 adapterBalanceBefore = token.balanceOf(address(oftAdapter));

        // Simulate lock by transferring to adapter
        vm.prank(admin);
        token.transfer(address(oftAdapter), lockAmount);

        assertEq(token.balanceOf(admin), ownerBalanceBefore - lockAmount);
        assertEq(token.balanceOf(address(oftAdapter)), adapterBalanceBefore + lockAmount);
    }

    function testCrosschainMintOnlyByAdapter() public {
        // Adapter should be able to mint
        vm.prank(address(oftAdapter));
        token.crosschainMint(user, 1000e18);
        assertEq(token.balanceOf(user), 1000e18);

        // Non-minter should not be able to mint
        vm.expectRevert();
        vm.prank(user);
        token.crosschainMint(user, 1000e18);
    }

    function testCrosschainBurnOnlyByAdapter() public {
        // First mint some tokens
        vm.prank(address(oftAdapter));
        token.crosschainMint(user, 1000e18);

        // Adapter should be able to burn
        vm.prank(address(oftAdapter));
        token.crosschainBurn(user, 500e18);
        assertEq(token.balanceOf(user), 500e18);

        // Non-minter should not be able to burn
        vm.expectRevert();
        vm.prank(user);
        token.crosschainBurn(user, 100e18);
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        oftAdapter.initialize(owner);
    }

    function testAdapterHasMinterRole() public view {
        assertTrue(token.hasAnyRole(address(oftAdapter), token.MINTER_ROLE()));
    }

    function testUserCannotDirectlyMint() public {
        vm.expectRevert();
        vm.prank(user);
        token.crosschainMint(user, 1000e18);
    }
}
