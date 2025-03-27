// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";

// This script deploys the full ecosystem including all mock contracts
// and properly links them together

contract DeployFullEcosystemScript is Script {
    // Store deployed contract addresses
    address public sheepToken;
    address public sheepDog;
    address public wolf;
    address public wGasToken;
    address public sheepPool;
    
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying ecosystem contracts from address:", deployer);
        console2.log("-------------------------");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy the wrapped gas token
        MockWGasToken mockWGasToken = new MockWGasToken();
        wGasToken = address(mockWGasToken);
        console2.log("MockWGasToken deployed at:", wGasToken);
        
        // Step 2: Deploy the Sheep token
        MockSheepToken mockSheepToken = new MockSheepToken(wGasToken);
        sheepToken = address(mockSheepToken);
        console2.log("MockSheepToken deployed at:", sheepToken);
        
        // Step 3: Deploy the Wolf contract
        MockWolf mockWolf = new MockWolf(sheepToken);
        wolf = address(mockWolf);
        console2.log("MockWolf deployed at:", wolf);
        
        // Step 4: Deploy the SheepDog contract
        MockSheepDog mockSheepDog = new MockSheepDog(sheepToken);
        sheepDog = address(mockSheepDog);
        console2.log("MockSheepDog deployed at:", sheepDog);
        
        // Step 5: Deploy the BTB staking contract
        SheepPool stakingPool = new SheepPool(sheepToken, sheepDog, wGasToken);
        sheepPool = address(stakingPool);
        console2.log("SheepPool deployed at:", sheepPool);
        
        console2.log("-------------------------");
        console2.log("Setting up contract connections...");
        
        // Step 6: Connect Wolf to SheepDog
        mockWolf.setProtector(sheepDog);
        console2.log("Wolf connected to SheepDog protector");
        
        // Step 7: Connect Sheep to Wolf
        mockSheepToken.setWolf(wolf);
        console2.log("Sheep connected to Wolf");
        
        // Step 8: Fund the contracts with tokens
        // Fund the SheepPool with SHEEP
        uint256 initialPoolAmount = 1000 * 10**18;
        mockSheepToken.transfer(sheepPool, initialPoolAmount);
        console2.log("SheepPool funded with", initialPoolAmount / 10**18, "SHEEP");
        
        // Fund the SheepPool with WGAS for rent payments
        uint256 initialGasAmount = 500 * 10**18;
        mockWGasToken.transfer(sheepPool, initialGasAmount);
        console2.log("SheepPool funded with", initialGasAmount / 10**18, "WGAS");
        
        // Step 9: Initialize the rotation in SheepPool
        uint256 initialRotationAmount = 100 * 10**18;
        mockSheepToken.approve(sheepPool, initialRotationAmount);
        stakingPool.initializeRotation(initialRotationAmount);
        console2.log("SheepPool rotation initialized with", initialRotationAmount / 10**18, "SHEEP");
        
        console2.log("-------------------------");
        console2.log("Deployment and setup complete!");
        console2.log("Contract addresses to set in .env file:");
        console2.log("SHEEP_TOKEN_ADDRESS=", sheepToken);
        console2.log("SHEEPDOG_CONTRACT_ADDRESS=", sheepDog);
        console2.log("WOLF_CONTRACT_ADDRESS=", wolf);
        console2.log("WGAS_TOKEN_ADDRESS=", wGasToken);
        console2.log("SHEEPPOOL_ADDRESS=", sheepPool);
        
        vm.stopBroadcast();
    }
}

// Enhanced mock contracts with inter-contract connections

