// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SHEEP} from "../src/sheep/sheeptoken.sol";
import {SHEEPDOG} from "../src/sheep/sheepdog.sol";
import {WOLF} from "../src/sheep/wolf.sol";

contract ConnectContracts is Script {
    // Contract instances
    SHEEP public sheepToken;
    SHEEPDOG public sheepDog;
    WOLF public wolf;
    
    // Hardcoded contract addresses from previous deployment
    address public constant SHEEP_TOKEN_ADDRESS = 0x186bDbd61A33a5bd71A357f1106C0D840Bf2279d;
    address public constant SHEEPDOG_ADDRESS = 0x3F22d29F8f6e6668F56E8472c10b0b842B83458c;
    address public constant WOLF_ADDRESS = 0xB75361924bcD5Ffa74Dca345797bE5652b5884B2;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("private_key");
        
        console.log("=== CONNECTING CONTRACTS AND PERFORMING OPERATIONS ===");
        console.log("SHEEP token address:", SHEEP_TOKEN_ADDRESS);
        console.log("SHEEPDOG contract address:", SHEEPDOG_ADDRESS);
        console.log("WOLF contract address:", WOLF_ADDRESS);
        
        // Connect to deployed contracts
        sheepToken = SHEEP(SHEEP_TOKEN_ADDRESS);
        sheepDog = SHEEPDOG(SHEEPDOG_ADDRESS);
        wolf = WOLF(WOLF_ADDRESS);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Ensure connections are set properly
        if (sheepToken.wolf() != WOLF_ADDRESS) {
            console.log("Setting wolf address in SHEEP token...");
            sheepToken.buildTheFarm(WOLF_ADDRESS);
        } else {
            console.log("Wolf address already set in SHEEP token");
        }
        
        // Ensure the sale has started and sheep are out of pasture
        if (sheepToken.pastured()) {
            console.log("Taking SHEEP out of pasture...");
            sheepToken.takeOutOfPasture();
        } else {
            console.log("SHEEP are already out of pasture");
        }
        
        if (!sheepToken.saleStarted()) {
            console.log("Starting SHEEP sale...");
            sheepToken.startSale();
        } else {
            console.log("SHEEP sale has already started");
        }
        
        // Check contract configurations
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("\n=== CONTRACT CONFIGURATIONS ===");
        console.log("SHEEP token owner:", sheepToken.owner());
        console.log("SHEEPDOG owner:", sheepDog.owner());
        console.log("WOLF owner:", wolf.owner());
        console.log("SHEEP wolf address:", sheepToken.wolf());
        console.log("SHEEP pastured:", sheepToken.pastured());
        console.log("SHEEP sale started:", sheepToken.saleStarted());
        
        // Print out instructions for manual operations
        console.log("\n=== MANUAL OPERATIONS INSTRUCTIONS ===");
        console.log("To mint SHEEP tokens (requires WETH):");
        console.log("1. Approve SHEEP contract to spend your WETH");
        console.log("2. Call sheepToken.mintForFee(amount)");
        
        console.log("\nTo stake SHEEP tokens in SHEEPDOG:");
        console.log("1. Approve SHEEPDOG contract to spend your SHEEP");
        console.log("2. Call sheepDog.protect(amount)");
        
        console.log("\nTo mint a WOLF NFT:");
        console.log("1. Approve WOLF contract to spend your SHEEP");
        console.log("2. Approve WOLF contract to spend your WETH");
        console.log("3. Call wolf.getWolf()");
        
        vm.stopBroadcast();
        
        console.log("\n=== OPERATIONS COMPLETED SUCCESSFULLY ===");
    }
}

// Define interface for IERC20 used for token approvals
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
} 