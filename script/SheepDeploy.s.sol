// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";

contract SheepDeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying SheepPool contract from address:", deployer);
        
        address sheepToken = vm.envAddress("SHEEP_TOKEN_ADDRESS");
        address sheepDogContract = vm.envAddress("SHEEPDOG_CONTRACT_ADDRESS");
        address wGasToken = vm.envAddress("WGAS_TOKEN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SheepPool contract
        SheepPool sheepPool = new SheepPool(sheepToken, sheepDogContract, wGasToken);
        
        console2.log("SheepPool deployed at:", address(sheepPool));
        
        vm.stopBroadcast();
    }
} 