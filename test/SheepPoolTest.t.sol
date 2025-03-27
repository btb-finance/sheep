// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/btb/btbstaking.sol";
import "../script/DeployFullEcosystem.s.sol";

contract SheepPoolTest is Test {
    // Contracts
    MockSheepToken public sheepToken;
    MockWolf public wolf;
    MockSheepDog public sheepDog;
    SheepPool public sheepPool;
    MockWGasToken public wGasToken;

    // Users
    address public deployer;
    address public user1;
    address public user2;
    address public user3;

    // Constants
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant INITIAL_USER_BALANCE = 10000 * 10**18;
    uint256 public constant INITIAL_POOL_FUNDING = 1000 * 10**18;
    uint256 public constant INITIAL_ROTATION_AMOUNT = 100 * 10**18;
    uint256 public constant TEST_DEPOSIT_AMOUNT = 1000 * 10**18;
    uint256 public constant ROTATION_PERIOD = 2 days;

    function setUp() public {
        // Set up accounts
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy contracts
        wGasToken = new MockWGasToken();
        sheepToken = new MockSheepToken(address(wGasToken));
        wolf = new MockWolf(address(sheepToken));
        sheepDog = new MockSheepDog(address(sheepToken));
        sheepPool = new SheepPool(
            address(sheepToken),
            address(sheepDog),
            address(wGasToken)
        );

        // Setup connections
        wolf.setProtector(address(sheepDog));
        sheepToken.setWolf(address(wolf));

        // Fund accounts
        sheepToken.transfer(user1, INITIAL_USER_BALANCE);
        sheepToken.transfer(user2, INITIAL_USER_BALANCE);
        sheepToken.transfer(user3, INITIAL_USER_BALANCE);
        wGasToken.transfer(user1, INITIAL_USER_BALANCE);
        wGasToken.transfer(user2, INITIAL_USER_BALANCE);
        wGasToken.transfer(user3, INITIAL_USER_BALANCE);
        wGasToken.transfer(address(sheepPool), INITIAL_USER_BALANCE);

        // Fund the SheepPool with initial SHEEP
        sheepToken.transfer(address(sheepPool), INITIAL_POOL_FUNDING);

        // Initialize the rotation
        sheepToken.approve(address(sheepPool), INITIAL_ROTATION_AMOUNT);
        sheepPool.initializeRotation(INITIAL_ROTATION_AMOUNT);
    }

    function testInitialSetup() public view {
        // Verify initial connections
        assertEq(sheepToken.wolf(), address(wolf), "Wolf connection incorrect");
        assertEq(wolf.protector(), address(sheepDog), "SheepDog protector connection incorrect");
        assertEq(sheepDog.sheep(), address(sheepToken), "SheepDog sheep connection incorrect");
        
        // Verify SheepPool connections
        assertEq(sheepPool.sheepToken(), address(sheepToken), "SheepPool sheepToken incorrect");
        assertEq(sheepPool.sheepDogContract(), address(sheepDog), "SheepPool sheepDogContract incorrect");
        assertEq(sheepPool.wGasToken(), address(wGasToken), "SheepPool wGasToken incorrect");
        
        // Verify initial state
        (bool dogAActive, , uint256 dogAAmount) = sheepPool.dogA();
        (bool dogBActive, uint256 dogBSleepStartTime, ) = sheepPool.dogB();
        
        assertTrue(dogAActive, "Dog A should be active initially");
        assertFalse(dogBActive, "Dog B should not be active initially");
        assertEq(dogAAmount, INITIAL_ROTATION_AMOUNT, "Dog A amount incorrect");
        assertTrue(dogBSleepStartTime > 0, "Dog B sleep start time should be set");
    }

    function testDeposit() public {
        // User1 deposits SHEEP
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Verify balance
        uint256 depositFee = TEST_DEPOSIT_AMOUNT * 50 / 10000; // 0.5% fee
        uint256 expectedShares = TEST_DEPOSIT_AMOUNT - depositFee; // Initial 1:1 ratio
        
        assertEq(sheepPool.balanceOf(user1), expectedShares, "User shares incorrect");
        
        // Verify Dog A amount increased
        (,, uint256 dogAAmount) = sheepPool.dogA();
        assertEq(dogAAmount, INITIAL_ROTATION_AMOUNT + (TEST_DEPOSIT_AMOUNT - depositFee), "Dog A amount incorrect after deposit");
    }

    function testWithdrawalRequestAndLocking() public {
        // User1 deposits SHEEP
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        
        // Get user shares
        uint256 userShares = sheepPool.balanceOf(user1);
        uint256 withdrawShares = userShares / 2; // Request half of shares
        
        // Request withdrawal
        sheepPool.requestWithdrawal(withdrawShares);
        
        // Verify locked shares
        assertEq(sheepPool.lockedShares(user1), withdrawShares, "Locked shares incorrect");
        
        // Try to transfer more than available
        vm.expectRevert("Shares locked for withdrawal");
        sheepPool.transfer(user2, userShares);
        
        // Transfer within available limit should work
        sheepPool.transfer(user2, userShares - withdrawShares);
        
        // Verify balances after transfer
        uint256 remainingBalance = sheepPool.balanceOf(user1); 
        uint256 freeShares = remainingBalance - sheepPool.lockedShares(user1);
        assertEq(freeShares, 0, "User1 should have 0 unlocked shares left");
        assertEq(sheepPool.balanceOf(user2), userShares - withdrawShares, "User2 should have received shares");
        assertEq(sheepPool.lockedShares(user1), withdrawShares, "Locked shares should remain unchanged");
        
        vm.stopPrank();
    }

    function testRotationAndWithdrawalProcessing() public {
        // User1 deposits
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        
        // Request withdrawal of half shares
        uint256 userShares = sheepPool.balanceOf(user1);
        uint256 withdrawShares = userShares / 2;
        sheepPool.requestWithdrawal(withdrawShares);
        vm.stopPrank();
        
        // User2 deposits
        vm.startPrank(user2);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Advance time to rotation period
        vm.warp(block.timestamp + ROTATION_PERIOD);
        
        // Verify rotation is ready
        (bool isReady, ) = sheepPool.isRotationReady();
        assertTrue(isReady, "Rotation should be ready");
        
        // Record balances before rotation
        uint256 user1SheepBefore = sheepToken.balanceOf(user1);
        
        // Perform rotation
        sheepPool.rotatePositions();
        
        // Verify dogs swapped roles
        (bool dogAActive, , ) = sheepPool.dogA();
        (bool dogBActive, , ) = sheepPool.dogB();
        
        assertFalse(dogAActive, "Dog A should be inactive after rotation");
        assertTrue(dogBActive, "Dog B should be active after rotation");
        
        // Verify user1 got their withdrawal
        uint256 user1SheepAfter = sheepToken.balanceOf(user1);
        assertTrue(user1SheepAfter > user1SheepBefore, "User1 should have received SHEEP from withdrawal");
        
        // Verify locked shares were processed
        assertEq(sheepPool.lockedShares(user1), 0, "User1 locked shares should be 0 after rotation");
    }

    function testEarlyWithdrawal() public {
        // Add liquidity to the SheepPool for early withdrawals to work
        sheepToken.transfer(address(sheepPool), 10000 * 10**18);
        
        // User1 deposits
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        
        uint256 userShares = sheepPool.balanceOf(user1);
        uint256 earlyWithdrawShares = userShares / 2;
        
        // Get user SHEEP balance before
        uint256 sheepBefore = sheepToken.balanceOf(user1);
        
        // Perform early withdrawal
        sheepPool.requestEarlyWithdrawal(earlyWithdrawShares);
        
        // Get user SHEEP balance after
        uint256 sheepAfter = sheepToken.balanceOf(user1);
        uint256 actualWithdrawn = sheepAfter - sheepBefore;
        
        // Get share price
        uint256 totalShares = sheepPool.totalSupply();
        uint256 totalPoolValue = sheepPool.totalPoolValue();
        uint256 sharePrice = totalPoolValue * 1e18 / totalShares;
        
        // Calculate expected amount (minus 2% fee)
        uint256 expectedAmount = earlyWithdrawShares * sharePrice / 1e18;
        uint256 earlyWithdrawalFee = expectedAmount * 200 / 10000; // 2% fee
        uint256 expectedReceivedAmount = expectedAmount - earlyWithdrawalFee;
        
        assertApproxEqRel(actualWithdrawn, expectedReceivedAmount, 0.05e18, "Early withdrawal amount incorrect");
        
        // Verify shares were burned
        assertEq(sheepPool.balanceOf(user1), userShares - earlyWithdrawShares, "Remaining shares incorrect");
        
        vm.stopPrank();
    }

    function testEmergencyWithdraw() public {
        // Deposit by users
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Enable emergency mode
        sheepPool.setEmergencyMode(true);
        
        // Record SHEEP balance before
        uint256 user1SheepBefore = sheepToken.balanceOf(user1);
        
        // Emergency withdraw
        vm.startPrank(user1);
        uint256 userShares = sheepPool.balanceOf(user1);
        sheepPool.emergencyWithdraw(userShares);
        vm.stopPrank();
        
        // Verify received SHEEP
        uint256 user1SheepAfter = sheepToken.balanceOf(user1);
        assertTrue(user1SheepAfter > user1SheepBefore, "User should receive SHEEP in emergency withdrawal");
        
        // Verify shares were burned
        assertEq(sheepPool.balanceOf(user1), 0, "All shares should be burned after emergency withdrawal");
    }

    function testMultipleUsers() public {
        // User1, User2, User3 deposit
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT * 2);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        vm.startPrank(user3);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT / 2);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT / 2);
        vm.stopPrank();
        
        // User1 and User3 request withdrawals
        uint256 user1Shares = sheepPool.balanceOf(user1);
        uint256 user3Shares = sheepPool.balanceOf(user3);
        
        vm.prank(user1);
        sheepPool.requestWithdrawal(user1Shares / 2);
        
        vm.prank(user3);
        sheepPool.requestWithdrawal(user3Shares / 2);
        
        // Verify locked shares
        assertEq(sheepPool.lockedShares(user1), user1Shares / 2, "User1 shares should be half locked");
        assertEq(sheepPool.lockedShares(user3), user3Shares / 2, "User3 should have half shares locked");
        
        // Advance time and rotate
        vm.warp(block.timestamp + ROTATION_PERIOD);
        sheepPool.rotatePositions();
        
        // Verify user balances after rotation
        assertEq(sheepPool.lockedShares(user1), 0, "User1 locked shares should be cleared");
        assertEq(sheepPool.lockedShares(user3), 0, "User3 locked shares should be cleared");
    }

    // Test distribution of rewards among multiple users
    function testRewardsDistribution() public {
        // Initial deposits by all users
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT * 2); // User2 deposits twice as much
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        // Record initial balances
        uint256 user1InitialShares = sheepPool.balanceOf(user1);
        uint256 user2InitialShares = sheepPool.balanceOf(user2);
        uint256 initialTotalShares = sheepPool.totalSupply();
        uint256 initialPoolValue = sheepPool.totalPoolValue();
        
        // Add rewards to pool
        uint256 rewardAmount = 100 * 10**18;
        sheepToken.transfer(address(sheepPool), rewardAmount);
        
        // Pool value should increase by reward amount
        uint256 newPoolValue = sheepPool.totalPoolValue();
        assertTrue(newPoolValue > initialPoolValue, "Pool value should increase");
        assertEq(newPoolValue - initialPoolValue, rewardAmount, "Pool value increase should match rewards");
        
        // User2 requests withdrawal
        vm.startPrank(user2);
        uint256 user2TokensBefore = sheepToken.balanceOf(user2);
        sheepPool.requestWithdrawal(user2InitialShares / 2); // Withdraw half shares
        vm.stopPrank();
        
        // Process the rotation
        vm.warp(block.timestamp + ROTATION_PERIOD);
        // Fund gas tokens for rent
        wGasToken.transfer(address(sheepPool), 100 * 10**18);
        sheepPool.rotatePositions();
        
        // Check if user received tokens
        uint256 user2TokensAfter = sheepToken.balanceOf(user2);
        uint256 receivedAmount = user2TokensAfter - user2TokensBefore;
        
        // User should receive original deposit plus proportional rewards
        assertTrue(receivedAmount > 0, "User should receive tokens after withdrawal");
        
        // Verify user1 has more shares value now due to rewards
        uint256 user1ValueBefore = user1InitialShares * initialPoolValue / initialTotalShares;
        uint256 user1ValueAfter = user1InitialShares * newPoolValue / initialTotalShares;
        assertTrue(user1ValueAfter > user1ValueBefore, "User1 share value should increase with rewards");
    }
    
    // Test multiple rotation cycles with ongoing deposits and withdrawals
    function testCompleteCycle() public {
        // Setup
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Verify initial state
        (bool dogAActive1, , ) = sheepPool.dogA();
        (bool dogBActive1, , ) = sheepPool.dogB();
        assertTrue(dogAActive1, "Dog A should be active initially");
        assertFalse(dogBActive1, "Dog B should not be active initially");
        
        // Request withdrawal
        uint256 user1Shares = sheepPool.balanceOf(user1);
        vm.prank(user1);
        sheepPool.requestWithdrawal(user1Shares / 2);
        
        // First rotation
        vm.warp(block.timestamp + ROTATION_PERIOD);
        wGasToken.transfer(address(sheepPool), 100 * 10**18);
        sheepPool.rotatePositions();
        
        // Verify dog states switched
        (bool dogAActive2, , ) = sheepPool.dogA();
        (bool dogBActive2, , ) = sheepPool.dogB();
        assertFalse(dogAActive2, "Dog A should be inactive after rotation");
        assertTrue(dogBActive2, "Dog B should be active after rotation");
        
        // Another user deposits
        vm.startPrank(user2);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Second rotation
        vm.warp(block.timestamp + ROTATION_PERIOD);
        wGasToken.transfer(address(sheepPool), 100 * 10**18);
        sheepPool.rotatePositions();
        
        // Verify dog states switched back
        (bool dogAActive3, , ) = sheepPool.dogA();
        (bool dogBActive3, , ) = sheepPool.dogB();
        assertTrue(dogAActive3, "Dog A should be active again");
        assertFalse(dogBActive3, "Dog B should be inactive again");
        
        // Verify user balances
        uint256 remainingUser1Shares = sheepPool.balanceOf(user1);
        uint256 user2Shares = sheepPool.balanceOf(user2);
        
        assertTrue(remainingUser1Shares > 0, "User1 should still have shares");
        assertTrue(user2Shares > 0, "User2 should have shares");
        assertEq(remainingUser1Shares, user1Shares / 2, "User1 should have half shares remaining");
    }

    function testRotationReadiness() public {
        // Advance time but not enough for rotation
        vm.warp(block.timestamp + ROTATION_PERIOD - 1 hours);
        
        // Check if rotation is ready
        (bool isReady, uint256 nextRotationTime) = sheepPool.isRotationReady();
        assertFalse(isReady, "Rotation should not be ready yet");
        
        // Try to rotate anyway - should fail
        vm.expectRevert("Too early for rotation");
        sheepPool.rotatePositions();
        
        // Advance to exactly rotation time
        vm.warp(nextRotationTime);
        
        // Check again
        (isReady, ) = sheepPool.isRotationReady();
        assertTrue(isReady, "Rotation should be ready now");
        
        // Rotation should succeed
        sheepPool.rotatePositions();
    }

    function testCompleteWithdrawalCycle() public {
        // User deposits
        vm.startPrank(user1);
        sheepToken.approve(address(sheepPool), TEST_DEPOSIT_AMOUNT);
        sheepPool.deposit(TEST_DEPOSIT_AMOUNT);
        
        // Lock all shares
        sheepPool.requestWithdrawal(sheepPool.balanceOf(user1));
        vm.stopPrank();
        
        // Complete first rotation cycle
        vm.warp(block.timestamp + ROTATION_PERIOD);
        sheepPool.rotatePositions();
        
        // Verify user received their SHEEP
        // Get deposit amount minus fees
        
        uint256 userSheepBalance = sheepToken.balanceOf(user1);
        assertTrue(userSheepBalance > INITIAL_USER_BALANCE, "User should have received their SHEEP back");
        
        // Verify user has no shares left
        assertEq(sheepPool.balanceOf(user1), 0, "User should have no shares left");
    }
} 