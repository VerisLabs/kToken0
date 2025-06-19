// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../../src/kToken.sol";
import { BaseHandler, console2 } from "./BaseHandler.sol";

/// @title TokenHandler
/// @notice Handler contract for kToken invariant testing
contract TokenHandler is BaseHandler {
    kToken public immutable token;
    address public immutable minter;
    address public immutable admin;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Expected state
    uint256 public expectedTotalSupply;
    mapping(address => uint256) public expectedBalances;
    mapping(address => mapping(address => uint256)) public expectedAllowances;
    bool public expectedPauseState;

    // Operation tracking
    uint256 public totalMinted;
    uint256 public totalBurned;
    uint256 public mintCalls;
    uint256 public burnCalls;
    uint256 public transferCalls;
    bool public wasLastMintOrBurnBlocked;
    mapping(address => int256) public netMinted;
    mapping(address => int256) public netTransferred;
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(kToken _token, address _minter, address _admin) BaseHandler() {
        token = _token;
        minter = _minter;
        admin = _admin;

        // Initialize state tracking
        expectedTotalSupply = _token.totalSupply();
        expectedPauseState = _token.isPaused();

        // Add initial actors
        _addNewActor(address(this));
        _addNewActor(minter);
        _addNewActor(admin);
    }

    function getNetMinted(address a) public view returns (int256) {
        return netMinted[a];
    }

    function getNetTransferred(address a) public view returns (int256) {
        return netTransferred[a];
    }

    function getAllowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function wasLastOperationBlocked() public view returns (bool) {
        return wasLastMintOrBurnBlocked;
    }

    function mint(uint256 amount) public createActor countCall(keccak256("mint")) {
        amount = bound(amount, 1, type(uint128).max);
        if (currentActor == address(token)) return;

        // Get current state right before operation
        uint256 currentTotalSupply = token.totalSupply();
        uint256 currentBalance = token.balanceOf(currentActor);
        bool currentPauseState = token.isPaused();

        if (currentPauseState) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;

        vm.prank(minter);
        try token.mint(currentActor, amount) {
            // Update tracking variables only on success
            totalMinted += amount;
            netMinted[currentActor] += int256(amount);
            mintCalls++;

            // Update expected state after successful operation
            expectedTotalSupply = token.totalSupply();
            expectedBalances[currentActor] = token.balanceOf(currentActor);
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Operation failed, don't update anything
        }
    }

    function burn(uint256 actorSeed, uint256 amount) public useActor(actorSeed) countCall(keccak256("burn")) {
        if (currentActor == address(token)) return;

        // Get current state right before operation
        uint256 currentTotalSupply = token.totalSupply();
        uint256 currentBalance = token.balanceOf(currentActor);
        bool currentPauseState = token.isPaused();

        if (currentPauseState) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;

        if (currentBalance == 0) return;
        amount = bound(amount, 1, currentBalance);

        vm.prank(minter);
        try token.burn(currentActor, amount) {
            // Update tracking variables only on success
            totalBurned += amount;
            netMinted[currentActor] -= int256(amount);
            burnCalls++;

            // Update expected state after successful operation
            expectedTotalSupply = token.totalSupply();
            expectedBalances[currentActor] = token.balanceOf(currentActor);
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Operation failed, don't update anything
        }
    }

    function transfer(
        uint256 fromSeed,
        uint256 toSeed,
        uint256 amount
    )
        public
        useActor(fromSeed)
        countCall(keccak256("transfer"))
    {
        // Get the 'to' address using a different actor seed
        address[] memory allActors = actors();
        if (allActors.length == 0) return;
        address to = allActors[bound(toSeed, 0, allActors.length - 1)];
        if (currentActor == to || currentActor == address(token) || to == address(token)) return;

        // Get current state right before operation
        uint256 currentFromBalance = token.balanceOf(currentActor);
        uint256 currentToBalance = token.balanceOf(to);

        if (currentFromBalance == 0) return;
        amount = bound(amount, 1, currentFromBalance);

        vm.prank(currentActor);
        try token.transfer(to, amount) {
            // Update tracking variables only on success
            netTransferred[currentActor] -= int256(amount);
            netTransferred[to] += int256(amount);
            transferCalls++;
            _addNewActor(to);

            // Update expected state after successful operation
            expectedBalances[currentActor] = token.balanceOf(currentActor);
            expectedBalances[to] = token.balanceOf(to);
        } catch {
            // Operation failed, don't update anything
        }
    }

    function approve(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 amount
    )
        public
        useActor(ownerSeed)
        countCall(keccak256("approve"))
    {
        // Get the spender address using a different actor seed
        address[] memory allActors = actors();
        if (allActors.length == 0) return;
        address spender = allActors[bound(spenderSeed, 0, allActors.length - 1)];
        if (currentActor == spender || currentActor == address(token) || spender == address(token)) return;
        amount = bound(amount, 0, type(uint128).max);

        vm.prank(currentActor);
        try token.approve(spender, amount) {
            allowances[currentActor][spender] = amount;
            expectedAllowances[currentActor][spender] = token.allowance(currentActor, spender);
            _addNewActor(spender);
        } catch {
            // Operation failed, don't update anything
        }
    }

    function transferFrom(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 toSeed
    )
        public
        useActor(spenderSeed)
        countCall(keccak256("transferFrom"))
    {
        // Get the owner and to addresses using different actor seeds
        address[] memory allActors = actors();
        if (allActors.length == 0) return;
        address owner_ = allActors[bound(ownerSeed, 0, allActors.length - 1)];
        address to = allActors[bound(toSeed, 0, allActors.length - 1)];
        if (
            currentActor == owner_ || currentActor == to || owner_ == to || currentActor == address(token)
                || owner_ == address(token) || to == address(token)
        ) return;

        // Get current state right before operation
        uint256 currentOwnerBalance = token.balanceOf(owner_);
        uint256 currentAllowance = token.allowance(owner_, currentActor);

        if (currentOwnerBalance == 0 || currentAllowance == 0) return;
        uint256 amount =
            bound(1, currentOwnerBalance < currentAllowance ? currentOwnerBalance : currentAllowance, type(uint128).max);

        vm.prank(currentActor);
        try token.transferFrom(owner_, to, amount) {
            // Update tracking variables only on success
            netTransferred[owner_] -= int256(amount);
            netTransferred[to] += int256(amount);
            allowances[owner_][currentActor] = token.allowance(owner_, currentActor);

            // Update expected state after successful operation
            expectedBalances[owner_] = token.balanceOf(owner_);
            expectedBalances[to] = token.balanceOf(to);
            expectedAllowances[owner_][currentActor] = token.allowance(owner_, currentActor);
            _addNewActor(to);
        } catch {
            // Operation failed, don't update anything
        }
    }

    function pause(uint256 value) public countCall(keccak256("pause")) {
        // Convert large numbers to boolean using modulo 2
        bool shouldPause = value % 2 == 1;

        vm.prank(admin);
        try token.pause(shouldPause) {
            expectedPauseState = token.isPaused();
            wasLastMintOrBurnBlocked = shouldPause;
        } catch {
            // If the pause fails, don't update expected state
        }
    }

    function grantRole(uint256 actorSeed, uint256 roleSeed) public countCall(keccak256("grantRole")) {
        // Get a random actor to grant the role to
        address[] memory allActors = actors();
        if (allActors.length == 0) return;
        address to = allActors[bound(actorSeed, 0, allActors.length - 1)];
        if (to == address(token)) return;

        // Get a random role
        bytes32 role = bytes32(roleSeed);

        // Only admin can grant roles
        vm.prank(admin);
        try token.grantRole(role, to) {
            // Role granted successfully
            _addNewActor(to);
        } catch {
            // Role grant failed
        }
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](7);
        _entryPoints[0] = this.mint.selector;
        _entryPoints[1] = this.burn.selector;
        _entryPoints[2] = this.transfer.selector;
        _entryPoints[3] = this.approve.selector;
        _entryPoints[4] = this.transferFrom.selector;
        _entryPoints[5] = this.pause.selector;
        _entryPoints[6] = this.grantRole.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("Call Summary:");
        console2.log("-------------------");
        console2.log("mint:", calls[keccak256("mint")]);
        console2.log("burn:", calls[keccak256("burn")]);
        console2.log("transfer:", calls[keccak256("transfer")]);
        console2.log("approve:", calls[keccak256("approve")]);
        console2.log("transferFrom:", calls[keccak256("transferFrom")]);
        console2.log("pause:", calls[keccak256("pause")]);
        console2.log("grantRole:", calls[keccak256("grantRole")]);
        console2.log("-------------------");
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    function INVARIANT_A_TOTAL_SUPPLY() public view {
        // Basic supply check
        assertEq(
            token.totalSupply(), totalMinted - totalBurned, "Total supply should equal total minted minus total burned"
        );

        // Sum of balances equals total supply
        uint256 totalBalance = 0;
        address[] memory allActors = actors();
        for (uint256 i = 0; i < allActors.length; i++) {
            totalBalance += token.balanceOf(allActors[i]);
        }
        assertEq(totalBalance, token.totalSupply(), "Sum of all balances should equal total supply");

        // Supply boundaries
        assertLe(totalBurned, totalMinted, "Cannot burn more than minted");
    }

    function INVARIANT_B_BALANCE_ACCOUNTING() public view {
        address[] memory allActors = actors();
        for (uint256 i = 0; i < allActors.length; i++) {
            address actor = allActors[i];
            uint256 balance = token.balanceOf(actor);

            // Balance matches net operations
            int256 expected = netMinted[actor] + netTransferred[actor];
            if (expected >= 0) {
                assertEq(int256(balance), expected, "Balance should match net operations");
            }

            // Balance cannot exceed total supply
            assertLe(balance, token.totalSupply(), "Balance cannot exceed total supply");
        }
    }

    function INVARIANT_C_ALLOWANCE_ACCOUNTING() public view {
        address[] memory allActors = actors();
        for (uint256 i = 0; i < allActors.length; i++) {
            for (uint256 j = 0; j < allActors.length; j++) {
                if (i != j) {
                    address owner = allActors[i];
                    address spender = allActors[j];

                    // Current allowance cannot exceed originally approved amount
                    assertLe(
                        token.allowance(owner, spender),
                        allowances[owner][spender],
                        "Allowance cannot exceed approved amount"
                    );
                }
            }
        }
    }

    function INVARIANT_D_ACCESS_CONTROL() public view {
        // Core role assignments
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role should be maintained");
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(this)), "Handler must have minter role");
    }

    function INVARIANT_E_PAUSE_STATE() public view {
        // Operation blocking when paused
        if (token.isPaused()) {
            assertTrue(wasLastMintOrBurnBlocked, "Operations should be blocked when paused");
        }
    }
}
