// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SheepPool} from "../src/btb/btbstaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BTBStakingTest is Test {
    SheepPool public sheepPool;
    
    address public sheepToken;
    address public sheepDogContract;
    address public wGasToken;
    
    address public deployer = makeAddr("deployer");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Set up mock addresses
        sheepToken = makeAddr("sheepToken");
        sheepDogContract = makeAddr("sheepDogContract");
        wGasToken = makeAddr("wGasToken");
        
        // Deploy the pool contract
        sheepPool = new SheepPool(sheepToken, sheepDogContract, wGasToken);
        
        vm.stopPrank();
    }
    
    function testInitialSetup() public {
        assertEq(sheepPool.sheepToken(), sheepToken, "SheepToken address not set correctly");
        assertEq(sheepPool.sheepDogContract(), sheepDogContract, "SheepDog address not set correctly");
        assertEq(sheepPool.wGasToken(), wGasToken, "wGasToken address not set correctly");
        (bool isActive, , ) = sheepPool.dogA();
        assertTrue(isActive, "Dog A should be active initially");
        (bool isDogBActive, , ) = sheepPool.dogB();
        assertFalse(isDogBActive, "Dog B should not be active initially");
    }
    
    // Additional tests would be added here
} 