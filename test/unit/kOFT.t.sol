// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kToken0 } from "../../src/kToken0.sol";
import { kOFT } from "../../src/kOFT.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/Test.sol";

contract kOFTTest is Test {
    kToken0 public token;
    kOFT public oft;
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

        // Deploy kToken0 with temporary kOFT address
        token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            address(this), // temporary - will grant to kOFT later
            NAME,
            SYMBOL,
            DECIMALS
        );

        // Deploy kOFT
        kOFT implementation = new kOFT(lzEndpoint, token);
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        oft = kOFT(address(proxy));

        // Grant kOFT minter role
        vm.prank(owner);
        token.grantMinterRole(address(oft));
    }

    function testInitialSetup() public {
        assertEq(oft.token(), address(token));
        assertEq(oft.owner(), owner);
    }

    function testApprovalRequiredIsFalse() public {
        assertEq(oft.approvalRequired(), false);
    }

    function testTokenFunctionReturnsToken() public {
        assertEq(oft.token(), address(token));
    }

    function testCrosschainMint() public {
        uint256 amount = 1000e18;
        
        // kOFT should be able to mint via crosschainMint
        vm.prank(address(oft));
        token.crosschainMint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
    }

    function testCrosschainBurn() public {
        uint256 amount = 1000e18;
        
        // First mint some tokens
        vm.prank(address(oft));
        token.crosschainMint(user, amount);
        
        // Then burn them
        vm.prank(address(oft));
        token.crosschainBurn(user, amount);
        
        assertEq(token.balanceOf(user), 0);
    }

    function testCrosschainMintOnlyByMinter() public {
        vm.expectRevert();
        vm.prank(user);
        token.crosschainMint(user, 1000e18);
    }

    function testCrosschainBurnOnlyByMinter() public {
        // Mint first
        vm.prank(address(oft));
        token.crosschainMint(user, 1000e18);
        
        // Try to burn from non-minter
        vm.expectRevert();
        vm.prank(user);
        token.crosschainBurn(user, 1000e18);
    }

    function testBuildMsgAndOptions() public {
        SendParam memory param = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(user))),
            amountLD: 1000,
            minAmountLD: 1000,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        
        (bytes memory msgBytes, bytes memory options) = oft.buildMsgAndOptions(param, 1000);
        assertGt(msgBytes.length, 0);
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        oft.initialize(owner);
    }

    function testSupportsERC7802Interface() public {
        // ERC7802 interface ID
        bytes4 erc7802InterfaceId = type(IERC7802).interfaceId;
        assertTrue(token.supportsInterface(erc7802InterfaceId));
    }

    function testSupportsERC165Interface() public {
        bytes4 erc165InterfaceId = type(IERC165).interfaceId;
        assertTrue(token.supportsInterface(erc165InterfaceId));
    }
}

// Minimal interface definitions for testing
interface IERC7802 {
    function crosschainMint(address to, uint256 amount) external;
    function crosschainBurn(address from, uint256 amount) external;
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}