// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";
import "./DeployFullEcosystem.s.sol";

/// @notice This script demonstrates user interactions with the Sheep ecosystem
contract UserInteractionsScript is Script {
    MockSheepToken public sheepToken;
    MockWolf public wolf;
    MockSheepDog public sheepDog;
    SheepPool public sheepPool;
    MockWGasToken public wGasToken;
    
    // User addresses
    address public deployer;
    address public user1;
    address public user2;
    
    function setUp() public {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        // Create test users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Get deployed contract addresses
        address sheepTokenAddr = vm.envAddress("SHEEP_TOKEN_ADDRESS");
        address wolfAddr = vm.envAddress("WOLF_CONTRACT_ADDRESS");
        address sheepDogAddr = vm.envAddress("SHEEPDOG_CONTRACT_ADDRESS");
        address sheepPoolAddr = vm.envAddress("SHEEPPOOL_ADDRESS");
        address wGasTokenAddr = vm.envAddress("WGAS_TOKEN_ADDRESS");
        
        // Connect to deployed contracts
        sheepToken = MockSheepToken(sheepTokenAddr);
        wolf = MockWolf(wolfAddr);
        sheepDog = MockSheepDog(sheepDogAddr);
        sheepPool = SheepPool(sheepPoolAddr);
        wGasToken = MockWGasToken(wGasTokenAddr);
    }

    function run() public {
        console2.log("===== USER INTERACTIONS DEMO =====");
        console2.log("Deployer: ", deployer);
        console2.log("User1: ", user1);
        console2.log("User2: ", user2);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start with deployer transferring tokens to users
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("\n1. FUNDING USERS WITH TOKENS");
        uint256 userAmount = 10000 * 10**18;
        sheepToken.transfer(user1, userAmount);
        sheepToken.transfer(user2, userAmount);
        wGasToken.transfer(user1, userAmount);
        wGasToken.transfer(user2, userAmount);
        
        console2.log("User1 funded with:");
        console2.log("- SHEEP: ", sheepToken.balanceOf(user1) / 1e18);
        console2.log("- WGAS: ", wGasToken.balanceOf(user1) / 1e18);
        
        console2.log("User2 funded with:");
        console2.log("- SHEEP: ", sheepToken.balanceOf(user2) / 1e18);
        console2.log("- WGAS: ", wGasToken.balanceOf(user2) / 1e18);
        
        vm.stopBroadcast();
        
        // User1 deposits into SheepPool
        console2.log("\n2. USER1 DEPOSITS INTO SHEEPPOOL");
        vm.startPrank(user1);
        
        uint256 depositAmount = 5000 * 10**18;
        sheepToken.approve(address(sheepPool), depositAmount);
        sheepPool.deposit(depositAmount);
        
        console2.log("User1 deposited ", depositAmount / 1e18, " SHEEP into SheepPool");
        console2.log("User1 share balance: ", sheepPool.balanceOf(user1) / 1e18);
        console2.log("User1 remaining SHEEP: ", sheepToken.balanceOf(user1) / 1e18);
        
        vm.stopPrank();
        
        // User2 protects with SheepDog
        console2.log("\n3. USER2 PROTECTS WITH SHEEPDOG");
        vm.startPrank(user2);
        
        uint256 protectAmount = 3000 * 10**18;
        sheepToken.approve(address(sheepDog), protectAmount);
        sheepDog.protect(protectAmount);
        
        console2.log("User2 protected ", protectAmount / 1e18, " SHEEP with SheepDog");
        console2.log("User2 SheepDog shares: ", sheepDog.sheepDogShares(user2) / 1e18);
        console2.log("User2 remaining SHEEP: ", sheepToken.balanceOf(user2) / 1e18);
        
        vm.stopPrank();
        
        // Wolf attack demonstration
        console2.log("\n4. WOLF ATTACK DEMONSTRATION");
        
        // User1 tries to attack User2 (protected)
        vm.startPrank(user1);
        
        uint256 attackAmount = 1000 * 10**18;
        try wolf.eat(user2, attackAmount) {
            console2.log("Wolf attack succeeded! This shouldn't happen!");
        } catch Error(string memory reason) {
            console2.log("Wolf attack failed (as expected): ", reason);
        }
        
        vm.stopPrank();
        
        // Fast forward time to test BTB rotation
        console2.log("\n5. ADVANCE TIME FOR ROTATION");
        // Fast forward 3 days
        uint256 advanceTime = 3 days;
        vm.warp(block.timestamp + advanceTime);
        
        console2.log("Time advanced by ", advanceTime / 1 days, " days");
        
        // Check if rotation is ready
        (bool isReady, uint256 nextRotationTime) = sheepPool.isRotationReady();
        console2.log("Rotation ready: ", isReady ? "YES" : "NO");
        
        if (isReady) {
            vm.startBroadcast(deployerPrivateKey);
            console2.log("\n6. PERFORMING ROTATION");
            
            try sheepPool.rotatePositions() {
                console2.log("Rotation successful!");
                
                // Show updated positions
                (bool dogAActive, , uint256 dogAAmount) = sheepPool.dogA();
                (bool dogBActive, , uint256 dogBAmount) = sheepPool.dogB();
                
                console2.log("Dog A - Active: ", dogAActive ? "YES" : "NO", ", Amount: ", dogAAmount / 1e18);
                console2.log("Dog B - Active: ", dogBActive ? "YES" : "NO", ", Amount: ", dogBAmount / 1e18);
            } catch Error(string memory reason) {
                console2.log("Rotation failed: ", reason);
            }
            
            vm.stopBroadcast();
        }
        
        // User2 withdraws from SheepDog
        console2.log("\n7. USER2 WITHDRAWS FROM SHEEPDOG");
        vm.startPrank(user2);
        
        // Start sleep process
        sheepDog.dogSleep();
        console2.log("User2 initiated sleep process with SheepDog");
        console2.log("User2 can claim at: ", sheepDog.wenToClaim(user2));
        
        // Fast forward time to enable withdrawal
        vm.warp(sheepDog.wenToClaim(user2) + 1);
        console2.log("Time advanced to enable withdrawal");
        
        // Withdraw sheep
        console2.log("User2 SHEEP before withdrawal: ", sheepToken.balanceOf(user2) / 1e18);
        sheepDog.getSheep();
        console2.log("User2 SHEEP after withdrawal: ", sheepToken.balanceOf(user2) / 1e18);
        
        vm.stopPrank();
        
        // User1 requests withdrawal from SheepPool
        console2.log("\n8. USER1 REQUESTS WITHDRAWAL FROM SHEEPPOOL");
        vm.startPrank(user1);
        
        uint256 withdrawalShares = sheepPool.balanceOf(user1) / 2; // Withdraw half
        sheepPool.requestWithdrawal(withdrawalShares);
        
        console2.log("User1 requested withdrawal of ", withdrawalShares / 1e18, " shares");
        console2.log("User1 pending withdrawal shares: ", sheepPool.lockedShares(user1) / 1e18);
        console2.log("User1 remaining active shares: ", (sheepPool.balanceOf(user1) - sheepPool.lockedShares(user1)) / 1e18);
        
        vm.stopPrank();
        
        // Check final pool state
        console2.log("\n9. FINAL POOL STATE");
        console2.log("SheepPool total value: ", sheepPool.totalPoolValue() / 1e18, " SHEEP");
        console2.log("Total shares: ", sheepPool.totalSupply() / 1e18);
        
        // Calculate total locked shares manually by summing across all users
        uint256 totalLocked = sheepPool.lockedShares(user1) + sheepPool.lockedShares(user2);
        console2.log("Total locked shares: ", totalLocked / 1e18);
    }
} 