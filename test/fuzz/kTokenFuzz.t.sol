    // SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

/// @title kTokenFuzzTest
/// @notice Comprehensive fuzz testing suite for kToken
/// @dev Tests cover stateless fuzzing, invariant testing, and edge cases
contract kTokenFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    kToken public token;

    // Test addresses
    address public owner;
    address public admin;
    address public minter;
    address public alice;
    address public bob;
    address public charlie;

    // Test constants
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;

    // Invariant tracking
    uint256 public totalMinted;
    uint256 public totalBurned;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Create test addresses
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy token using proxy pattern
        kToken implementation = new kToken();
        bytes memory data = abi.encodeWithSelector(
            kToken.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, owner, admin, minter
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        token = kToken(address(proxy));

        // Reset invariant tracking
        totalMinted = 0;
        totalBurned = 0;
    }

    /*//////////////////////////////////////////////////////////////
                        STATELESS FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test mint function with valid parameters
    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);

        uint256 balanceBefore = token.balanceOf(to);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(minter);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), balanceBefore + amount);
        assertEq(token.totalSupply(), totalSupplyBefore + amount);
        totalMinted += amount;
    }

    /// @notice Fuzz test burn function with valid parameters
    function testFuzz_Burn(address from, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(from != address(token));
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(burnAmount > 0);
        vm.assume(burnAmount <= mintAmount);

        vm.prank(minter);
        token.mint(from, mintAmount);

        uint256 balanceBefore = token.balanceOf(from);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(minter);
        token.burn(from, burnAmount);

        assertEq(token.balanceOf(from), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        totalBurned += burnAmount;
    }

    /// @notice Fuzz test transfer functionality
    function testFuzz_Transfer(address from, address to, uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(from != address(token));
        vm.assume(to != address(token));
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount <= mintAmount);

        vm.prank(minter);
        token.mint(from, mintAmount);

        uint256 fromBalanceBefore = token.balanceOf(from);
        uint256 toBalanceBefore = token.balanceOf(to);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(from);
        token.transfer(to, transferAmount);

        assertEq(token.balanceOf(from), fromBalanceBefore - transferAmount);
        assertEq(token.balanceOf(to), toBalanceBefore + transferAmount);
        assertEq(token.totalSupply(), totalSupplyBefore);
    }

    /// @notice Fuzz test approve and transferFrom
    function testFuzz_ApproveAndTransferFrom(
        address owner_,
        address spender,
        address to,
        uint256 mintAmount,
        uint256 approveAmount,
        uint256 transferAmount
    )
        public
    {
        vm.assume(owner_ != address(0));
        vm.assume(spender != address(0));
        vm.assume(to != address(0));
        vm.assume(owner_ != spender);
        vm.assume(owner_ != to);
        vm.assume(spender != to);
        vm.assume(owner_ != address(token));
        vm.assume(mintAmount > 0);
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        approveAmount = bound(approveAmount, 0, mintAmount);
        transferAmount = bound(transferAmount, 0, approveAmount);
        vm.assume(transferAmount > 0);

        vm.prank(minter);
        token.mint(owner_, mintAmount);

        vm.prank(owner_);
        token.approve(spender, approveAmount);

        uint256 ownerBalanceBefore = token.balanceOf(owner_);
        uint256 toBalanceBefore = token.balanceOf(to);
        uint256 allowanceBefore = token.allowance(owner_, spender);

        vm.prank(spender);
        token.transferFrom(owner_, to, transferAmount);

        assertEq(token.balanceOf(owner_), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(to), toBalanceBefore + transferAmount);
        assertEq(token.allowance(owner_, spender), allowanceBefore - transferAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MaxValues(uint256 amount) public {
        vm.assume(amount > 0);
        amount = bound(amount, 1, type(uint256).max / 2);
        vm.prank(minter);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_PauseFunctionality(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);
        vm.prank(admin);
        token.pause(true);
        vm.prank(minter);
        vm.expectRevert(kToken.Paused.selector);
        token.mint(alice, amount);
        vm.prank(admin);
        token.pause(false);
        vm.prank(minter);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzz_DecimalPrecision(uint8 decimals_) public {
        decimals_ = uint8(bound(decimals_, 1, 18));
        address localOwner = makeAddr("localOwner");
        address localAdmin = makeAddr("localAdmin");
        address localMinter = makeAddr("localMinter");
        kToken implementation = new kToken();
        bytes memory data = abi.encodeWithSelector(
            kToken.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, decimals_, localOwner, localAdmin, localMinter
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        kToken customToken = kToken(address(proxy));
        assertEq(customToken.decimals(), decimals_);
        uint256 amount = 10 ** decimals_;
        vm.prank(localMinter);
        customToken.mint(alice, amount);
        assertEq(customToken.balanceOf(alice), amount);
    }

    function testFuzz_UnauthorizedMint(address unauthorized, uint256 amount) public {
        vm.assume(unauthorized != minter);
        vm.assume(unauthorized != admin);
        vm.assume(unauthorized != owner);
        vm.assume(amount > 0);
        vm.prank(unauthorized);
        vm.expectRevert();
        token.mint(alice, amount);
    }

    function testFuzz_BurnMoreThanBalance(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(burnAmount > mintAmount);
        vm.prank(minter);
        token.mint(alice, mintAmount);
        vm.prank(minter);
        vm.expectRevert();
        token.burn(alice, burnAmount);
    }

    function testFuzz_TransferMoreThanBalance(uint256 balance, uint256 transferAmount) public {
        vm.assume(balance > 0);
        vm.assume(balance <= type(uint128).max);
        vm.assume(transferAmount > balance);
        vm.prank(minter);
        token.mint(alice, balance);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, transferAmount);
    }

    function _mintToRandomAddress(uint256 amount, address to) internal {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);
        vm.prank(minter);
        token.mint(to, amount);
        totalMinted += amount;
    }

    function _burnFromRandomAddress(uint256 amount, address from) internal {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= token.balanceOf(from));
        vm.prank(minter);
        token.burn(from, amount);
        totalBurned += amount;
    }

    function testProperty_TotalSupplyEqualsBalances(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 charlieAmount
    )
        public
    {
        aliceAmount = bound(aliceAmount, 0, type(uint128).max / 3);
        bobAmount = bound(bobAmount, 0, type(uint128).max / 3);
        charlieAmount = bound(charlieAmount, 0, type(uint128).max / 3);
        if (aliceAmount > 0) {
            vm.prank(minter);
            token.mint(alice, aliceAmount);
        }
        if (bobAmount > 0) {
            vm.prank(minter);
            token.mint(bob, bobAmount);
        }
        if (charlieAmount > 0) {
            vm.prank(minter);
            token.mint(charlie, charlieAmount);
        }
        uint256 totalBalances = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(charlie);
        assertEq(token.totalSupply(), totalBalances);
    }

    function testProperty_TransfersPreserveTotalSupply(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount <= mintAmount);
        vm.prank(minter);
        token.mint(alice, mintAmount);
        uint256 totalSupplyBefore = token.totalSupply();
        vm.prank(alice);
        token.transfer(bob, transferAmount);
        assertEq(token.totalSupply(), totalSupplyBefore);
    }

    function testProperty_TransferSymmetry(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount <= mintAmount);
        vm.prank(minter);
        token.mint(alice, mintAmount);
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(alice);
        token.transfer(bob, transferAmount);
        assertEq(token.balanceOf(alice), aliceBalanceBefore - transferAmount);
        assertEq(token.balanceOf(bob), bobBalanceBefore + transferAmount);
        assertEq(aliceBalanceBefore - token.balanceOf(alice), token.balanceOf(bob) - bobBalanceBefore);
    }

    function testFuzz_MultipleOperations(uint256 amount1, uint256 amount2, uint256 transferAmount) public {
        amount1 = bound(amount1, 1, type(uint128).max / 4);
        amount2 = bound(amount2, 1, type(uint128).max / 4);
        transferAmount = bound(transferAmount, 1, amount1);
        vm.startPrank(minter);
        token.mint(alice, amount1);
        token.mint(bob, amount2);
        vm.stopPrank();
        vm.prank(alice);
        token.transfer(charlie, transferAmount);
        uint256 burnAmount = amount2 / 2;
        vm.prank(minter);
        token.burn(bob, burnAmount);
        assertEq(token.balanceOf(alice), amount1 - transferAmount);
        assertEq(token.balanceOf(bob), amount2 - burnAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.totalSupply(), amount1 + amount2 - burnAmount);
    }

    function testFuzz_Permit(uint256 ownerPrivateKey, address spender, uint256 value, uint256 deadline) public {
        ownerPrivateKey = bound(ownerPrivateKey, 1, type(uint128).max);
        vm.assume(spender != address(0));
        deadline = bound(deadline, block.timestamp, type(uint256).max);
        address owner_ = vm.addr(ownerPrivateKey);
        // First mint some tokens to the owner
        vm.prank(minter);
        token.mint(owner_, value);
        // Create permit signature
        bytes32 permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        owner_,
                        spender,
                        value,
                        token.nonces(owner_),
                        deadline
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, permitHash);
        // Execute permit
        token.permit(owner_, spender, value, deadline, v, r, s);
        assertEq(token.allowance(owner_, spender), value);
    }

    function testFuzz_BurnFrom(address from, uint256 mintAmount, uint256 approveAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(from != minter);
        vm.assume(mintAmount > 0);
        mintAmount = bound(mintAmount, 1, type(uint128).max);
        approveAmount = bound(approveAmount, 0, mintAmount);
        if (approveAmount < 1) return; // skip if approveAmount is 0
        burnAmount = bound(burnAmount, 1, approveAmount);
        // Mint tokens
        vm.prank(minter);
        token.mint(from, mintAmount);
        // Approve minter to burn
        vm.prank(from);
        token.approve(minter, approveAmount);
        uint256 balanceBefore = token.balanceOf(from);
        uint256 allowanceBefore = token.allowance(from, minter);
        // Burn tokens using burnFrom
        vm.prank(minter);
        token.burnFrom(from, burnAmount);
        assertEq(token.balanceOf(from), balanceBefore - burnAmount);
        assertEq(token.allowance(from, minter), allowanceBefore - burnAmount);
    }

    function testFuzz_ComplexSequence(
        uint256 mintAmount1,
        uint256 mintAmount2,
        uint256 transferAmount,
        uint256 burnAmount,
        bool shouldPause
    )
        public
    {
        // Bound inputs
        mintAmount1 = bound(mintAmount1, 1, type(uint64).max);
        mintAmount2 = bound(mintAmount2, 1, type(uint64).max);
        uint256 maxTransfer = mintAmount1 / 2;
        uint256 maxBurn = mintAmount2 / 2;
        if (maxTransfer < 1 || maxBurn < 1) return; // skip if bounds are invalid
        transferAmount = bound(transferAmount, 1, maxTransfer);
        burnAmount = bound(burnAmount, 1, maxBurn);
        uint256 expectedTotalSupply = mintAmount1 + mintAmount2 - burnAmount;
        // Execute sequence
        vm.startPrank(minter);
        token.mint(alice, mintAmount1);
        token.mint(bob, mintAmount2);
        vm.stopPrank();
        if (shouldPause) {
            vm.prank(admin);
            token.pause(true);
            // Operations should fail when paused
            vm.prank(minter);
            vm.expectRevert(kToken.Paused.selector);
            token.mint(charlie, 100);
            vm.prank(admin);
            token.pause(false);
        }
        vm.prank(alice);
        token.transfer(charlie, transferAmount);
        vm.prank(minter);
        token.burn(bob, burnAmount);
        // Verify final state
        assertEq(token.totalSupply(), expectedTotalSupply);
        assertEq(token.balanceOf(alice), mintAmount1 - transferAmount);
        assertEq(token.balanceOf(bob), mintAmount2 - burnAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
    }
}
