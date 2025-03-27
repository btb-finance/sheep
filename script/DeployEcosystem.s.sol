// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/btb/btbstaking.sol";

// This is a mock version of the Sheep contract for testing
contract MockSheepToken {
    string public name = "Sheep Token";
    string public symbol = "SHEEP";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10**18;
    address public owner;
    address public wGasToken;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(address _wGasToken) {
        owner = msg.sender;
        wGasToken = _wGasToken;
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
        balanceOf[_victim] -= _amount;
        uint256 mintAmount = (_amount * _mintPercent) / 100;
        balanceOf[_owner] += mintAmount;
        emit Transfer(_victim, _owner, mintAmount);
    }
}

// This is a mock version of the SheepDog contract for testing
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

// This is a mock version of the wrapped gas token for testing
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

contract DeployEcosystemScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying ecosystem contracts from address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // First deploy the mock WGAS token
        MockWGasToken wGasToken = new MockWGasToken();
        console2.log("MockWGasToken deployed at:", address(wGasToken));
        
        // Then deploy the mock Sheep token
        MockSheepToken sheepToken = new MockSheepToken(address(wGasToken));
        console2.log("MockSheepToken deployed at:", address(sheepToken));
        
        // Then deploy the mock SheepDog contract
        MockSheepDog sheepDog = new MockSheepDog(address(sheepToken));
        console2.log("MockSheepDog deployed at:", address(sheepDog));
        
        // Finally deploy the BTB staking contract
        SheepPool sheepPool = new SheepPool(address(sheepToken), address(sheepDog), address(wGasToken));
        console2.log("SheepPool deployed at:", address(sheepPool));
        
        // Fund the SheepPool with some initial SHEEP for testing
        uint256 initialAmount = 1000 * 10**18;
        sheepToken.transfer(address(sheepPool), initialAmount);
        console2.log("SheepPool funded with", initialAmount / 10**18, "SHEEP");
        
        vm.stopBroadcast();
    }
} 