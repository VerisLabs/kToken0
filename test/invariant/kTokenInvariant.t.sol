// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kToken.sol";

import { TokenHandler } from "./handlers/TokenHandler.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

/// @title kTokenInvariantTest
/// @notice Stateful invariant testing for kToken
contract kTokenInvariantTest is StdInvariant, Test {
    kToken public token;
    TokenHandler public handler;
    address public owner;
    address public admin;
    address public minter;

    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        kToken implementation = new kToken();
        bytes memory data =
            abi.encodeWithSelector(kToken.initialize.selector, "Test Token", "TEST", 18, owner, admin, minter);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));
        handler = new TokenHandler(token, minter, admin);

        // Grant minter role to handler
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(handler));
        vm.stopPrank();

        // Verify roles
        require(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler must have minter role");

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = TokenHandler.mint.selector;
        selectors[1] = TokenHandler.burn.selector;
        selectors[2] = TokenHandler.transfer.selector;
        selectors[3] = TokenHandler.approve.selector;
        selectors[4] = TokenHandler.transferFrom.selector;
        selectors[5] = TokenHandler.pause.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    function invariant_TotalSupplyEqualsNetMinting() public view {
        assertEq(
            token.totalSupply(),
            handler.totalMinted() - handler.totalBurned(),
            "Total supply should equal total minted minus total burned"
        );
    }

    function invariant_BalancesShouldNotExceedTotalSupply() public view {
        address[] memory actors = handler.getActors();
        uint256 totalSupply = token.totalSupply();
        for (uint256 i = 0; i < actors.length; i++) {
            address currentAccount = actors[i];
            assertLe(token.balanceOf(currentAccount), totalSupply, "Individual balance should not exceed total supply");
        }
    }

    function invariant_BalanceAccountingConsistency() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            address currentAccount = actors[i];
            uint256 currentBalance = token.balanceOf(currentAccount);
            int256 netMinted = handler.getNetMinted(currentAccount);
            int256 netTransferred = handler.getNetTransferred(currentAccount);
            int256 expected = netMinted + netTransferred;
            if (expected >= 0) {
                assertEq(int256(currentBalance), expected, "Balance should equal net minted plus net transferred");
            }
        }
    }

    function invariant_TokenMetadataImmutable() public view {
        assertEq(token.name(), "Test Token", "Token name should not change");
        assertEq(token.symbol(), "TEST", "Token symbol should not change");
        assertEq(token.decimals(), 18, "Token decimals should not change");
    }

    function invariant_AllowanceAccountingConsistency() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            for (uint256 j = 0; j < actors.length; j++) {
                if (i != j) {
                    address currentOwner = actors[i];
                    address spender = actors[j];
                    uint256 allowance = token.allowance(currentOwner, spender);
                    uint256 recorded = handler.getAllowance(currentOwner, spender);
                    assertLe(allowance, recorded, "Current allowance should not exceed the originally approved amount");
                }
            }
        }
    }

    function invariant_RoleBasedAccessControl() public view {
        // Verify role assignments remain consistent
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler should maintain minter role");

        // Verify owner hasn't changed
        assertEq(token.owner(), owner, "Owner should not change");
    }

    function invariant_PauseStateConsistency() public view {
        bool isPaused = token.isPaused();
        bool wasBlocked = handler.wasLastOperationBlocked();

        if (isPaused) {
            // If paused, the last operation should have been blocked
            assertTrue(wasBlocked, "Operations should be blocked when paused");
        }
    }

    function invariant_TotalSupplyBoundaries() public view {
        // Check that total minted and burned are within uint256 bounds
        uint256 totalMinted = handler.totalMinted();
        uint256 totalBurned = handler.totalBurned();

        // These assertions will fail if there was an overflow
        assertLt(totalMinted, type(uint256).max, "Total minted should not overflow");
        assertLt(totalBurned, type(uint256).max, "Total burned should not overflow");
        assertLe(totalBurned, totalMinted, "Cannot burn more than minted");
    }

    function invariant_SumOfBalancesEqualsSupply() public view {
        address[] memory actors = handler.getActors();
        uint256 totalBalance = 0;

        for (uint256 i = 0; i < actors.length; i++) {
            totalBalance += token.balanceOf(actors[i]);
        }

        assertEq(totalBalance, token.totalSupply(), "Sum of all balances should equal total supply");
    }

    function invariant_CallSummary() public view {
        handler.callSummary();
    }

    function invariant_TransferSanityChecks() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            // Balance should never be negative (redundant with uint256 but explicit check)
            assertTrue(token.balanceOf(actor) >= 0, "Balance should never be negative");
            // Balance should never exceed total supply
            assertTrue(token.balanceOf(actor) <= token.totalSupply(), "Balance should not exceed total supply");
        }
    }

    function invariant_PausedStateChecks() public view {
        bool isPaused = token.isPaused();
        bool wasBlocked = handler.wasLastOperationBlocked();

        if (isPaused) {
            // If paused, verify operations are blocked
            assertTrue(wasBlocked, "Operations should be blocked when paused");
        }
    }

    function invariant_RoleConsistency() public view {
        // Admin role checks
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin role lost");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role lost");
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler lost minter role");

        // Owner consistency
        assertEq(token.owner(), owner, "Owner changed unexpectedly");
    }
}
