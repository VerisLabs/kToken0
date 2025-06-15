// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kOFT } from "../../src/kOFT.sol";
import { kToken } from "../../src/kToken.sol";

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

contract BridgeSimulationForkTest is Test {
    using OptionsBuilder for bytes;

    // LayerZero EndpointV2 addresses
    address constant ETH_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant BASE_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 constant ETH_EID = 30_101;
    uint32 constant BASE_EID = 30_184;

    address public owner = address(0x1);
    address public admin = address(0x2);
    address public minter = address(0x3);
    address public user = address(0x4);

    kToken public ethToken;
    kOFT public ethOFT;
    kToken public baseToken;
    kOFT public baseOFT;

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_MAINNET");
        vm.createSelectFork(rpcUrl);

        // Deploy kToken and kOFT for Ethereum as admin
        vm.startPrank(admin);
        kToken ethTokenImpl = new kToken();
        bytes memory ethTokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, "kUSD", "kUSD", 6, owner, admin, minter);
        ERC1967Proxy ethTokenProxy = new ERC1967Proxy(address(ethTokenImpl), ethTokenInit);
        ethToken = kToken(address(ethTokenProxy));

        kOFT ethOFTImpl = new kOFT(ETH_ENDPOINT, 6);
        bytes memory ethOFTInit = abi.encodeWithSelector(kOFT.initialize.selector, owner, address(ethToken));
        ERC1967Proxy ethOFTProxy = new ERC1967Proxy(address(ethOFTImpl), ethOFTInit);
        ethOFT = kOFT(address(ethOFTProxy));

        // Grant MINTER_ROLE to ethOFT
        ethToken.grantRole(ethToken.MINTER_ROLE(), address(ethOFT));
        vm.stopPrank();

        // Deploy kToken and kOFT for Base as admin
        vm.startPrank(admin);
        kToken baseTokenImpl = new kToken();
        bytes memory baseTokenInit =
            abi.encodeWithSelector(kToken.initialize.selector, "kUSD", "kUSD", 6, owner, admin, minter);
        ERC1967Proxy baseTokenProxy = new ERC1967Proxy(address(baseTokenImpl), baseTokenInit);
        baseToken = kToken(address(baseTokenProxy));

        kOFT baseOFTImpl = new kOFT(BASE_ENDPOINT, 6);
        bytes memory baseOFTInit = abi.encodeWithSelector(kOFT.initialize.selector, owner, address(baseToken));
        ERC1967Proxy baseOFTProxy = new ERC1967Proxy(address(baseOFTImpl), baseOFTInit);
        baseOFT = kOFT(address(baseOFTProxy));

        // Grant MINTER_ROLE to baseOFT
        baseToken.grantRole(baseToken.MINTER_ROLE(), address(baseOFT));
        vm.stopPrank();

        // Set peers (cross-chain trusted remotes) as owner
        vm.startPrank(owner);
        ethOFT.setPeer(BASE_EID, bytes32(uint256(uint160(address(baseOFT)))));
        baseOFT.setPeer(ETH_EID, bytes32(uint256(uint160(address(ethOFT)))));
        vm.stopPrank();
    }

    function testSimulateBridgeWithFee() public {
        // Mint tokens to user on Ethereum
        vm.prank(minter);
        ethToken.mint(user, 1000e6);
        assertEq(ethToken.balanceOf(user), 1000e6);

        // Prepare send params with valid LayerZero options
        uint256 amount = 100e6;
        uint256 minAmount = 100e6;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);
        SendParam memory sendParam =
            SendParam(BASE_EID, bytes32(uint256(uint160(user))), amount, minAmount, options, "", "");
        // Estimate LayerZero fee
        MessagingFee memory fee = ethOFT.quoteSend(sendParam, false);
        assertGt(fee.nativeFee, 0);

        // Simulate a real send (will not deliver on fork, but should not revert)
        vm.prank(user);
        ethOFT.send{ value: fee.nativeFee }(sendParam, fee, user);

        // Assert that the user's token balance decreased by the amount
        assertEq(ethToken.balanceOf(user), 900e6);
    }
}
