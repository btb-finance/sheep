// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ISheep {
    function wGasToken() external view returns (address);
}

/**
 * @title SheepDogProxy
 * @dev Simple proxy contract that interacts with the SHEEPDOG contract
 * Only the manager can control this proxy
 */
contract SheepDogProxy {
    address public manager;
    address public sheepDog;
    address public sheep;
    address public wGasToken;
    
    constructor(address _manager, address _sheepDog, address _sheep) {
        manager = _manager;
        sheepDog = _sheepDog;
        sheep = _sheep;
        wGasToken = ISheep(_sheep).wGasToken();
    }
    
    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call");
        _;
    }
    
    /**
     * @notice Execute a function call on the SHEEPDOG contract
     * @param data Function call data
     * @return result Return data from the function call
     */
    function executeSheepDogFunction(bytes calldata data) external onlyManager returns (bytes memory) {
        (bool success, bytes memory result) = sheepDog.call(data);
        require(success, "Function call failed");
        return result;
    }
    
    /**
     * @notice Execute the protect function directly
     * @param amount Amount of SHEEP to protect
     */
    function protect(uint256 amount) external onlyManager {
        // This assumes the token has already been approved
        (bool success,) = sheepDog.call(abi.encodeWithSignature("protect(uint256)", amount));
        require(success, "Protect call failed");
    }
    
    /**
     * @notice Execute the dogSleep function directly
     */
    function dogSleep() external onlyManager {
        (bool success,) = sheepDog.call(abi.encodeWithSignature("dogSleep()"));
        require(success, "DogSleep call failed");
    }
    
    /**
     * @notice Execute the getSheep function directly
     */
    function getSheep() external onlyManager {
        (bool success,) = sheepDog.call(abi.encodeWithSignature("getSheep()"));
        require(success, "GetSheep call failed");
    }
    
    /**
     * @notice Execute the buySheep function directly
     */
    function buySheep() external onlyManager {
        (bool success,) = sheepDog.call(abi.encodeWithSignature("buySheep()"));
        require(success, "BuySheep call failed");
    }
    
    /**
     * @notice Approve tokens for SHEEPDOG
     * @param token Token address
     * @param amount Amount to approve
     */
    function approveToken(address token, uint256 amount) external onlyManager {
        IERC20(token).approve(sheepDog, amount);
    }
    
    /**
     * @notice Recover tokens from this proxy
     * @param token Token address
     * @param to Address to send tokens to
     * @param amount Amount to recover
     */
    function recoverTokens(address token, address to, uint256 amount) external onlyManager {
        IERC20(token).transfer(to, amount);
    }
    
    // Allow the proxy to receive ETH if needed
    receive() external payable {}
}