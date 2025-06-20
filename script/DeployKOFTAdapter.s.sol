// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { kOFTAdapter } from "../src/kOFTAdapter.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";

contract DeployKOFTAdapter is Script {
    kOFTAdapter public koftAdapter;
    IERC20 public tokenContract;

    address public lzEndpoint;
    address public owner;

    function run() public {
        lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        tokenContract = IERC20(vm.envAddress("KTOKEN_CONTRACT"));
        owner = vm.envAddress("OWNER");

        vm.startBroadcast();

        kOFTAdapter implementation = new kOFTAdapter(lzEndpoint, 18);
        bytes memory data = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner, address(tokenContract));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        koftAdapter = kOFTAdapter(address(proxy));

        console2.log("owner", owner);
        console2.log("lzEndpoint", lzEndpoint);
        console2.log("tokenContract", address(tokenContract));
        console2.log("implementation", address(implementation));
        console2.log("proxy", address(proxy));
        console2.log("kOFTAdapter deployed at", address(koftAdapter));

        vm.stopBroadcast();
    }
} 