contract MockWGasToken {
    string public name = "Wrapped Gas Token";
    string public symbol = "WGAS";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        balanceOf[msg.sender] = totalSupply;
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MockSheepToken {
    string public name = "Sheep Token";
    string public symbol = "SHEEP";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;
    address public owner;
    address public wGasToken;
    address public wolf; // Wolf contract address
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(address _wGasToken) {
        owner = msg.sender;
        wGasToken = _wGasToken;
        balanceOf[msg.sender] = totalSupply;
    }
    
    // Set Wolf contract address
    function setWolf(address _wolf) public {
        require(msg.sender == owner, "Not owner");
        wolf = _wolf;
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function burnSheep(uint256 amount) public {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner, "Not owner");
        owner = newOwner;
    }
    
    function eatSheep(address _victim, uint256 _amount, address _owner, uint256 _mintPercent) public {
        // Only the wolf can eat sheep
        require(msg.sender == wolf, "Only wolf can eat sheep");
        
        // Burn victim's sheep
        balanceOf[_victim] -= _amount;
        
        // Mint new sheep based on percentage
        uint256 mintAmount = (_amount * _mintPercent) / 100;
        balanceOf[_owner] += mintAmount;
        
        emit Transfer(_victim, _owner, mintAmount);
    }
}

contract MockWolf {
    address public sheepToken;
    address public protector; // SheepDog contract that protects from the wolf
    
    constructor(address _sheepToken) {
        sheepToken = _sheepToken;
    }
    
    // Set protector (SheepDog) address
    function setProtector(address _protector) public {
        protector = _protector;
    }
    
    // This function simulates the Wolf eating Sheep
    // In reality, it would check if the victim is protected by the SheepDog
    function eat(address victim, uint256 amount) public {
        // Check if victim is protected
        bool isProtected = checkProtection(victim);
        require(!isProtected, "Victim is protected by SheepDog");
        
        // Call eatSheep on the token contract
        // This would burn victim's tokens and mint some percentage to the caller
        MockSheepToken(sheepToken).eatSheep(victim, amount, msg.sender, 50); // 50% mint percentage
    }
    
    // Check if address is protected by SheepDog
    function checkProtection(address user) public view returns (bool) {
        // In the real contract, this would check if the user has tokens in SheepDog
        // For mock purposes, we'll just check if the protector is set
        if (protector == address(0)) return false;
        
        // Check if user has shares in the SheepDog
        uint256 shares = MockSheepDog(protector).sheepDogShares(user);
        return shares > 0;
    }
}

contract MockSheepDog {
    address public sheep;
    
    mapping(address => uint256) public sheepDogShares;
    mapping(address => uint256) public wenToClaim;
    mapping(address => uint256) public rentStart;
    
    uint256 public totalShares;
    uint256 public totalSheep;
    
    constructor(address _sheep) {
        sheep = _sheep;
    }
    
    function protect(uint256 _amount) public {
        IERC20(sheep).transferFrom(msg.sender, address(this), _amount);
        sheepDogShares[msg.sender] += _amount;
        totalShares += _amount;
        totalSheep += _amount;
        if (rentStart[msg.sender] == 0) {
            rentStart[msg.sender] = block.timestamp;
        }
    }
    
    function dogSleep() public {
        wenToClaim[msg.sender] = block.timestamp + 2 days;
    }
    
    function getSheep() public {
        require(wenToClaim[msg.sender] != 0, "Not sleeping");
        require(block.timestamp >= wenToClaim[msg.sender], "Too early");
        
        uint256 amount = sheepDogShares[msg.sender];
        IERC20(sheep).transfer(msg.sender, amount);
        
        sheepDogShares[msg.sender] = 0;
        totalShares -= amount;
        totalSheep -= amount;
        wenToClaim[msg.sender] = 0;
        rentStart[msg.sender] = 0;
    }
    
    function buySheep() public {
        // Mock implementation
    }
    
    function totalSheepBalance() public view returns (uint256) {
        return IERC20(sheep).balanceOf(address(this));
    }
    
    function getCurrentRent(address _user) public view returns (uint256) {
        if (rentStart[_user] == 0) return 0;
        return ((block.timestamp - rentStart[_user]) / 1 days) * 10 * 10**18;
    }
} 