// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./helpers/SetUp.t.sol";

contract kTokenInvariants is SetUp {
    function setUp() public {
        _setUpToken();
    }

    // Single invariant functions following the example pattern
    function invariantkToken__SupplyAccounting() public view {
        handler.INVARIANT_A_TOTAL_SUPPLY();
    }

    function invariantkToken__BalanceAccounting() public view {
        handler.INVARIANT_B_BALANCE_ACCOUNTING();
    }

    function invariantkToken__AllowanceAccounting() public view {
        handler.INVARIANT_C_ALLOWANCE_ACCOUNTING();
    }

    function invariantkToken__AccessControl() public view {
        handler.INVARIANT_D_ACCESS_CONTROL();
    }

    function invariantkToken__PauseState() public view {
        handler.INVARIANT_E_PAUSE_STATE();
    }

    function invariantkToken__CallSummary() public view {
        handler.callSummary();
    }
}
