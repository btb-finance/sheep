// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";
import {MockSheepToken, MockSheepDog, MockWGasToken} from "./DeployEcosystem.s.sol";

contract InteractWithPoolScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get the addresses of the deployed contracts from environment variables or a config file
        address sheepToken = vm.envAddress("SHEEP_TOKEN_ADDRESS");
        address sheepDog = vm.envAddress("SHEEPDOG_CONTRACT_ADDRESS");
        address wGasToken = vm.envAddress("WGAS_TOKEN_ADDRESS");
        address sheepPool = vm.envAddress("SHEEPPOOL_ADDRESS");
        
        console2.log("Interacting with contracts as:", deployer);
        console2.log("SheepToken:", sheepToken);
        console2.log("SheepDog:", sheepDog);
        console2.log("WGasToken:", wGasToken);
        console2.log("SheepPool:", sheepPool);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Interact with the contracts
        
        // 1. Initialize the rotation if not already initialized
        SheepPool pool = SheepPool(sheepPool);
        
        // Check if already initialized by checking Dog B sleep time
        (,uint256 dogBSleepTime,) = pool.dogB();
        
        if (dogBSleepTime == 0) {
            console2.log("Initializing rotation...");
            
            // Approve SHEEP tokens
            uint256 initialAmount = 100 * 1e18;
            MockSheepToken(sheepToken).approve(sheepPool, initialAmount);
            
            // Initialize rotation
            pool.initializeRotation(initialAmount);
            console2.log("Rotation initialized with", initialAmount / 1e18, "SHEEP");
        } else {
            console2.log("Rotation already initialized, dog B sleep time:", dogBSleepTime);
        }
        
        // 2. Check pool metrics
        uint256 totalPoolValue = pool.totalPoolValue();
        console2.log("Total pool value:", totalPoolValue / 1e18, "SHEEP");
        
        // 3. Deposit some SHEEP
        uint256 depositAmount = 50 * 1e18;
        
        // Check user's SHEEP balance first
        uint256 sheepBalance = MockSheepToken(sheepToken).balanceOf(deployer);
        console2.log("User SHEEP balance:", sheepBalance / 1e18);
        
        if (sheepBalance >= depositAmount) {
            console2.log("Depositing", depositAmount / 1e18, "SHEEP...");
            
            // Approve SHEEP tokens
            MockSheepToken(sheepToken).approve(sheepPool, depositAmount);
            
            // Deposit
            pool.deposit(depositAmount);
            console2.log("Deposit successful, new pool shares:", pool.balanceOf(deployer) / 1e18);
        } else {
            console2.log("Not enough SHEEP to deposit");
        }
        
        // 4. Check if rotation is ready
        (bool isReady, uint256 nextRotationTime) = pool.isRotationReady();
        if (isReady) {
            console2.log("Rotation is ready, rotating positions...");
            
            // Make sure we have enough gas tokens for rent
            uint256 wGasBalance = MockWGasToken(wGasToken).balanceOf(deployer);
            console2.log("User WGAS balance:", wGasBalance / 1e18);
            
            if (wGasBalance > 0) {
                // Deposit some gas tokens for rent
                MockWGasToken(wGasToken).transfer(sheepPool, 20 * 1e18);
                
                // Rotate positions
                pool.rotatePositions();
                console2.log("Positions rotated successfully");
            } else {
                console2.log("Not enough WGAS for rotation");
            }
        } else {
            console2.log("Rotation not ready yet, next rotation at timestamp:", nextRotationTime);
            console2.log("Current timestamp:", block.timestamp);
            console2.log("Time until rotation:", nextRotationTime - block.timestamp, "seconds");
        }
        
        vm.stopBroadcast();
    }
} 