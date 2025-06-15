// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IKToken } from "../src/interfaces/IKToken.sol";
import { kOFT } from "../src/kOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";

contract DeployKOFT is Script {
    kOFT public koft;
    IKToken public tokenContract;

    address public lzEndpoint;
    address public owner;

    function run() public {
        lzEndpoint = vm.envAddress("LZ_ENDPOINT");
        tokenContract = IKToken(vm.envAddress("KTOKEN_CONTRACT"));
        owner = vm.envAddress("OWNER");

        vm.startBroadcast();

        kOFT implementation = new kOFT(lzEndpoint, 18);
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, owner, address(tokenContract));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        koft = kOFT(address(proxy));

        console2.log("owner", owner);
        console2.log("lzEndpoint", lzEndpoint);
        console2.log("tokenContract", address(tokenContract));
        console2.log("implementation", address(implementation));
        console2.log("proxy", address(proxy));
        console2.log("kOFT deployed at", address(koft));

        vm.stopBroadcast();
    }
}
