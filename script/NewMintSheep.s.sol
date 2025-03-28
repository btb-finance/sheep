// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SHEEP} from "../src/sheep/sheeptoken.sol";
import {IGasERC20} from "../src/sheep/sheeptoken.sol";
import {SheepDogManager} from "../src/btb/sheepdogmanger.sol";

contract NewMintSheepScript is Script {
    // Deployed contract addresses
    address public constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    address payable public constant SHEEPDOG_MANAGER_ADDRESS = payable(0xceD304db3Ab2F4943c35c9Cb4d162e793A12D5AA);
    
    // Amount to mint - using a very small amount since 1 wei now gives 10000 tokens
    uint256 public constant AMOUNT_TO_MINT = 0.000001 ether; // This should mint 10000 tokens per wei

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOY NEW SHEEP TOKEN WITH MODIFIED PRICE ===");
        console.log("Deployer address:", deployer);
        console.log("Amount to mint:", AMOUNT_TO_MINT / 1e18, "ETH");
        console.log("Expected tokens: ~", (AMOUNT_TO_MINT * 10000) / 1e18, "SHEEP");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy a new SHEEP token
        console.log("Deploying new SHEEP token with modified price logic...");
        SHEEP newSheep = new SHEEP(WETH_ADDRESS, deployer);
        console.log("New SHEEP token deployed at:", address(newSheep));
        
        // Start the sale
        console.log("Starting the sale...");
        newSheep.startSale();
        
        // Try minting with ETH
        console.log("Minting with ETH...");
        try newSheep.mintForFee{value: AMOUNT_TO_MINT}() {
            console.log("Mint successful!");
            
            // Check balance
            uint256 balance = newSheep.balanceOf(deployer);
            console.log("SHEEP balance after minting:", balance / 1e18);
            
            // Take out of pasture (for trading)
            console.log("Taking SHEEP out of pasture...");
            newSheep.takeOutOfPasture();
            
            // Now that we have tokens, let's try to stake them in the existing SheepDogManager
            console.log("Approving SheepDogManager to spend SHEEP...");
            newSheep.approve(SHEEPDOG_MANAGER_ADDRESS, balance);
            
            // The existing SheepDogManager won't work with our new token, but for demonstration:
            console.log("Note: To stake these tokens, you would need a new SheepDogManager instance");
            console.log("that recognizes the new SHEEP token address:", address(newSheep));
        } catch {
            console.log("Mint failed.");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== OPERATION COMPLETED ===");
        console.log("New SHEEP token address:", address(newSheep));
    }
} 