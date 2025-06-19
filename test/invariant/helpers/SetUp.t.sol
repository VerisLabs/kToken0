// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kToken } from "../../../src/kToken.sol";
import { TokenHandler } from "../handlers/TokenHandler.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { console2 } from "forge-std/console2.sol";

contract SetUp is StdInvariant, Test {
    TokenHandler public handler;
    kToken public token;
    address public owner;
    address public admin;
    address public minter;

    string public constant NAME = "kUSD";
    string public constant SYMBOL = "kUSD";
    uint8 public constant DECIMALS = 6;

    function _setUpToken() public virtual {
        // Setup addresses
        owner = makeAddr("owner");
        admin = address(this); // Make test contract the admin to grant roles
        minter = makeAddr("minter");

        console2.log("Owner:", owner);
        console2.log("Admin:", admin);
        console2.log("Minter:", minter);

        // Deploy token
        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, NAME, SYMBOL, DECIMALS, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));

        console2.log("Token:", address(token));
        console2.log("Implementation:", address(implementation));

        // Deploy handler
        handler = new TokenHandler(token, minter, admin);
        console2.log("Handler:", address(handler));

        // Grant minter role to handler
        console2.log("Granting MINTER_ROLE to handler...");
        token.grantRole(token.MINTER_ROLE(), address(handler));

        // Verify the role was granted
        require(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler should have MINTER_ROLE");

        console2.log("Handler has MINTER_ROLE:", token.hasRole(token.MINTER_ROLE(), address(handler)));
        console2.log("Admin has DEFAULT_ADMIN_ROLE:", token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));

        // Target handler functions for invariant testing
        bytes4[] memory selectors = handler.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));

        // Target the handler contract specifically
        targetContract(address(handler));
    }
}
