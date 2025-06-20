// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

/// @title kTokenInvariantTest
/// @notice Stateful invariant testing for kToken
contract kTokenInvariantTest is Test {
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
            assertLe(token.balanceOf(actors[i]), totalSupply, "Individual balance should not exceed total supply");
        }
    }

    function invariant_BalanceAccountingConsistency() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            address actor = actors[i];
            uint256 currentBalance = token.balanceOf(actor);
            int256 netMinted = handler.getNetMinted(actor);
            int256 netTransferred = handler.getNetTransferred(actor);
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
}

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
    uint256 public constant MAX_ACTORS = 20;

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

    function wasLastOperationBlocked() public view returns (bool) {
        return wasLastMintOrBurnBlocked;
    }

    function mint(uint256 actorSeed, uint256 amount) public {
        address to = _getActor(actorSeed);
        amount = bound(amount, 1, type(uint128).max);
        wasLastMintOrBurnBlocked = false;
        vm.prank(minter);
        try token.mint(to, amount) {
            totalMinted += amount;
            netMinted[to] += int256(amount);
            mintCalls++;
            _addActor(to);
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Other errors, do not set wasLastMintOrBurnBlocked
        }
    }

    function burn(uint256 actorSeed, uint256 amount) public {
        address from = _getActor(actorSeed);
        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;
        amount = bound(amount, 1, balance);
        wasLastMintOrBurnBlocked = false;
        vm.prank(minter);
        try token.burn(from, amount) {
            totalBurned += amount;
            netMinted[from] -= int256(amount);
            burnCalls++;
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Paused()"))) {
                wasLastMintOrBurnBlocked = true;
            }
        } catch {
            // Other errors, do not set wasLastMintOrBurnBlocked
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
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

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) public {
        address owner_ = _getActor(ownerSeed);
        address spender = _getActor(spenderSeed);
        if (owner_ == spender) return;
        amount = bound(amount, 0, type(uint128).max);
        vm.prank(owner_);
        try token.approve(spender, amount) { } catch { }
    }

    function transferFrom(
        uint256 ownerSeed,
        uint256 spenderSeed,
        uint256 toSeed,
        uint256 amount
    )
        public
        createActorIfNew(_getActor(toSeed))
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
            _addActor(to);
        } catch { }
    }

    function pause(uint256 shouldPause) public {
        bool pauseState = (shouldPause % 2 == 0);
        vm.prank(admin);
        try token.pause(pauseState) { } catch { }
    }

    function _getActor(uint256 seed) internal view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
    }
}
