// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kToken.sol";

import { TokenHandler } from "./handlers/TokenHandler.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
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

    function testFuzz_PermitReplay(uint256 ownerPrivateKey, address spender, uint256 value, uint256 deadline) public {
        vm.assume(ownerPrivateKey != 0 && ownerPrivateKey < type(uint160).max);
        vm.assume(spender != address(0));

        // Generate owner address from private key
        address signer = vm.addr(ownerPrivateKey);

        // Ensure deadline is in the future
        deadline = bound(deadline, block.timestamp + 1, type(uint256).max);

        // Get the current nonce
        uint256 nonce = token.nonces(signer);

        // Get domain separator
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();

        // Get permit typehash
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        // Create permit signature
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // First permit should succeed
        token.permit(signer, spender, value, deadline, v, r, s);

        // Attempt to replay the same permit
        // Note: We don't know the exact recovered address, but we know it will be different
        // from the expected signer, so we just check for the error type
        vm.expectRevert();
        token.permit(signer, spender, value, deadline, v, r, s);

        // Verify nonce increased only once
        assertEq(token.nonces(signer), nonce + 1, "Nonce should increase only once");
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

    function testFuzz_PermitExpiredDeadline(
        uint256 deadline,
        uint256 ownerPrivateKey,
        address spender,
        uint256 value
    )
        public
    {
        vm.assume(ownerPrivateKey != 0 && ownerPrivateKey < type(uint160).max);
        vm.assume(spender != address(0));

        // Generate owner address from private key
        address signer = vm.addr(ownerPrivateKey);

        // Bound deadline to be in the past
        deadline = bound(deadline, 0, block.timestamp - 1);

        // Get the current nonce
        uint256 nonce = token.nonces(signer);

        // Get domain separator
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();

        // Get permit typehash
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        // Create permit signature
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, signer, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // Test expired permit
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("ERC2612ExpiredSignature(uint256)")), deadline));
        token.permit(signer, spender, value, deadline, v, r, s);

        // Verify state hasn't changed
        assertEq(token.nonces(signer), nonce, "Nonce should not increase for expired permit");
        assertEq(token.allowance(signer, spender), 0, "Allowance should not change for expired permit");
    }
}
