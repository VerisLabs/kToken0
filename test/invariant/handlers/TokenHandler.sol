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
        if (token.isPaused()) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;
        amount = bound(amount, 1, type(uint128).max);
        vm.prank(minter);
        try token.mint(actor, amount) {
            totalMinted += amount;
            netMinted[actor] += int256(amount);
            mintCalls++;
            _addActor(actor);
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Other errors, do not set wasLastMintOrBurnBlocked
        }
    }

    function burn(uint256 actorSeed, uint256 amount) public countCall("burn") {
        address actor = _getActor(actorSeed);
        if (token.isPaused()) {
            wasLastMintOrBurnBlocked = true;
            return;
        }
        wasLastMintOrBurnBlocked = false;
        uint256 balance = token.balanceOf(actor);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);
        vm.prank(minter);
        try token.burn(actor, amount) {
            totalBurned += amount;
            netMinted[actor] -= int256(amount);
            burnCalls++;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Other errors, do not set wasLastMintOrBurnBlocked
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public countCall("transfer") {
        address from = _getActor(fromSeed);
        address to = _getActor(toSeed);
        if (from == to) return;
        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);
        vm.prank(from);
        try token.transfer(to, amount) {
            netTransferred[from] -= int256(amount);
            netTransferred[to] += int256(amount);
            transferCalls++;
            _addActor(to);
        } catch { }
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) public countCall("approve") {
        address owner_ = _getActor(ownerSeed);
        address spender = _getActor(spenderSeed);
        if (owner_ == spender) return;
        amount = bound(amount, 0, type(uint128).max);
        vm.prank(owner_);
        try token.approve(spender, amount) {
            allowances[owner_][spender] = amount;
            _addActor(spender);
        } catch { }
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
        uint256 balance = token.balanceOf(owner_);
        uint256 allowance = token.allowance(owner_, spender);
        if (balance == 0 || allowance == 0) return;
        amount = bound(amount, 1, balance < allowance ? balance : allowance);
        vm.prank(spender);
        try token.transferFrom(owner_, to, amount) {
            netTransferred[owner_] -= int256(amount);
            netTransferred[to] += int256(amount);
            allowances[owner_][spender] = allowance - amount;
            _addActor(to);
        } catch { }
    }

    function pause(uint256 value) public countCall("pause") {
        // Convert large numbers to boolean using modulo 2
        bool shouldPause = value % 2 == 1;
        vm.prank(admin);
        token.pause(shouldPause);
        wasLastMintOrBurnBlocked = shouldPause;
    }

    function _getActor(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
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
