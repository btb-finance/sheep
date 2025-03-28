// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

contract VerifyBTBScript is Script {
    function run() public {
        string memory baseSepoliaChainId = "84532"; // Base Sepolia Chain ID
        string memory baseScanApiKey = vm.envString("basescanapi_key");
        
        // SheepDogManager address from recent deployment
        address sheepDogManager = 0xa4d9D3ef30f2D72949F28B62cfbbDfdf15b9726d;
        
        // Original contract addresses used in the deployment
        address sheepToken = 0xD0667Ee6329156e9cFBB1ad9C281590696315db5;
        address sheepDog = 0x46B11ff880eC59a985f443B5931Af41ab665aB06;
        address router = 0x4200000000000000000000000000000000000006;
        
        // Just get deployer's address from environment
        address deployer = vm.addr(vm.envUint("private_key"));
        
        console.log("=== VERIFICATION COMMANDS ===");
        
        // SheepDogManager verification
        console.log("# Verify SheepDogManager contract");
        console.log(string.concat(
            "forge verify-contract --chain-id ", 
            baseSepoliaChainId, 
            " --etherscan-api-key ", 
            baseScanApiKey, 
            " --constructor-args $(cast abi-encode \"constructor(address,address,address,address)\" ",
            vm.toString(sheepToken),
            " ",
            vm.toString(sheepDog),
            " ",
            vm.toString(router),
            " ",
            vm.toString(deployer),
            ") ",
            vm.toString(sheepDogManager), 
            " src/btb/sheepdogmanger.sol:SheepDogManager"
        ));
        
        // SheepDogProxy contracts
        // We'd need to read these addresses from the manager contract in a full implementation
        // For demonstration, we'll use the addresses from the logs
        address sheepDogProxyA = 0x35cd97220286B194fc7fA48c548964DCcB822D96;
        address sheepDogProxyB = 0x5c9d25ee2E675688D69201997EDD443D3287fa6e;
        
        console.log("\n# Note: To verify SheepDogProxy contracts, you may need to manually extract the constructor arguments");
        console.log("# The proxies are created internally by the SheepDogManager contract");
    }
} 