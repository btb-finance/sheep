// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SheepPool} from "../src/btb/btbstaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockSheepToken, MockSheepDog, MockWGasToken} from "../script/DeployEcosystem.s.sol";

contract SheepPoolIntegrationTest is Test {
    SheepPool public sheepPool;
    MockSheepToken public sheepToken;
    MockSheepDog public sheepDog;
    MockWGasToken public wGasToken;
    
    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 public constant INITIAL_BALANCE = 10000 * 1e18;
    uint256 public constant MIN_DEPOSIT = 10 * 1e18;
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy the tokens and contracts
        wGasToken = new MockWGasToken();
        sheepToken = new MockSheepToken(address(wGasToken));
        sheepDog = new MockSheepDog(address(sheepToken));
        sheepPool = new SheepPool(address(sheepToken), address(sheepDog), address(wGasToken));
        
        // Give tokens to users
        sheepToken.transfer(user1, INITIAL_BALANCE);
        sheepToken.transfer(user2, INITIAL_BALANCE);
        wGasToken.transfer(user1, INITIAL_BALANCE);
        wGasToken.transfer(user2, INITIAL_BALANCE);
        
        // Fund the SheepPool with some initial SHEEP
        uint256 initialPoolAmount = 1000 * 1e18;
        sheepToken.transfer(address(sheepPool), initialPoolAmount);
        
        vm.stopPrank();
    }
    
    function testInitializeRotation() public {
        // Initialize the rotation
        vm.startPrank(deployer);
        uint256 initialAmount = 100 * 1e18;
        
        // First need to approve tokens for the pool
        sheepToken.approve(address(sheepPool), initialAmount);
        
        // Now initialize
        sheepPool.initializeRotation(initialAmount);
        
        // Verify setup
        (bool dogAActive, , uint256 dogAAmount) = sheepPool.dogA();
        (bool dogBActive, uint256 dogBSleepTime, ) = sheepPool.dogB();
        
        assertTrue(dogAActive, "Dog A should be active");
        assertFalse(dogBActive, "Dog B should not be active");
        assertEq(dogAAmount, initialAmount, "Dog A should have the initial amount");
        assertTrue(dogBSleepTime > 0, "Dog B sleep time should be set");
        assertEq(sheepPool.totalSheepDeposited(), initialAmount, "Total sheep deposited should match initial amount");
        
        vm.stopPrank();
    }
    
    function testUserDeposit() public {
        // First initialize the rotation
        vm.startPrank(deployer);
        uint256 initialAmount = 100 * 1e18;
        sheepToken.approve(address(sheepPool), initialAmount);
        sheepPool.initializeRotation(initialAmount);
        vm.stopPrank();
        
        // Now have user1 deposit
        vm.startPrank(user1);
        uint256 depositAmount = 50 * 1e18;
        
        // Approve tokens for the pool
        sheepToken.approve(address(sheepPool), depositAmount);
        
        // Check balance before
        uint256 balanceBefore = sheepToken.balanceOf(user1);
        
        // Deposit
        sheepPool.deposit(depositAmount);
        
        // Check balance after
        uint256 balanceAfter = sheepToken.balanceOf(user1);
        assertEq(balanceBefore - balanceAfter, depositAmount, "User's SHEEP balance should decrease by deposit amount");
        
        // Check user got pool shares
        assertTrue(sheepPool.balanceOf(user1) > 0, "User should have pool shares");
        
        // Check deposit was recorded
        assertEq(sheepPool.userDeposits(user1), depositAmount - (depositAmount * sheepPool.DEPOSIT_FEE_BPS() / 10000), "User deposit should be recorded after fee");
        
        vm.stopPrank();
    }
    
    function testRequestWithdrawal() public {
        // Setup: initialize and deposit
        vm.startPrank(deployer);
        uint256 initialAmount = 100 * 1e18;
        sheepToken.approve(address(sheepPool), initialAmount);
        sheepPool.initializeRotation(initialAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        uint256 depositAmount = 50 * 1e18;
        sheepToken.approve(address(sheepPool), depositAmount);
        sheepPool.deposit(depositAmount);
        
        // Request withdrawal
        uint256 shareAmount = sheepPool.balanceOf(user1) / 2; // Request half of shares
        sheepPool.requestWithdrawal(shareAmount);
        
        // Check locked shares
        assertEq(sheepPool.lockedShares(user1), shareAmount, "Shares should be locked");
        
        vm.stopPrank();
    }
    
    function testRotatePositions() public {
        // Setup: initialize and deposit
        vm.startPrank(deployer);
        uint256 initialAmount = 100 * 1e18;
        sheepToken.approve(address(sheepPool), initialAmount);
        sheepPool.initializeRotation(initialAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        uint256 depositAmount = 50 * 1e18;
        sheepToken.approve(address(sheepPool), depositAmount);
        sheepPool.deposit(depositAmount);
        
        // Request withdrawal
        uint256 shareAmount = sheepPool.balanceOf(user1) / 2; // Request half of shares
        sheepPool.requestWithdrawal(shareAmount);
        vm.stopPrank();
        
        // Advance time to make rotation possible
        vm.warp(block.timestamp + 3 days);
        
        // Ensure we have enough gas tokens for rent
        vm.startPrank(deployer);
        wGasToken.transfer(address(sheepPool), 100 * 1e18);
        
        // Rotate positions
        sheepPool.rotatePositions();
        
        // Verify rotation
        (bool dogAActive, , ) = sheepPool.dogA();
        (bool dogBActive, , ) = sheepPool.dogB();
        
        // The roles should have switched
        assertFalse(dogAActive, "Dog A should now be inactive");
        assertTrue(dogBActive, "Dog B should now be active");
        
        // Check if withdrawal was processed
        assertEq(sheepPool.lockedShares(user1), 0, "Locked shares should be cleared");
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        // Setup: initialize and deposit
        vm.startPrank(deployer);
        uint256 initialAmount = 100 * 1e18;
        sheepToken.approve(address(sheepPool), initialAmount);
        sheepPool.initializeRotation(initialAmount);
        vm.stopPrank();
        
        vm.startPrank(user1);
        uint256 depositAmount = 50 * 1e18;
        sheepToken.approve(address(sheepPool), depositAmount);
        sheepPool.deposit(depositAmount);
        
        // Enable emergency mode
        vm.stopPrank();
        vm.startPrank(deployer);
        sheepPool.setEmergencyMode(true);
        vm.stopPrank();
        
        // Emergency withdraw
        vm.startPrank(user1);
        uint256 shareAmount = sheepPool.balanceOf(user1);
        uint256 balanceBefore = sheepToken.balanceOf(user1);
        
        sheepPool.emergencyWithdraw(shareAmount);
        
        uint256 balanceAfter = sheepToken.balanceOf(user1);
        assertTrue(balanceAfter > balanceBefore, "User should have received SHEEP tokens");
        assertEq(sheepPool.balanceOf(user1), 0, "User should have no more shares");
        
        vm.stopPrank();
    }
} 