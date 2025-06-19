// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./kTokenInvariantSetup.t.sol";

contract kTokenInvariantTransferTest is kTokenInvariantSetup {
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

    function invariant_ExpectedVsActualAllowances() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            for (uint256 j = 0; j < actors.length; j++) {
                if (i != j) {
                    address owner_ = actors[i];
                    address spender = actors[j];
                    assertEq(
                        handler.actualAllowances(owner_, spender),
                        handler.expectedAllowances(owner_, spender),
                        "Allowance should match expected"
                    );
                    assertEq(
                        handler.actualAllowances(owner_, spender),
                        token.allowance(owner_, spender),
                        "Handler actual allowance should match token"
                    );
                }
            }
        }
    }
}
