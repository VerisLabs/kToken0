// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./kTokenInvariantSetup.t.sol";

contract kTokenInvariantAccessTest is kTokenInvariantSetup {
    function invariant_RoleBasedAccessControl() public view {
        // Verify role assignments remain consistent
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler should maintain minter role");

        // Verify owner hasn't changed
        assertEq(token.owner(), owner, "Owner should not change");
    }

    function invariant_RoleConsistency() public view {
        // Admin role checks
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin role lost");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role lost");
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(handler)), "Handler lost minter role");

        // Owner consistency
        assertEq(token.owner(), owner, "Owner changed unexpectedly");
    }

    function testFuzz_RoleManagement(address newMinter, address unauthorizedCaller) public {
        vm.assume(newMinter != address(0));
        vm.assume(unauthorizedCaller != admin && unauthorizedCaller != address(0));
        vm.assume(!token.hasRole(token.DEFAULT_ADMIN_ROLE(), unauthorizedCaller));

        // Ensure admin has the DEFAULT_ADMIN_ROLE
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE");

        // Test granting role by admin
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), newMinter);
        vm.stopPrank();
        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter), "Role should be granted");

        // Test unauthorized role grant
        bytes32 minterRole = token.MINTER_ROLE();
        vm.startPrank(unauthorizedCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                unauthorizedCaller,
                token.DEFAULT_ADMIN_ROLE()
            )
        );
        token.grantRole(minterRole, newMinter);
        vm.stopPrank();

        // Test revoking role by admin
        vm.startPrank(admin);
        token.revokeRole(minterRole, newMinter);
        vm.stopPrank();
        assertFalse(token.hasRole(minterRole, newMinter), "Role should be revoked");

        // Test unauthorized role revocation
        vm.startPrank(unauthorizedCaller);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                unauthorizedCaller,
                token.DEFAULT_ADMIN_ROLE()
            )
        );
        token.revokeRole(minterRole, newMinter);
        vm.stopPrank();

        // Test renouncing role
        vm.startPrank(admin);
        token.grantRole(minterRole, newMinter);
        vm.stopPrank();

        vm.startPrank(newMinter);
        token.renounceRole(minterRole, newMinter);
        vm.stopPrank();
        assertFalse(token.hasRole(minterRole, newMinter), "Role should be renounced");
    }
} 