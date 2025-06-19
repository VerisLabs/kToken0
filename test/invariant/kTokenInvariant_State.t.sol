// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./kTokenInvariantSetup.t.sol";

contract kTokenInvariantStateTest is kTokenInvariantSetup {
    function invariant_TokenMetadataImmutable() public view {
        assertEq(token.name(), "Test Token", "Token name should not change");
        assertEq(token.symbol(), "TEST", "Token symbol should not change");
        assertEq(token.decimals(), 18, "Token decimals should not change");
    }

    function invariant_PauseStateConsistency() public view {
        bool isPaused = token.isPaused();
        bool wasBlocked = handler.wasLastOperationBlocked();

        if (isPaused) {
            // If paused, the last operation should have been blocked
            assertTrue(wasBlocked, "Operations should be blocked when paused");
        }
    }

    function invariant_ExpectedVsActualPauseState() public view {
        assertEq(handler.actualPauseState(), handler.expectedPauseState(), "Pause state should match expected");
    }

    function invariant_ActualStateMatchesToken() public view {
        // Verify that actual state in handler matches token state
        assertEq(handler.actualTotalSupply(), token.totalSupply(), "Handler actual total supply should match token");

        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            assertEq(handler.actualBalances(actor), token.balanceOf(actor), "Handler actual balance should match token");
        }

        assertEq(handler.actualPauseState(), token.isPaused(), "Handler actual pause state should match token");
    }

    function invariant_CallSummary() public view {
        handler.callSummary();
    }
}
