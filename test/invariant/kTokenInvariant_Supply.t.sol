// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./kTokenInvariantSetup.t.sol";

contract kTokenInvariantSupplyTest is kTokenInvariantSetup {
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

    function invariant_TotalSupplyBoundaries() public view {
        uint256 totalMinted = handler.totalMinted();
        uint256 totalBurned = handler.totalBurned();

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

    function invariant_ExpectedVsActualTotalSupply() public view {
        assertEq(handler.actualTotalSupply(), handler.expectedTotalSupply(), "Total supply should match expected");
    }

    function invariant_ExpectedVsActualBalances() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            assertEq(handler.actualBalances(actor), handler.expectedBalances(actor), "Balance should match expected");
        }
    }
} 