// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/btb/sheepdogmanger.sol";

contract DeployBTBScript is Script {
    // Updated contract addresses from our most recent deployment
    address public constant SHEEP_TOKEN_ADDRESS = 0xD0667Ee6329156e9cFBB1ad9C281590696315db5;
    address public constant SHEEPDOG_ADDRESS = 0x46B11ff880eC59a985f443B5931Af41ab665aB06;
    address public constant WOLF_ADDRESS = 0xD5F3462A3C332720D58b6036e784679d57446f82;
    
    // Router address for token swaps
    address public constant ROUTER_ADDRESS = 0x4200000000000000000000000000000000000006; // Using WETH as router for now
    
    // Deployed contracts
    SheepDogManager public sheepDogManager;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BTB DEPLOYMENT PHASE ===");
        console.log("Deployer address:", deployer);
        console.log("SHEEP token address:", SHEEP_TOKEN_ADDRESS);
        console.log("SHEEPDOG contract address:", SHEEPDOG_ADDRESS);
        console.log("WOLF address:", WOLF_ADDRESS);
        console.log("Router address:", ROUTER_ADDRESS);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the SheepDogManager contract
        // Parameters: sheep, sheepDog, router, admin
        sheepDogManager = new SheepDogManager(
            SHEEP_TOKEN_ADDRESS,
            SHEEPDOG_ADDRESS,
            ROUTER_ADDRESS,
            deployer // Admin address is the deployer
        );
        
        console.log("SheepDogManager deployed at:", address(sheepDogManager));
        
        // Addresses of the proxy contracts are stored in the manager contract
        address addressA = sheepDogManager.addressA();
        address addressB = sheepDogManager.addressB();
        
        console.log("SheepDogProxy A deployed at:", addressA);
        console.log("SheepDogProxy B deployed at:", addressB);
        
        vm.stopBroadcast();
        
        console.log("\n=== BTB DEPLOYMENT COMPLETED SUCCESSFULLY ===");
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Fund the SheepDogManager contract with SHEEP tokens");
        console.log("2. Call deposit() to stake SHEEP in the active proxy");
        console.log("3. Check the manager's total value locked with getTotalSheepValue()");
    }
}