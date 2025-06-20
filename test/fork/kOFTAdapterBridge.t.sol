// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { kToken } from "../../src/kToken.sol";

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee, SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

contract kOFTAdapterBridgeTest is Test {
    using OptionsBuilder for bytes;

    // LayerZero EndpointV2 addresses
    address constant ETH_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant BASE_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 constant ETH_EID = 30_101;
    uint32 constant BASE_EID = 30_184;

    address public owner = address(0x1);
    address public admin = address(0x2);
    address public user = address(0x4);

    kToken public ethToken;
    kOFTAdapter public ethOFTAdapter;
    kToken public baseToken;
    kOFTAdapter public baseOFTAdapter;

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_MAINNET");
        vm.createSelectFork(rpcUrl);

        // Deploy kToken and kOFTAdapter for Ethereum as admin
        vm.startPrank(admin);
        kToken ethTokenImpl = new kToken();
        bytes memory ethTokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, "kUSD", "kUSD", 6, owner, admin, address(this));
        ERC1967Proxy ethTokenProxy = new ERC1967Proxy(address(ethTokenImpl), ethTokenInit);
        ethToken = kToken(address(ethTokenProxy));

        kOFTAdapter ethOFTAdapterImpl = new kOFTAdapter(ETH_ENDPOINT, 6);
        bytes memory ethOFTAdapterInit =
            abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner, address(ethToken));
        ERC1967Proxy ethOFTAdapterProxy = new ERC1967Proxy(address(ethOFTAdapterImpl), ethOFTAdapterInit);
        ethOFTAdapter = kOFTAdapter(address(ethOFTAdapterProxy));
        vm.stopPrank();

        // Deploy kToken and kOFTAdapter for Base as admin
        vm.startPrank(admin);
        kToken baseTokenImpl = new kToken();
        bytes memory baseTokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, "kUSD", "kUSD", 6, owner, admin, address(this));
        ERC1967Proxy baseTokenProxy = new ERC1967Proxy(address(baseTokenImpl), baseTokenInit);
        baseToken = kToken(address(baseTokenProxy));

        kOFTAdapter baseOFTAdapterImpl = new kOFTAdapter(BASE_ENDPOINT, 6);
        bytes memory baseOFTAdapterInit =
            abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner, address(baseToken));
        ERC1967Proxy baseOFTAdapterProxy = new ERC1967Proxy(address(baseOFTAdapterImpl), baseOFTAdapterInit);
        baseOFTAdapter = kOFTAdapter(address(baseOFTAdapterProxy));
        vm.stopPrank();

        // Set peers (cross-chain trusted remotes) as owner
        vm.startPrank(owner);
        ethOFTAdapter.setPeer(BASE_EID, bytes32(uint256(uint160(address(baseOFTAdapter)))));
        baseOFTAdapter.setPeer(ETH_EID, bytes32(uint256(uint160(address(ethOFTAdapter)))));
        vm.stopPrank();
    }

    function testSimulateBridgeWithFee() public {
        // Mint tokens to user on Ethereum
        ethToken.mint(user, 1000e6);
        assertEq(ethToken.balanceOf(user), 1000e6);

        // Prepare send params with valid LayerZero options
        uint256 amount = 100e6;
        uint256 minAmount = 100e6;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);
        SendParam memory sendParam =
            SendParam(BASE_EID, bytes32(uint256(uint160(user))), amount, minAmount, options, "", "");
        // Estimate LayerZero fee
        MessagingFee memory fee = ethOFTAdapter.quoteSend(sendParam, false);
        assertGt(fee.nativeFee, 0);

        // User approves adapter to spend tokens
        vm.prank(user);
        ethToken.approve(address(ethOFTAdapter), amount);

        // Simulate a real send (will not deliver on fork, but should not revert)
        vm.prank(user);
        ethOFTAdapter.send{ value: fee.nativeFee }(sendParam, fee, user);

        // Assert that the user's token balance decreased and tokens are locked in adapter
        assertEq(ethToken.balanceOf(user), 900e6);
        assertEq(ethToken.balanceOf(address(ethOFTAdapter)), 100e6);
    }
}
