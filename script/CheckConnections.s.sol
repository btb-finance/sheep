// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";
import "./DeployFullEcosystem.s.sol";

/// @notice This script checks all contract connections and token balances
contract CheckConnectionsScript is Script {
    MockSheepToken public sheepToken;
    MockWolf public wolf;
    MockSheepDog public sheepDog;
    SheepPool public sheepPool;
    MockWGasToken public wGasToken;
    
    function setUp() public {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);
        
        // Get deployed contract addresses
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
        console2.log("===== CHECKING CONTRACT CONNECTIONS =====");
        
        // Check SheepToken connections
        console2.log("SHEEP TOKEN:");
        console2.log("- Address: ", address(sheepToken));
        console2.log("- Total Supply: ", sheepToken.totalSupply() / 1e18, " SHEEP");
        console2.log("- Connected Wolf: ", sheepToken.wolf());
        console2.log("- Wolf connection correct: ", sheepToken.wolf() == address(wolf) ? "YES" : "NO");
        
        // Check Wolf connections
        console2.log("\nWOLF CONTRACT:");
        console2.log("- Address: ", address(wolf));
        console2.log("- Connected SheepToken: ", wolf.sheepToken());
        console2.log("- SheepToken connection correct: ", wolf.sheepToken() == address(sheepToken) ? "YES" : "NO");
        console2.log("- Connected SheepDog protector: ", wolf.protector());
        console2.log("- SheepDog connection correct: ", wolf.protector() == address(sheepDog) ? "YES" : "NO");
        
        // Check SheepDog connections
        console2.log("\nSHEEPDOG CONTRACT:");
        console2.log("- Address: ", address(sheepDog));
        console2.log("- Connected SheepToken: ", sheepDog.sheep());
        console2.log("- SheepToken connection correct: ", sheepDog.sheep() == address(sheepToken) ? "YES" : "NO");
        console2.log("- Total SheepDog shares: ", sheepDog.totalShares() / 1e18);
        
        // Check SheepPool connections and state
        console2.log("\nSHEEPPOOL CONTRACT:");
        console2.log("- Address: ", address(sheepPool));
        console2.log("- Connected SheepToken: ", sheepPool.sheepToken());
        console2.log("- SheepToken connection correct: ", sheepPool.sheepToken() == address(sheepToken) ? "YES" : "NO");
        console2.log("- Connected SheepDog: ", sheepPool.sheepDogContract());
        console2.log("- SheepDog connection correct: ", sheepPool.sheepDogContract() == address(sheepDog) ? "YES" : "NO");
        console2.log("- Connected WGasToken: ", sheepPool.wGasToken());
        console2.log("- WGasToken connection correct: ", sheepPool.wGasToken() == address(wGasToken) ? "YES" : "NO");
        
        // Check contract balances
        console2.log("\n===== CONTRACT BALANCES =====");
        console2.log("SheepPool SHEEP balance: ", sheepToken.balanceOf(address(sheepPool)) / 1e18);
        console2.log("SheepPool WGAS balance: ", wGasToken.balanceOf(address(sheepPool)) / 1e18);
        
        // Check dog positions
        (bool dogAActive, uint256 dogASleepStartTime, uint256 dogAAmount) = sheepPool.dogA();
        (bool dogBActive, uint256 dogBSleepStartTime, uint256 dogBAmount) = sheepPool.dogB();
        
        console2.log("\n===== DOG POSITIONS =====");
        console2.log("Dog A:");
        console2.log("- Active: ", dogAActive ? "YES" : "NO");
        console2.log("- Sleep start time: ", dogASleepStartTime);
        console2.log("- Amount: ", dogAAmount / 1e18, " SHEEP");
        
        console2.log("\nDog B:");
        console2.log("- Active: ", dogBActive ? "YES" : "NO");
        console2.log("- Sleep start time: ", dogBSleepStartTime);
        console2.log("- Amount: ", dogBAmount / 1e18, " SHEEP");
        
        // Check if rotation is ready
        (bool isReady, uint256 nextRotationTime) = sheepPool.isRotationReady();
        console2.log("\nRotation status:");
        console2.log("- Ready for rotation: ", isReady ? "YES" : "NO");
        console2.log("- Next rotation time: ", nextRotationTime);
        console2.log("- Current block time: ", block.timestamp);
        console2.log("- Time until rotation: ", nextRotationTime > block.timestamp ? nextRotationTime - block.timestamp : 0, " seconds");
    }
} 