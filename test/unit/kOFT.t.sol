// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IKToken } from "../../src/interfaces/IKToken.sol";
import { kToken } from "../../src/kToken.sol";
import { kOFTV2 } from "../kOFTV2.sol";
import { MockLayerZeroEndpoint } from "../mocks/MockLayerZeroEndpoint.sol";
import { kOFTMock } from "../mocks/kOFTMock.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

interface IUpgrade {
    function upgradeTo(address newImplementation) external;
}

contract kOFTTest is Test {
    kToken public token;
    kOFTMock public oft;
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
        kToken tokenImpl = new kToken();
        bytes memory tokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, NAME, SYMBOL, DECIMALS, owner, admin, minter);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImpl), tokenInit);
        token = kToken(address(tokenProxy));
        bool isAdmin = token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin);
        assertTrue(isAdmin, "admin should have DEFAULT_ADMIN_ROLE on token");
        vm.deal(admin, 1 ether);
        kOFTMock oftImpl = new kOFTMock(lzEndpoint, DECIMALS);
        bytes memory oftInit = abi.encodeWithSelector(oftImpl.initialize.selector, address(this), address(token));
        ERC1967Proxy oftProxy = new ERC1967Proxy(address(oftImpl), oftInit);
        oft = kOFTMock(address(oftProxy));
        oft.initializeMock(address(this));
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(oft));
        vm.stopPrank();
        oft.setMinter(address(this));
    }

    function testInitialSetup() public {
        assertEq(address(oft.getkOFTStorage()), address(token));
        assertEq(oft.owner(), address(this));
    }

    function testApprovalRequiredIsFalse() public {
        assertEq(oft.approvalRequired(), false);
    }

    function testTokenFunctionReturnsSelf() public {
        assertEq(oft.token(), address(oft));
    }

    function testDebitViewReturnsCorrectAmounts() public {
        vm.prank(minter);
        token.mint(user, 1e18);
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(oft)));
        (uint256 sent, uint256 received) = oft.debitView(1e18, 1e18, 1);
        assertLe(received, 1e18);
    }

    function testRemoveDust() public {
        uint256 amount = 1.23456789 ether;
        uint256 noDust = oft.removeDust(amount);
        assertLe(noDust, amount);
    }

    function testToLDandToSD() public {
        uint64 amountSD = 1000;
        uint256 conversionRate = oft.decimalConversionRate();
        uint256 amountLD = oft.toLD(amountSD);
        emit log_uint(amountLD);
        emit log_uint(amountSD * conversionRate);
        assertEq(amountLD, amountSD * conversionRate);
        uint256 testLD = 1_000_000;
        uint64 testSD = oft.toSD(testLD);
        emit log_uint(testSD);
        emit log_uint(uint64(testLD / conversionRate));
        assertEq(testSD, uint64(testLD / conversionRate));
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

    function testInitializeWithZeroAddressReverts() public {
        kOFTMock o = new kOFTMock(lzEndpoint, DECIMALS);
        vm.expectRevert();
        o.initialize(address(0), address(token));
        vm.expectRevert();
        o.initialize(owner, address(0));
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        oft.initialize(owner, address(token));
    }

    function testExposedCredit() public {
        uint256 before = token.balanceOf(user);
        uint256 received = oft.exposedCredit(user, 1000, 1);
        assertEq(received, 1000);
        assertEq(token.balanceOf(user), before + 1000);
    }

    function testExposedDebit() public {
        uint256 amount = 1e18;
        address from = address(this);
        oft.exposedCredit(from, amount, 1);
        oft.exposedDebit(from, amount, amount, 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testOnlyOwnerCanUpgrade() public {
        kOFTMock newImpl = new kOFTMock(lzEndpoint, DECIMALS);
        address notOwner = address(0xBEEF);
        vm.prank(notOwner);
        vm.expectRevert();
        IUpgrade(address(oft)).upgradeTo(address(newImpl));
        vm.prank(address(this));
        vm.expectRevert();
        IUpgrade(address(oft)).upgradeTo(address(newImpl));
    }
}
