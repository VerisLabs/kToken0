// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { kToken } from "../../src/kToken.sol";
import { kOFTAdapterV2 } from "../kOFTAdapterV2.sol";
import { MockLayerZeroEndpoint } from "../mocks/MockLayerZeroEndpoint.sol";
import { kOFTAdapterMock } from "../mocks/kOFTAdapterMock.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

interface IUpgrade {
    function upgradeTo(address newImplementation) external;
}

contract kOFTAdapterTest is Test {
    kToken public token;
    kOFTAdapterMock public oftAdapter;
    address public lzEndpoint;
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public minter = address(0x3);
    address public user = address(0x4);

    string public constant NAME = "kUSD";
    string public constant SYMBOL = "kUSD";
    uint8 public constant DECIMALS = 18;

    MockLayerZeroEndpoint public mockEndpoint;

    function setUp() public {
        mockEndpoint = new MockLayerZeroEndpoint();
        lzEndpoint = address(mockEndpoint);

        // Deploy underlying token
        kToken tokenImpl = new kToken();
        bytes memory tokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, NAME, SYMBOL, DECIMALS, owner, admin, minter);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInit);
        token = kToken(address(tokenProxy));

        // Deploy kOFTAdapter
        kOFTAdapterMock oftAdapterImpl = new kOFTAdapterMock(lzEndpoint, DECIMALS);
        bytes memory oftAdapterInit =
            abi.encodeWithSelector(oftAdapterImpl.initialize.selector, address(this), address(token));
        ERC1967Proxy oftAdapterProxy = new ERC1967Proxy(address(oftAdapterImpl), oftAdapterInit);
        oftAdapter = kOFTAdapterMock(address(oftAdapterProxy));
        oftAdapter.initializeMock(address(this));

        // Grant minter role to the test contract for test setup
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(this));
        vm.stopPrank();

        oftAdapter.setMinter(address(this));
    }

    function testInitialSetup() public view {
        assertEq(oftAdapter.token(), address(token));
        assertEq(oftAdapter.owner(), address(this));
    }

    function testApprovalRequiredIsTrue() public view {
        assertTrue(oftAdapter.approvalRequired());
    }

    function testTokenFunctionReturnsToken() public view {
        assertEq(oftAdapter.token(), address(token));
    }

    function testDebitViewReturnsCorrectAmounts() public view {
        (uint256 sent, uint256 received) = oftAdapter.debitView(1e18, 1e18, 1);
        assertEq(sent, 1e18);
        assertEq(received, 1e18);
    }

    function testRemoveDust() public view {
        uint256 amount = 1.23456789 ether;
        uint256 noDust = oftAdapter.removeDust(amount);
        assertLe(noDust, amount);
    }

    function testToLDandToSD() public view {
        uint64 amountSD = 1000;
        uint256 conversionRate = oftAdapter.decimalConversionRate();
        uint256 amountLD = oftAdapter.toLD(amountSD);
        assertEq(amountLD, amountSD * conversionRate);
        uint256 testLD = 1_000_000;
        uint64 testSD = oftAdapter.toSD(testLD);
        assertEq(testSD, uint64(testLD / conversionRate));
    }

    function testBuildMsgAndOptions() public view {
        SendParam memory param = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(user))),
            amountLD: 1000,
            minAmountLD: 1000,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        (bytes memory msgBytes,) = oftAdapter.buildMsgAndOptions(param, 1000);
        assertGt(msgBytes.length, 0);
    }

    function testInitializeWithZeroAddressReverts() public {
        kOFTAdapterMock o = new kOFTAdapterMock(lzEndpoint, DECIMALS);
        vm.expectRevert();
        o.initialize(address(0), address(token));
        vm.expectRevert();
        o.initialize(owner, address(0));
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        oftAdapter.initialize(owner, address(token));
    }

    function testExposedCredit() public {
        // Fund adapter with tokens
        uint256 amount = 1000;
        token.mint(address(oftAdapter), amount);

        uint256 before = token.balanceOf(user);
        uint256 received = oftAdapter.exposedCredit(user, amount, 1);
        assertEq(received, amount);
        assertEq(token.balanceOf(user), before + amount);
        assertEq(token.balanceOf(address(oftAdapter)), 0);
    }

    function testExposedDebit() public {
        uint256 amount = 1e18;
        // Mint to user and user approves adapter
        token.mint(user, amount);
        vm.prank(user);
        token.approve(address(oftAdapter), amount);

        uint256 userBalanceBefore = token.balanceOf(user);
        uint256 adapterBalanceBefore = token.balanceOf(address(oftAdapter));

        vm.prank(address(this)); // Call debit from authorized minter
        oftAdapter.exposedDebit(user, amount, amount, 1);

        assertEq(token.balanceOf(user), userBalanceBefore - amount);
        assertEq(token.balanceOf(address(oftAdapter)), adapterBalanceBefore + amount);
    }

    function testOnlyOwnerCanUpgrade() public {
        kOFTAdapterV2 newImpl = new kOFTAdapterV2(lzEndpoint, DECIMALS);
        address notOwner = address(0xBEEF);

        vm.prank(notOwner);
        vm.expectRevert();
        IUpgrade(address(oftAdapter)).upgradeTo(address(newImpl));

        vm.prank(address(this));
        vm.expectRevert();
        IUpgrade(address(oftAdapter)).upgradeTo(address(newImpl));
    }
}
