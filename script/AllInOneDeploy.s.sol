// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SHEEP} from "../src/sheep/sheeptoken.sol";
import {SHEEPDOG} from "../src/sheep/sheepdog.sol";
import {WOLF} from "../src/sheep/wolf.sol";
import {SheepDogManager} from "../src/btb/sheepdogmanger.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AllInOneDeploy
 * @dev This script handles the complete deployment process for the SHEEP ecosystem:
 * 1. Deploy SHEEP token, SHEEPDOG, and WOLF contracts
 * 2. Verify all contracts
 * 3. Mint SHEEP tokens
 * 4. Deposit directly to SHEEPDOG
 * 5. Deploy and verify SheepDogManager (BTB staking)
 * 6. Deposit to BTB vault (SheepDogManager)
 */
contract AllInOneDeploy is Script {
    // Deployed contract instances
    SHEEP public sheepToken;
    SHEEPDOG public sheepDog;
    WOLF public wolf;
    SheepDogManager public sheepDogManager;
    
    // Constants for Base Sepolia
    address constant WGAS_TOKEN = 0x4200000000000000000000000000000000000006; // WETH on Base Sepolia
    address constant POL_ADDRESS = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // POL address for Base Sepolia
    address constant ROUTER_ADDRESS = 0x4200000000000000000000000000000000000006; // Using WETH as router for now
    address constant SHEEP_MARKET_ADDRESS = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // Market address
    
    // Amount to mint and stake
    uint256 constant AMOUNT_TO_MINT = 0.0001 ether; // Small amount for testing
    uint256 constant AMOUNT_TO_STAKE_SHEEPDOG = 100e18; // Exactly 100 SHEEP tokens to stake
    uint256 constant AMOUNT_TO_STAKE_BTB = 100.5e18; // Accounts for 0.5% fee in BTB
    
    // Chain configuration
    string constant CHAIN_ID = "84532"; // Base Sepolia Chain ID

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        address deployer = vm.addr(deployerPrivateKey);
        string memory baseScanApiKey = vm.envString("basescanapi_key");
        
        console.log("\n=== ALL-IN-ONE DEPLOYMENT SCRIPT ===");
        console.log("Deployer address:", deployer);
        
        // ======= STEP 1: DEPLOY SHEEP ECOSYSTEM =======
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== DEPLOYING SHEEP ECOSYSTEM ===");
        
        // Deploy SHEEP token
        // Using deployer as the POL address for this test deployment
        // This way, the tokens minted to POL will be directly accessible
        sheepToken = new SHEEP(WGAS_TOKEN, deployer);
        console.log("SHEEP token deployed at:", address(sheepToken));

        // Deploy SHEEPDOG contract
        sheepDog = new SHEEPDOG(address(sheepToken), ROUTER_ADDRESS);
        console.log("SHEEPDOG contract deployed at:", address(sheepDog));

        // Deploy WOLF contract
        wolf = new WOLF(address(sheepToken), address(sheepDog), SHEEP_MARKET_ADDRESS);
        console.log("WOLF contract deployed at:", address(wolf));

        // Configure contracts
        sheepToken.buildTheFarm(address(wolf));
        console.log("Wolf address set in SHEEP token");

        // Start SHEEP sale and take out of pasture
        sheepToken.startSale();
        console.log("SHEEP token sale started");
        
        vm.stopBroadcast();
        
        // ======= STEP 2: VERIFY SHEEP ECOSYSTEM CONTRACTS =======
        console.log("\n=== VERIFYING SHEEP ECOSYSTEM CONTRACTS ===");
        
        // SHEEP Token verification
        console.log("\n# Verifying SHEEP token at:", address(sheepToken));
        string memory sheepVerifyCmd = string.concat(
            "forge verify-contract --chain-id ", 
            CHAIN_ID,
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address)\" ",
            vm.toString(WGAS_TOKEN),
            " ",
            vm.toString(deployer), // Using deployer as POL
            ") ",
            vm.toString(address(sheepToken)), 
            " src/sheep/sheeptoken.sol:SHEEP"
        );
        console.log(sheepVerifyCmd);
        
        // SHEEPDOG verification
        console.log("\n# Verifying SHEEPDOG contract at:", address(sheepDog));
        string memory sheepDogVerifyCmd = string.concat(
            "forge verify-contract --chain-id ", 
            CHAIN_ID,
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address)\" ",
            vm.toString(address(sheepToken)),
            " ",
            vm.toString(ROUTER_ADDRESS),
            ") ",
            vm.toString(address(sheepDog)), 
            " src/sheep/sheepdog.sol:SHEEPDOG"
        );
        console.log(sheepDogVerifyCmd);
        
        // WOLF verification
        console.log("\n# Verifying WOLF contract at:", address(wolf));
        string memory wolfVerifyCmd = string.concat(
            "forge verify-contract --chain-id ", 
            CHAIN_ID,
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address,address)\" ",
            vm.toString(address(sheepToken)),
            " ",
            vm.toString(address(sheepDog)),
            " ",
            vm.toString(SHEEP_MARKET_ADDRESS),
            ") ",
            vm.toString(address(wolf)), 
            " src/sheep/wolf.sol:WOLF"
        );
        console.log(wolfVerifyCmd);
        
        // ======= STEP 3: MINT SHEEP TOKENS =======
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== MINTING SHEEP TOKENS ===");
        console.log("Amount to mint:", AMOUNT_TO_MINT / 1e18, "ETH");
        console.log("Expected tokens: ~", (AMOUNT_TO_MINT * 10000) / 1e18, "SHEEP");
        
        // Mint SHEEP tokens using mintForFee (sending ETH directly)
        try sheepToken.mintForFee{value: AMOUNT_TO_MINT}() {
            console.log("Mint successful!");
        } catch Error(string memory reason) {
            console.log("Mint failed. Reason:", reason);
        } catch {
            console.log("Mint failed with unknown error.");
        }
        
        // Now, take the token out of pasture so we can actually transfer/stake them
        sheepToken.takeOutOfPasture();
        console.log("SHEEP token taken out of pasture");
        
        // Check balances - We should have tokens from the mint as well as from POL
        uint256 deployerBalance = sheepToken.balanceOf(deployer);
        console.log("SHEEP balance after minting:", deployerBalance / 1e18);
        
        // ======= STEP 4: DEPOSIT TO SHEEPDOG DIRECTLY =======
        console.log("\n=== DIRECT DEPOSIT TO SHEEPDOG ===");
        
        // Check if we have enough SHEEP for staking in SHEEPDOG
        if (deployerBalance >= AMOUNT_TO_STAKE_SHEEPDOG) {
            console.log("Approving SHEEPDOG to spend SHEEP...");
            sheepToken.approve(address(sheepDog), AMOUNT_TO_STAKE_SHEEPDOG);
            
            console.log("Depositing to SHEEPDOG contract...");
            try sheepDog.protect(AMOUNT_TO_STAKE_SHEEPDOG) {
                console.log("SHEEPDOG deposit successful!");
                
                // Check shares
                uint256 shares = sheepDog.sheepDogShares(deployer);
                console.log("SHEEPDOG shares:", shares / 1e18);
            } catch Error(string memory reason) {
                console.log("SHEEPDOG deposit failed. Reason:", reason);
            } catch {
                console.log("SHEEPDOG deposit failed with unknown error.");
            }
        } else {
            console.log("Not enough SHEEP tokens for SHEEPDOG. Need:", AMOUNT_TO_STAKE_SHEEPDOG / 1e18, "but have:", deployerBalance / 1e18);
        }
        
        vm.stopBroadcast();
        
        // ======= STEP 5: DEPLOY BTB STAKING (SHEEPDOGMANAGER) =======
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== DEPLOYING BTB STAKING ===");
        
        // Deploy the SheepDogManager contract
        sheepDogManager = new SheepDogManager(
            address(sheepToken),
            address(sheepDog),
            ROUTER_ADDRESS,
            deployer // Admin address is the deployer
        );
        
        console.log("SheepDogManager deployed at:", address(sheepDogManager));
        
        // Get proxy addresses
        address addressA = sheepDogManager.addressA();
        address addressB = sheepDogManager.addressB();
        
        console.log("SheepDogProxy A deployed at:", addressA);
        console.log("SheepDogProxy B deployed at:", addressB);
        
        // ======= STEP 6: DEPOSIT TO BTB VAULT (SHEEPDOGMANAGER) =======
        console.log("\n=== DEPOSIT TO BTB VAULT (SHEEPDOGMANAGER) ===");
        
        // Check remaining balance after SHEEPDOG deposit
        deployerBalance = sheepToken.balanceOf(deployer);
        console.log("Remaining SHEEP balance:", deployerBalance / 1e18);
        
        if (deployerBalance >= AMOUNT_TO_STAKE_BTB) {
            console.log("Approving SheepDogManager to spend SHEEP...");
            sheepToken.approve(address(sheepDogManager), AMOUNT_TO_STAKE_BTB);
            
            console.log("Depositing to BTB vault...");
            try sheepDogManager.deposit(AMOUNT_TO_STAKE_BTB) {
                console.log("BTB vault deposit successful!");
                
                // Check user deposits
                uint256 userDeposits = sheepDogManager.userDeposits(deployer);
                console.log("User deposits in BTB vault:", userDeposits / 1e18);
                
                // Check total value locked
                uint256 tvl = sheepDogManager.getTotalSheepValue();
                console.log("Total Value Locked in BTB vault:", tvl / 1e18);
            } catch Error(string memory reason) {
                console.log("BTB vault deposit failed. Reason:", reason);
            } catch {
                console.log("BTB vault deposit failed with unknown error.");
            }
        } else {
            console.log("Not enough SHEEP tokens for BTB vault. Need:", AMOUNT_TO_STAKE_BTB / 1e18, "but have:", deployerBalance / 1e18);
        }
        
        vm.stopBroadcast();
        
        // ======= STEP 7: VERIFY SHEEPDOGMANAGER =======
        console.log("\n=== VERIFYING BTB STAKING CONTRACT ===");
        
        // SheepDogManager verification
        console.log("\n# Verifying SheepDogManager at:", address(sheepDogManager));
        string memory btbVerifyCmd = string.concat(
            "forge verify-contract --chain-id ", 
            CHAIN_ID,
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address,address,address)\" ",
            vm.toString(address(sheepToken)),
            " ",
            vm.toString(address(sheepDog)),
            " ",
            vm.toString(ROUTER_ADDRESS),
            " ",
            vm.toString(deployer),
            ") ",
            vm.toString(address(sheepDogManager)), 
            " src/btb/sheepdogmanger.sol:SheepDogManager"
        );
        console.log(btbVerifyCmd);
        
        // ======= SUMMARY =======
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("SHEEP token:", address(sheepToken));
        console.log("SHEEPDOG contract:", address(sheepDog));
        console.log("WOLF contract:", address(wolf));
        console.log("SheepDogManager (BTB vault):", address(sheepDogManager));
        console.log("SheepDogProxy A:", addressA);
        console.log("SheepDogProxy B:", addressB);
        
        console.log("\n=== STAKING SUMMARY ===");
        console.log("SHEEPDOG deposit:", AMOUNT_TO_STAKE_SHEEPDOG / 1e18, "SHEEP");
        console.log("BTB vault deposit:", AMOUNT_TO_STAKE_BTB / 1e18, "SHEEP");
        
        console.log("\n=== HOW TO RUN THIS SCRIPT ===");
        console.log("forge script script/AllInOneDeploy.s.sol:AllInOneDeploy --rpc-url base_sepolia --broadcast");
        
        console.log("\n=== MANUAL STAKING INSTRUCTIONS ===");
        console.log("To stake via SheepDogManager, you must have exactly 100 SHEEP tokens (no more, no less) for the first deposit.");
        console.log("1. Approve the SheepDogManager to spend your SHEEP tokens:");
        console.log("   sheepToken.approve(", address(sheepDogManager), ", 100.5e18)");
        console.log("2. Deposit into the SheepDogManager:");
        console.log("   sheepDogManager.deposit(100.5e18)");
        
        console.log("\nTo stake directly in SHEEPDOG:");
        console.log("1. Approve the SHEEPDOG contract to spend your SHEEP tokens:");
        console.log("   sheepToken.approve(", address(sheepDog), ", 100e18)");
        console.log("2. Deposit SHEEP into SHEEPDOG:");
        console.log("   sheepDog.protect(100e18)");
    }
} 