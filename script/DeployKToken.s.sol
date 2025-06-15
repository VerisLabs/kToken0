// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kToken } from "../src/kToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";

contract DeployKToken is Script {
    kToken public token;

    address public owner;
    address public admin;
    address public minter;

    string public name;
    string public symbol;
    uint8 public decimals;

    function run() public {
        name = "kUSD Token";
        symbol = "kUSD";
        decimals = 18;

        owner = vm.envAddress("OWNER");
        admin = vm.envAddress("ADMIN");
        minter = vm.envAddress("MINTER");

        vm.startBroadcast();

        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, name, symbol, decimals, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));

        console2.log("name", name);
        console2.log("symbol", symbol);
        console2.log("decimals", decimals);
        console2.log("owner", owner);
        console2.log("admin", admin);
        console2.log("minter", minter);
        console2.log("implementation", address(implementation));
        console2.log("proxy", address(proxy));
        console2.log("token deployed at", address(token));
        vm.stopBroadcast();
    }
}
