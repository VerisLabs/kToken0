// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../../src/kToken.sol";
import "forge-std/Test.sol";

/// @title TokenHandler
/// @notice Handler contract for kToken invariant testing
contract TokenHandler is Test {
    kToken public immutable token;
    address public immutable minter;
    address public immutable admin;
    
    // Expected state
    uint256 public expectedTotalSupply;
    mapping(address => uint256) public expectedBalances;
    mapping(address => mapping(address => uint256)) public expectedAllowances;
    bool public expectedPauseState;
    
    // Actual state
    uint256 public actualTotalSupply;
    mapping(address => uint256) public actualBalances;
    mapping(address => mapping(address => uint256)) public actualAllowances;
    bool public actualPauseState;
    
    // Operation tracking
    uint256 public totalMinted;
    uint256 public totalBurned;
    uint256 public mintCalls;
    uint256 public burnCalls;
    uint256 public transferCalls;
    bool public wasLastMintOrBurnBlocked;
    address[] public actors;
    mapping(address => bool) public isActor;
    mapping(address => int256) public netMinted;
    mapping(address => int256) public netTransferred;
    mapping(address => mapping(address => uint256)) public allowances;
    uint256 public constant MAX_ACTORS = 20;

    // Add call tracking
    mapping(string => uint256) public calls;

    modifier countCall(string memory name) {
        calls[name]++;
        _;
    }

    constructor(kToken _token, address _minter, address _admin) {
        token = _token;
        minter = _minter;
        admin = _admin;
        
        // Initialize state tracking
        actualTotalSupply = _token.totalSupply();
        actualPauseState = _token.isPaused();
        expectedTotalSupply = actualTotalSupply;
        expectedPauseState = actualPauseState;
    }

    modifier createActorIfNew(address actor) {
        _;
    }

    function _addActor(address actor) internal {
        if (actor != address(0) && actor != address(token) && !isActor[actor] && actors.length < MAX_ACTORS) {
            actors.push(actor);
            isActor[actor] = true;
        }
    }

    function getActors() public view returns (address[] memory) {
        return actors;
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

    function mint(uint256 actorSeed, uint256 amount) public countCall("mint") {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 1, type(uint128).max);
        
        // Get current state right before operation
        uint256 currentTotalSupply = token.totalSupply();
        uint256 currentBalance = token.balanceOf(actor);
        bool currentPauseState = token.isPaused();
        
        if (currentPauseState) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;
        
        // Set expected state based on current state
        expectedTotalSupply = currentTotalSupply + amount;
        expectedBalances[actor] = currentBalance + amount;
        
        vm.prank(minter);
        try token.mint(actor, amount) {
            // Update actual state
            actualTotalSupply = token.totalSupply();
            actualBalances[actor] = token.balanceOf(actor);
            actualPauseState = token.isPaused();
            
            // Update tracking variables
            totalMinted += amount;
            netMinted[actor] += int256(amount);
            mintCalls++;
            _addActor(actor);
        } catch Error(string memory reason) {
            // Revert expected state if operation failed
            expectedTotalSupply = currentTotalSupply;
            expectedBalances[actor] = currentBalance;
            
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Revert expected state if operation failed
            expectedTotalSupply = currentTotalSupply;
            expectedBalances[actor] = currentBalance;
        }
    }

    function burn(uint256 actorSeed, uint256 amount) public countCall("burn") {
        address actor = _getActor(actorSeed);
        
        // Get current state right before operation
        uint256 currentTotalSupply = token.totalSupply();
        uint256 currentBalance = token.balanceOf(actor);
        bool currentPauseState = token.isPaused();
        
        if (currentPauseState) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;
        
        if (currentBalance == 0) return;
        amount = bound(amount, 1, currentBalance);
        
        // Set expected state based on current state
        expectedTotalSupply = currentTotalSupply - amount;
        expectedBalances[actor] = currentBalance - amount;
        
        vm.prank(minter);
        try token.burn(actor, amount) {
            // Update actual state
            actualTotalSupply = token.totalSupply();
            actualBalances[actor] = token.balanceOf(actor);
            actualPauseState = token.isPaused();
            
            // Update tracking variables
            totalBurned += amount;
            netMinted[actor] -= int256(amount);
            burnCalls++;
        } catch Error(string memory reason) {
            // Revert expected state if operation failed
            expectedTotalSupply = currentTotalSupply;
            expectedBalances[actor] = currentBalance;
            
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Revert expected state if operation failed
            expectedTotalSupply = currentTotalSupply;
            expectedBalances[actor] = currentBalance;
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public countCall("transfer") {
        address from = _getActor(fromSeed);
        address to = _getActor(toSeed);
        if (from == to) return;
        
        // Get current state right before operation
        uint256 currentFromBalance = token.balanceOf(from);
        uint256 currentToBalance = token.balanceOf(to);
        bool currentPauseState = token.isPaused();
        
        if (currentFromBalance == 0) return;
        amount = bound(amount, 1, currentFromBalance);
        
        // Set expected state based on current state
        expectedBalances[from] = currentFromBalance - amount;
        expectedBalances[to] = currentToBalance + amount;
        
        vm.prank(from);
        try token.transfer(to, amount) {
            // Update actual state
            actualBalances[from] = token.balanceOf(from);
            actualBalances[to] = token.balanceOf(to);
            actualTotalSupply = token.totalSupply();
            actualPauseState = token.isPaused();
            
            // Update tracking variables
            netTransferred[from] -= int256(amount);
            netTransferred[to] += int256(amount);
            transferCalls++;
            _addActor(to);
        } catch {
            // Revert expected state if operation failed
            expectedBalances[from] = currentFromBalance;
            expectedBalances[to] = currentToBalance;
        }
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) public countCall("approve") {
        address owner_ = _getActor(ownerSeed);
        address spender = _getActor(spenderSeed);
        if (owner_ == spender) return;
        amount = bound(amount, 0, type(uint128).max);
        
        // Get current state right before operation
        uint256 currentAllowance = token.allowance(owner_, spender);
        bool currentPauseState = token.isPaused();
        
        // Set expected state based on current state
        expectedAllowances[owner_][spender] = amount;
        
        vm.prank(owner_);
        try token.approve(spender, amount) {
            // Update actual state
            actualAllowances[owner_][spender] = token.allowance(owner_, spender);
            actualPauseState = token.isPaused();
            allowances[owner_][spender] = amount;
            _addActor(spender);
        } catch {
            // Revert expected state if operation failed
            expectedAllowances[owner_][spender] = currentAllowance;
        }
    }

    function transferFrom(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 toSeed,
        uint256 amount
    )
        public
        createActorIfNew(_getActor(toSeed))
        countCall("transferFrom")
    {
        address owner_ = _getActor(ownerSeed);
        address spender = _getActor(spenderSeed);
        address to = _getActor(toSeed);
        if (owner_ == spender || owner_ == to || spender == to) return;
        
        // Get current state right before operation
        uint256 currentOwnerBalance = token.balanceOf(owner_);
        uint256 currentToBalance = token.balanceOf(to);
        uint256 currentAllowance = token.allowance(owner_, spender);
        bool currentPauseState = token.isPaused();
        
        if (currentOwnerBalance == 0 || currentAllowance == 0) return;
        amount = bound(amount, 1, currentOwnerBalance < currentAllowance ? currentOwnerBalance : currentAllowance);
        
        // Set expected state based on current state
        expectedBalances[owner_] = currentOwnerBalance - amount;
        expectedBalances[to] = currentToBalance + amount;
        expectedAllowances[owner_][spender] = currentAllowance - amount;
        
        vm.prank(spender);
        try token.transferFrom(owner_, to, amount) {
            // Update actual state
            actualBalances[owner_] = token.balanceOf(owner_);
            actualBalances[to] = token.balanceOf(to);
            actualAllowances[owner_][spender] = token.allowance(owner_, spender);
            actualTotalSupply = token.totalSupply();
            actualPauseState = token.isPaused();
            
            // Update tracking variables
            netTransferred[owner_] -= int256(amount);
            netTransferred[to] += int256(amount);
            allowances[owner_][spender] = currentAllowance - amount;
            _addActor(to);
        } catch {
            // Revert expected state if operation failed
            expectedBalances[owner_] = currentOwnerBalance;
            expectedBalances[to] = currentToBalance;
            expectedAllowances[owner_][spender] = currentAllowance;
        }
    }

    function pause(uint256 value) public countCall("pause") {
        // Convert large numbers to boolean using modulo 2
        bool shouldPause = value % 2 == 1;
        
        // Set expected state
        expectedPauseState = shouldPause;
        
        vm.prank(admin);
        try token.pause(shouldPause) {
            // Update actual state
            actualPauseState = token.isPaused();
            wasLastMintOrBurnBlocked = shouldPause;
        } catch {
            // If the pause fails, revert expected state
            expectedPauseState = !shouldPause;
        }
    }

    function _getActor(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }

    function getEntryPoints() public pure returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](6);
        _entryPoints[0] = this.mint.selector;
        _entryPoints[1] = this.burn.selector;
        _entryPoints[2] = this.transfer.selector;
        _entryPoints[3] = this.approve.selector;
        _entryPoints[4] = this.transferFrom.selector;
        _entryPoints[5] = this.pause.selector;
        return _entryPoints;
    }

    function callSummary() public view {
        console.log("Call Summary:");
        console.log("-------------------");
        console.log("mint:", calls["mint"]);
        console.log("burn:", calls["burn"]);
        console.log("transfer:", calls["transfer"]);
        console.log("approve:", calls["approve"]);
        console.log("transferFrom:", calls["transferFrom"]);
        console.log("pause:", calls["pause"]);
        console.log("-------------------");
    }
}
