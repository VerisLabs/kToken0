// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kToken.sol";
import { TokenHandler } from "./handlers/TokenHandler.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

abstract contract kTokenInvariantSetup is StdInvariant, Test {
    kToken public token;
    TokenHandler public handler;
    address public owner;
    address public admin;
    address public minter;

    function setUp() public virtual {
        // Setup addresses
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        minter = makeAddr("minter");

        // Deploy token
        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, "Test Token", "TEST", 18, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));

        // Deploy handler
        handler = new TokenHandler(token, minter, admin);

        // Grant minter role to handler
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(handler));
        vm.stopPrank();

        // Verify roles
        require(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler must have minter role");

        // Target the handler contract and its functions
        targetContract(address(handler));
        // Get the entry points from the handler
        bytes4[] memory selectors = handler.getEntryPoints();
        // Target the handler contract and its functions
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }
}
