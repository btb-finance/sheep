// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SheepDogManager} from "../src/btb/sheepdogmanger.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InteractBTBScript is Script {
    // Contract addresses from our new deployment
    address public constant SHEEP_TOKEN_ADDRESS = 0xCbab18E72005ba5Bc5ea861514b187561Bb805FB;
    address payable public constant SHEEPDOG_MANAGER_ADDRESS = payable(0xCB988E5DA3a3e0B981A128fbdcb2FDA14eBa5Fc6);
    
    // Amount to deposit - adjusted to account for 0.5% fee
    // After analyzing the trace, it seems the fee calculation is different than expected
    uint256 public constant DEPOSIT_AMOUNT = 100.5e18; // 100.5 SHEEP tokens

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== INTERACTING WITH BTB CONTRACTS ===");
        console.log("User address:", deployer);
        console.log("SHEEP token address:", SHEEP_TOKEN_ADDRESS);
        console.log("SheepDogManager address:", SHEEPDOG_MANAGER_ADDRESS);
        console.log("Deposit amount:", DEPOSIT_AMOUNT / 1e18, "SHEEP");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create contract instances
        IERC20 sheepToken = IERC20(SHEEP_TOKEN_ADDRESS);
        SheepDogManager sheepDogManager = SheepDogManager(SHEEPDOG_MANAGER_ADDRESS);
        
        // First, check current SHEEP balance
        uint256 initialBalance = sheepToken.balanceOf(deployer);
        console.log("Initial SHEEP balance:", initialBalance / 1e18);
        
        // Check if we have enough tokens
        if (initialBalance < DEPOSIT_AMOUNT) {
            console.log("Not enough SHEEP tokens. We need to mint some first.");
            // For this script, we'll just stop here if we don't have enough tokens
            vm.stopBroadcast();
            return;
        }
        
        // Check current allowance
        uint256 allowance = sheepToken.allowance(deployer, SHEEPDOG_MANAGER_ADDRESS);
        console.log("Current allowance:", allowance / 1e18);
        
        // Approve SHEEP for SheepDogManager if needed
        if (allowance < DEPOSIT_AMOUNT) {
            console.log("Approving SheepDogManager to spend SHEEP...");
            sheepToken.approve(SHEEPDOG_MANAGER_ADDRESS, DEPOSIT_AMOUNT);
        }
        
        // Get current staked amount
        uint256 initialTVL = sheepDogManager.getTotalSheepValue();
        console.log("Current TVL in SheepDogManager:", initialTVL / 1e18, "SHEEP");
        
        // Deposit SHEEP into SheepDogManager
        console.log("Depositing SHEEP into SheepDogManager...");
        sheepDogManager.deposit(DEPOSIT_AMOUNT);
        
        // Check new balance and TVL after deposit
        uint256 newBalance = sheepToken.balanceOf(deployer);
        uint256 newTVL = sheepDogManager.getTotalSheepValue();
        
        console.log("New SHEEP balance:", newBalance / 1e18);
        console.log("New TVL in SheepDogManager:", newTVL / 1e18, "SHEEP");
        console.log("TVL change:", (newTVL - initialTVL) / 1e18, "SHEEP");
        
        // Check user's staked amount
        uint256 userStaked = sheepDogManager.userDeposits(deployer);
        console.log("User's staked SHEEP:", userStaked / 1e18);
        
        vm.stopBroadcast();
        
        console.log("\n=== OPERATION COMPLETED ===");
    }
} 