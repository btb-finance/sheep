// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SHEEP} from "../src/sheep/sheeptoken.sol";
import {SHEEPDOG} from "../src/sheep/sheepdog.sol";
import {WOLF} from "../src/sheep/wolf.sol";

contract DeployScript is Script {
    // Contract instances
    SHEEP public sheepToken;
    SHEEPDOG public sheepDog;
    WOLF public wolf;

    // Constants for Base Sepolia
    address constant WGAS_TOKEN = 0x4200000000000000000000000000000000000006; // WETH on Base Sepolia
    address constant POL_ADDRESS = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // Updated POL address for Base Sepolia
    address constant ROUTER_ADDRESS = 0x4200000000000000000000000000000000000006; // Using WETH as router for now
    address constant SHEEP_MARKET_ADDRESS = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // Updated market address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        
        console.log("=== DEPLOYMENT PHASE ===");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy SHEEP token
        sheepToken = new SHEEP(WGAS_TOKEN, POL_ADDRESS);
        console.log("SHEEP token deployed at:", address(sheepToken));

        // Deploy SHEEPDOG contract
        sheepDog = new SHEEPDOG(address(sheepToken), ROUTER_ADDRESS);
        console.log("SHEEPDOG contract deployed at:", address(sheepDog));

        // Deploy WOLF contract
        wolf = new WOLF(address(sheepToken), address(sheepDog), SHEEP_MARKET_ADDRESS);
        console.log("WOLF contract deployed at:", address(wolf));

        // Configure contracts
        // Set the wolf address in SHEEP contract
        sheepToken.buildTheFarm(address(wolf));
        console.log("Wolf address set in SHEEP token");

        // Take SHEEP out of pasture and start sale
        sheepToken.startSale();
        sheepToken.takeOutOfPasture();
        console.log("SHEEP token sale started and taken out of pasture");

        vm.stopBroadcast();
        
        // Print deployed contract addresses
        console.log("\n=== DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("SHEEP token:", address(sheepToken));
        console.log("SHEEPDOG contract:", address(sheepDog));
        console.log("WOLF contract:", address(wolf));
        
        // Save the contract addresses to environment variables
        vm.setEnv("SHEEP_ADDRESS", vm.toString(address(sheepToken)));
        vm.setEnv("SHEEPDOG_ADDRESS", vm.toString(address(sheepDog)));
        vm.setEnv("WOLF_ADDRESS", vm.toString(address(wolf)));
        
        console.log("\n=== HOW TO VERIFY CONTRACTS ===");
        console.log("Run this command to verify all contracts:");
        console.log("forge script script/DeployVerify.s.sol:VerifyScript --rpc-url base_sepolia");
    }
}

contract VerifyScript is Script {
    function run() public {
        string memory baseSepoliaChainId = "84532"; // Base Sepolia Chain ID
        string memory baseScanApiKey = vm.envString("basescanapi_key");
        
        // Read deployment addresses from environment variables
        address sheepToken = vm.envAddress("SHEEP_ADDRESS");
        address sheepDog = vm.envAddress("SHEEPDOG_ADDRESS");
        address wolf = vm.envAddress("WOLF_ADDRESS");
        
        console.log("Verifying contracts with addresses:");
        console.log("SHEEP token:", sheepToken);
        console.log("SHEEPDOG contract:", sheepDog);
        console.log("WOLF contract:", wolf);
        
        // Common addresses for Base Sepolia
        address wGasToken = 0x4200000000000000000000000000000000000006; // WETH on Base Sepolia
        address polAddress = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // Updated POL address for Base Sepolia
        address routerAddress = 0x4200000000000000000000000000000000000006; // Using WETH as router for now
        address sheepMarketAddress = 0xf237dE5664D3c2D2545684E76fef02A3A58A364c; // Updated market address

        console.log("\n=== VERIFICATION COMMANDS ===");
        
        // SHEEP Token verification
        console.log("# Verify SHEEP token");
        console.log(string.concat(
            "forge verify-contract --chain-id ", 
            baseSepoliaChainId, 
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address)\" ",
            vm.toString(wGasToken),
            " ",
            vm.toString(polAddress),
            ") ",
            vm.toString(sheepToken), 
            " src/sheep/sheeptoken.sol:SHEEP"
        ));
        
        // SHEEPDOG verification
        console.log("\n# Verify SHEEPDOG contract");
        console.log(string.concat(
            "forge verify-contract --chain-id ", 
            baseSepoliaChainId, 
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address)\" ",
            vm.toString(sheepToken),
            " ",
            vm.toString(routerAddress),
            ") ",
            vm.toString(sheepDog), 
            " src/sheep/sheepdog.sol:SHEEPDOG"
        ));
        
        // WOLF verification
        console.log("\n# Verify WOLF contract");
        console.log(string.concat(
            "forge verify-contract --chain-id ", 
            baseSepoliaChainId, 
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address,address)\" ",
            vm.toString(sheepToken),
            " ",
            vm.toString(sheepDog),
            " ",
            vm.toString(sheepMarketAddress),
            ") ",
            vm.toString(wolf), 
            " src/sheep/wolf.sol:WOLF"
        ));
    }
}