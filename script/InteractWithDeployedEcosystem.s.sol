// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";
import "./DeployFullEcosystem.s.sol";

/// @notice This script demonstrates the full ecosystem interactions
/// including Sheep, Wolf, SheepDog, and SheepPool interactions
contract InteractWithEcosystemScript is Script {
    MockSheepToken public sheepToken;
    MockWolf public wolf;
    MockSheepDog public sheepDog;
    SheepPool public sheepPool;
    MockWGasToken public wGasToken;
    
    // User addresses for demonstration
    address public deployer;
    address public user1;
    address public user2;
    
    function setUp() public {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        // Define test users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Get deployed contract addresses from environment variables
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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console2.log("Interacting with ecosystem as", deployer);
        console2.log("-------------------------");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Setup: Give tokens to test users
        uint256 tokenAmount = 10000 * 10**18;
        sheepToken.transfer(user1, tokenAmount);
        sheepToken.transfer(user2, tokenAmount);
        wGasToken.transfer(user1, tokenAmount);
        wGasToken.transfer(user2, tokenAmount);
        
        console2.log("Transferred tokens to test users");
        console2.log("User1 SHEEP balance:", sheepToken.balanceOf(user1) / 10**18);
        console2.log("User2 SHEEP balance:", sheepToken.balanceOf(user2) / 10**18);
        
        console2.log("-------------------------");
        console2.log("DEMONSTRATION 1: Wolf eats unprotected sheep");
        
        // Impersonate user1 to simulate wolf attack
        vm.stopBroadcast();
        vm.startPrank(user1);
        
        // User1 attempts to use Wolf to eat User2's sheep
        uint256 attackAmount = 1000 * 10**18;
        try wolf.eat(user2, attackAmount) {
            console2.log("Wolf attack succeeded! User1 ate some of User2's SHEEP");
            console2.log("User2 SHEEP balance after attack:", sheepToken.balanceOf(user2) / 10**18);
            console2.log("User1 SHEEP balance after attack:", sheepToken.balanceOf(user1) / 10**18);
        } catch Error(string memory reason) {
            console2.log("Wolf attack failed:", reason);
        }
        
        vm.stopPrank();
        console2.log("-------------------------");
        console2.log("DEMONSTRATION 2: SheepDog protects User2's sheep");
        
        // Impersonate user2 to protect sheep
        vm.startPrank(user2);
        
        // User2 approves SheepDog to take their sheep
        uint256 protectAmount = 5000 * 10**18;
        sheepToken.approve(address(sheepDog), protectAmount);
        
        // User2 protects their sheep with SheepDog
        sheepDog.protect(protectAmount);
        console2.log("User2 protected", protectAmount / 10**18, "SHEEP with SheepDog");
        console2.log("User2 SheepDog shares:", sheepDog.sheepDogShares(user2) / 10**18);
        
        vm.stopPrank();
        
        // Try wolf attack again on protected user
        console2.log("User1 tries to attack User2 again...");
        vm.startPrank(user1);
        
        try wolf.eat(user2, attackAmount) {
            console2.log("Wolf attack succeeded! User1 ate some of User2's SHEEP");
        } catch Error(string memory reason) {
            console2.log("Wolf attack failed:", reason);
        }
        
        vm.stopPrank();
        
        console2.log("-------------------------");
        console2.log("DEMONSTRATION 3: SheepPool staking for higher returns");
        
        // Impersonate user1 to use SheepPool
        vm.startPrank(user1);
        
        // User1 approves SheepPool to take their sheep
        uint256 stakeAmount = 500 * 10**18;
        sheepToken.approve(address(sheepPool), stakeAmount);
        
        // User1 deposits sheep into SheepPool
        console2.log("User1 SHEEP balance before staking:", sheepToken.balanceOf(user1) / 10**18);
        sheepPool.deposit(stakeAmount);
        console2.log("User1 deposited", stakeAmount / 10**18, "SHEEP into SheepPool");
        console2.log("User1 SHEEP balance after staking:", sheepToken.balanceOf(user1) / 10**18);
        console2.log("User1 pool shares:", sheepPool.balanceOf(user1) / 10**18);
        
        vm.stopPrank();
        
        // Fast forward time to allow for rotation
        vm.warp(block.timestamp + 3 days);
        
        // Impersonate deployer to rotate positions
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Time passed, checking if rotation is ready...");
        (bool isReady, uint256 nextRotationTime) = sheepPool.isRotationReady();
        
        if (isReady) {
            console2.log("Rotation is ready, rotating positions...");
            sheepPool.rotatePositions();
            console2.log("Positions rotated successfully");
            
            // Show updated statuses
            (bool dogAActive, , uint256 dogAAmount) = sheepPool.dogA();
            (bool dogBActive, , uint256 dogBAmount) = sheepPool.dogB();
            
            console2.log("Dog A active:", dogAActive, "- amount:", dogAAmount / 10**18);
            console2.log("Dog B active:", dogBActive, "- amount:", dogBAmount / 10**18);
        } else {
            console2.log("Rotation not ready yet, next rotation at:", nextRotationTime);
        }
        
        console2.log("-------------------------");
        console2.log("DEMONSTRATION 4: SheepDog withdrawal");
        
        // Impersonate user2 to withdraw from SheepDog
        vm.stopBroadcast();
        vm.startPrank(user2);
        
        // User2 initiates the sleep process to get their sheep back
        console2.log("User2 starts sleep process for SheepDog...");
        sheepDog.dogSleep();
        uint256 claimTime = sheepDog.wenToClaim(user2);
        console2.log("User2 can claim sheep at timestamp:", claimTime);
        
        // Fast forward time to allow claiming
        vm.warp(claimTime + 1);
        
        // Get sheep back
        console2.log("User2 SHEEP balance before claiming:", sheepToken.balanceOf(user2) / 10**18);
        sheepDog.getSheep();
        console2.log("User2 claimed SHEEP from SheepDog");
        console2.log("User2 SHEEP balance after claiming:", sheepToken.balanceOf(user2) / 10**18);
        
        vm.stopPrank();
        
        // Final summary
        vm.startBroadcast(deployerPrivateKey);
        console2.log("-------------------------");
        console2.log("ECOSYSTEM DEMONSTRATION COMPLETE");
        console2.log("SheepPool total value:", sheepPool.totalPoolValue() / 10**18, "SHEEP");
        console2.log("User1 final pool shares:", sheepPool.balanceOf(user1) / 10**18);
        console2.log("User1 final SHEEP balance:", sheepToken.balanceOf(user1) / 10**18);
        console2.log("User2 final SHEEP balance:", sheepToken.balanceOf(user2) / 10**18);
        
        vm.stopBroadcast();
    }
} 