// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ISheep
 * @dev Interface for interacting with the SHEEP token contract
 */
interface ISheep {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function wGasToken() external view returns (address);
}

/**
 * @title ISheepDog
 * @dev Interface for interacting with the SHEEPDOG staking contract
 */
interface ISheepDog {
    function protect(uint256 _amount) external;
    function dogSleep() external;
    function getSheep() external;
    function getCurrentRent(address _user) external view returns (uint256);
    function totalSheepBalance() external view returns (uint256);
    function sheepDogShares(address) external view returns (uint256);
    function wenToClaim(address) external view returns (uint256);
    function buySheep() external;
}

/**
 * @title IERC20
 * @dev Basic interface for ERC20 tokens (for wGasToken)
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title IRouter
 * @dev Simple interface for DEX router (for swapping tokens if needed)
 */
interface IRouter {
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

// Import or include the SheepDogProxy contract
interface ISheepDogProxy {
    function protect(uint256 amount) external;
    function dogSleep() external;
    function getSheep() external;
    function buySheep() external;
    function approveToken(address token, uint256 amount) external;
    function recoverTokens(address token, address to, uint256 amount) external;
    function executeSheepDogFunction(bytes calldata data) external returns (bytes memory);
}

/**
 * @title SheepDogManager
 * @dev Manager contract for handling SHEEPDOG staking with two-address rotation
 * All yield is directed to the admin while users get back exactly what they deposited
 */
contract SheepDogManager {
    /* ========== STATE VARIABLES ========== */
    
    // Core contract addresses
    address public sheep;           // SHEEP token contract
    address public sheepDog;        // SHEEPDOG staking contract
    address public wGasToken;       // Wrapped gas token (from SHEEP contract)
    address public router;          // Router for token swaps (optional)
    
    // Two addresses for rotation
    address public addressA;        // First SHEEPDOG interaction address
    address public addressB;        // Second SHEEPDOG interaction address
    
    // Current active state
    address public activeAddress;   // Currently active address for deposits
    address public sleepingAddress; // Address currently in sleeping state
    
    // Rotation timing
    uint256 public lastRotationTimestamp;    // When the last rotation occurred
    uint256 public nextWithdrawalTimestamp;  // When the next withdrawal is scheduled
    uint256 public withdrawalInterval = 7 days; // How often withdrawals are processed
    
    // User accounting - track exact token amounts
    uint256 public totalDeposits;            // Total SHEEP deposited by users
    mapping(address => uint256) public userDeposits; // Exact amount of SHEEP deposited by each user
    
    // Withdrawal requests
    mapping(address => WithdrawalRequest) public withdrawalRequests;
    address[] public withdrawalQueue; // Users who have requested withdrawals
    uint256 public maxWithdrawalQueueSize = 100; // Maximum number of users in withdrawal queue
    
    // Protocol metrics
    uint256 public totalValueLocked;  // Total SHEEP value across both addresses
    uint256 public cumulativeRewards; // Total rewards accrued since inception
    uint256 public lastRewardSnapshot; // Last recorded TVL for reward calculation
    
    // Fee settings
    uint256 public gasReserveBps = 50;  // 0.5% reserved for gas payments (in basis points)
    
    // Admin address (all rewards go here)
    address public admin;
    
    // Platform state
    bool public emergencyShutdown; // Emergency pause
    
    // Tracking deposits per proxy to ensure sufficient funds for withdrawals
    mapping(address => uint256) public proxyTotalDeposits;
    
    /* ========== STRUCTS ========== */
    
    struct WithdrawalRequest {
        uint256 amount;           // Amount of SHEEP to withdraw
        uint256 requestTimestamp; // When the request was made
        bool processed;           // Whether the request has been processed
    }
    
    struct AddressState {
        uint256 depositedSheep;  // Total SHEEP deposited to this address
        bool isSleeping;         // Whether dog sleep has been called
        uint256 sleepTimestamp;  // When dog sleep was called
        bool canWithdraw;        // Whether address is ready for withdrawal
    }
    
    mapping(address => AddressState) public addressStates;
    
    /* ========== EVENTS ========== */
    
    event Deposited(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardHarvested(uint256 rewardAmount);
    event AddressRotated(address oldActive, address newActive);
    event EmergencyShutdownSet(bool status);
    event ParameterUpdated(string parameter, uint256 value);
    event WithdrawalQueueFull(address indexed user, uint256 amount);
    
    /* ========== CONSTRUCTOR ========== */
    
    constructor(
        address _sheep,
        address _sheepDog,
        address _router,
        address _admin
    ) {
        sheep = _sheep;
        sheepDog = _sheepDog;
        wGasToken = ISheep(_sheep).wGasToken();
        router = _router;
        admin = _admin;
        
        // Deploy the two proxy contracts
        addressA = address(new SheepDogProxy(address(this), sheepDog, sheep));
        addressB = address(new SheepDogProxy(address(this), sheepDog, sheep));
        
        // Set Address A as the initial active address
        activeAddress = addressA;
        
        // Set initial protocol parameters
        lastRotationTimestamp = block.timestamp;
        nextWithdrawalTimestamp = block.timestamp + withdrawalInterval;
    }
    
    /* ========== MODIFIERS ========== */
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }
    
    modifier notEmergencyShutdown() {
        require(!emergencyShutdown, "Contract is in emergency shutdown");
        _;
    }
    
    /* ========== USER FUNCTIONS ========== */
    
    /**
     * @notice Deposit SHEEP tokens to stake in the active SHEEPDOG address
     * @param amount Amount of SHEEP to deposit
     */
    function deposit(uint256 amount) external notEmergencyShutdown {
        require(amount > 0, "Cannot deposit 0");
        
        // Transfer SHEEP from user to this contract
        ISheep(sheep).transferFrom(msg.sender, address(this), amount);
        
        // Handle gas reserve if enabled
        uint256 gasReserveAmount = (amount * gasReserveBps) / 10000;
        uint256 netDepositAmount = amount - gasReserveAmount;
        
        // Transfer SHEEP to the proxy contract
        ISheep(sheep).transfer(activeAddress, netDepositAmount);
        
        // Have the proxy approve SHEEP for the SHEEPDOG contract
        ISheepDogProxy(activeAddress).approveToken(sheep, netDepositAmount);
        
        // Call protect through the proxy
        ISheepDogProxy(activeAddress).protect(netDepositAmount);
        
        // Update user deposits and total
        userDeposits[msg.sender] += netDepositAmount;
        totalDeposits += netDepositAmount;
        
        // Update total value locked
        totalValueLocked += netDepositAmount;
        
        // Update address state
        addressStates[activeAddress].depositedSheep += netDepositAmount;
        
        // Track deposits per proxy for safety checks
        proxyTotalDeposits[activeAddress] += netDepositAmount;
        
        emit Deposited(msg.sender, netDepositAmount);
    }
    
    /**
     * @notice Request withdrawal of SHEEP
     * @param amount Amount of SHEEP to withdraw
     */
    function requestWithdrawal(uint256 amount) external notEmergencyShutdown {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= userDeposits[msg.sender], "Not enough deposits");
        
        // Check if the withdrawal queue is too large
        require(withdrawalQueue.length < maxWithdrawalQueueSize || 
                withdrawalRequests[msg.sender].amount > 0, 
                "Withdrawal queue is full");
        
        // Add or update withdrawal request
        if (withdrawalRequests[msg.sender].amount == 0) {
            // Only add to queue if not already in queue
            if (withdrawalQueue.length < maxWithdrawalQueueSize) {
                withdrawalQueue.push(msg.sender);
            } else {
                emit WithdrawalQueueFull(msg.sender, amount);
                revert("Withdrawal queue is full");
            }
        }
        
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            requestTimestamp: block.timestamp,
            processed: false
        });
        
        emit WithdrawalRequested(msg.sender, amount);
    }
    
    /**
     * @notice Get user's claimable SHEEP amount (always equals their deposit)
     * @param user User address
     * @return Claimable SHEEP amount
     */
    function getUserClaimableAmount(address user) public view returns (uint256) {
        return userDeposits[user];
    }
    
    /* ========== ROTATION FUNCTIONS ========== */
    
    /**
     * @notice Check if it's time to initiate the next withdrawal cycle
     * @return Whether rotation should be initiated
     */
    function shouldInitiateRotation() public view returns (bool) {
        return block.timestamp >= nextWithdrawalTimestamp;
    }
    
    /**
     * @notice Initiate the next withdrawal cycle by putting the active address to sleep
     */
    function initiateRotation() external notEmergencyShutdown {
        require(shouldInitiateRotation(), "Not time to rotate yet");
        
        // Call dogSleep through the proxy
        ISheepDogProxy(activeAddress).dogSleep();
        
        // Update address states
        addressStates[activeAddress].isSleeping = true;
        addressStates[activeAddress].sleepTimestamp = block.timestamp;
        
        // Mark the address as sleeping
        sleepingAddress = activeAddress;
        
        // Schedule the next rotation
        lastRotationTimestamp = block.timestamp;
        
        emit AddressRotated(activeAddress, sleepingAddress);
    }
    
    /**
     * @notice Check if the sleeping address is ready for withdrawal and has sufficient funds
     * @return Whether the address is ready for withdrawal
     */
    function canCompleteRotation() public view returns (bool) {
        // Make sure at least 2 days have passed since initiating sleep
        if (!(sleepingAddress != address(0) && 
            addressStates[sleepingAddress].isSleeping &&
            block.timestamp >= addressStates[sleepingAddress].sleepTimestamp + 2 days)) {
            return false;
        }
        
        // Check if there are pending withdrawal requests
        uint256 totalWithdrawalAmount = calculatePendingWithdrawalsTotal();
        if (totalWithdrawalAmount == 0) {
            return true; // No withdrawals to process, can complete rotation
        }
        
        // Check if there are enough funds in the sleeping proxy
        // This is an estimate since we can't know the exact amount until after getSheep()
        uint256 expectedProxyValue = proxyTotalDeposits[sleepingAddress];
        
        // Require at least 95% of the expected value to be available
        // (allowing for small fluctuations or fees)
        return expectedProxyValue >= totalWithdrawalAmount;
    }
    
    /**
     * @notice Complete the rotation by processing withdrawals and moving funds to the other address
     */
    function completeRotation() external notEmergencyShutdown {
        require(canCompleteRotation(), "Not ready to complete rotation");
        
        // Save reference to which address is which
        address withdrawalAddress = sleepingAddress;
        address nextActiveAddress = (withdrawalAddress == addressA) ? addressB : addressA;
        
        // Get pending withdrawal total for safety check
        uint256 totalWithdrawalAmount = calculatePendingWithdrawalsTotal();
        
        // Take snapshot of total value before withdrawal for reward calculation
        uint256 beforeWithdrawalBalance = getTotalSheepValue();
        
        // Prepare wGasToken for rent payment
        uint256 rentAmount = ISheepDog(sheepDog).getCurrentRent(withdrawalAddress);
        require(IERC20(wGasToken).balanceOf(address(this)) >= rentAmount, "Not enough wGasToken");
        
        // Transfer wGasToken to the proxy
        IERC20(wGasToken).transfer(withdrawalAddress, rentAmount);
        
        // Have the proxy approve wGasToken for the SHEEPDOG contract
        ISheepDogProxy(withdrawalAddress).approveToken(wGasToken, rentAmount);
        
        // Call getSheep through the proxy
        ISheepDogProxy(withdrawalAddress).getSheep();
        
        // Recover SHEEP from the proxy
        uint256 proxyBalance = ISheep(sheep).balanceOf(withdrawalAddress);
        if (proxyBalance > 0) {
            ISheepDogProxy(withdrawalAddress).recoverTokens(sheep, address(this), proxyBalance);
        }
        
        // Double-check we have enough funds after withdrawal
        uint256 contractBalance = ISheep(sheep).balanceOf(address(this));
        require(contractBalance >= totalWithdrawalAmount, 
                "Insufficient funds to process withdrawals");
        
        // Process withdrawal requests
        processWithdrawalRequests();
        
        // Reset proxy total deposits
        proxyTotalDeposits[withdrawalAddress] = 0;
        
        // Calculate if there are any rewards (excess SHEEP)
        contractBalance = ISheep(sheep).balanceOf(address(this));
        uint256 pendingWithdrawalsTotal = calculatePendingWithdrawalsTotal();
        
        // If we have more SHEEP than needed for pending withdrawals, those are rewards
        if (contractBalance > pendingWithdrawalsTotal) {
            uint256 rewardAmount = contractBalance - pendingWithdrawalsTotal;
            
            // Transfer rewards to admin
            ISheep(sheep).transfer(admin, rewardAmount);
            
            // Update cumulative rewards
            cumulativeRewards += rewardAmount;
            
            emit RewardHarvested(rewardAmount);
        }
        
        // Calculate the remaining SHEEP balance to transfer to the next active address
        uint256 remainingSheep = ISheep(sheep).balanceOf(address(this));
        
        // Deposit remaining SHEEP to the next active address
        if (remainingSheep > 0) {
            // Transfer SHEEP to the next active proxy
            ISheep(sheep).transfer(nextActiveAddress, remainingSheep);
            
            // Have the proxy approve SHEEP for the SHEEPDOG contract
            ISheepDogProxy(nextActiveAddress).approveToken(sheep, remainingSheep);
            
            // Call protect through the proxy
            ISheepDogProxy(nextActiveAddress).protect(remainingSheep);
            
            // Update proxy total deposits
            proxyTotalDeposits[nextActiveAddress] += remainingSheep;
        }
        
        // Update address states
        addressStates[withdrawalAddress].isSleeping = false;
        addressStates[withdrawalAddress].canWithdraw = false;
        addressStates[withdrawalAddress].depositedSheep = 0;
        addressStates[nextActiveAddress].depositedSheep = remainingSheep;
        
        // Update protocol addresses
        activeAddress = nextActiveAddress;
        sleepingAddress = address(0);
        
        // Schedule next withdrawal
        nextWithdrawalTimestamp = block.timestamp + withdrawalInterval;
        
        // Update total value locked
        totalValueLocked = remainingSheep;
        
        emit AddressRotated(withdrawalAddress, activeAddress);
    }
    
    /**
     * @notice Process all pending withdrawal requests
     */
    function processWithdrawalRequests() internal {
        uint256 queueLength = withdrawalQueue.length;
        if (queueLength == 0) return;
        
        for (uint256 i = 0; i < queueLength; i++) {
            address user = withdrawalQueue[i];
            WithdrawalRequest memory request = withdrawalRequests[user];
            
            if (!request.processed && request.amount > 0 && userDeposits[user] >= request.amount) {
                // Transfer SHEEP to user - they get exactly what they deposited
                ISheep(sheep).transfer(user, request.amount);
                
                // Update user deposits
                userDeposits[user] -= request.amount;
                totalDeposits -= request.amount;
                
                // Mark request as processed
                withdrawalRequests[user].processed = true;
                
                emit Withdrawn(user, request.amount);
            }
        }
        
        // Clear the withdrawal queue
        delete withdrawalQueue;
    }
    
    /**
     * @notice Calculate total of all pending withdrawal requests
     * @return Total SHEEP needed for pending withdrawals
     */
    function calculatePendingWithdrawalsTotal() internal view returns (uint256) {
        uint256 total = 0;
        uint256 queueLength = withdrawalQueue.length;
        
        for (uint256 i = 0; i < queueLength; i++) {
            address user = withdrawalQueue[i];
            WithdrawalRequest memory request = withdrawalRequests[user];
            
            if (!request.processed && request.amount > 0 && userDeposits[user] >= request.amount) {
                total += request.amount;
            }
        }
        
        return total;
    }
    
    /* ========== REWARD FUNCTIONS ========== */
    
    /**
     * @notice Call buySheep on the active address to realize rewards
     */
    function harvestRewards() external notEmergencyShutdown {
        uint256 beforeBalance = getTotalSheepValue();
        
        // Call buySheep through the proxy
        ISheepDogProxy(activeAddress).buySheep();
        
        // Recover any SHEEP that might have been sent to the proxy as caller reward
        uint256 proxyBalance = ISheep(sheep).balanceOf(activeAddress);
        if (proxyBalance > 0) {
            ISheepDogProxy(activeAddress).recoverTokens(sheep, address(this), proxyBalance);
        }
        
        // Calculate new rewards
        uint256 afterBalance = getTotalSheepValue();
        
        if (afterBalance > beforeBalance) {
            uint256 rewardAmount = afterBalance - beforeBalance;
            
            // Calculate the amount needed for user deposits
            uint256 amountNeededForDeposits = totalDeposits;
            
            // If we have excess SHEEP (rewards), send them to admin
            if (afterBalance > amountNeededForDeposits) {
                uint256 excessAmount = afterBalance - amountNeededForDeposits;
                ISheep(sheep).transfer(admin, excessAmount);
                
                // Update cumulative rewards
                cumulativeRewards += excessAmount;
                
                emit RewardHarvested(excessAmount);
            }
        }
        
        // Update the reward snapshot
        lastRewardSnapshot = afterBalance;
    }
    
    /* ========== VIEW FUNCTIONS ========== */
    
    /**
     * @notice Get total SHEEP value across both addresses
     * @return Total SHEEP value
     */
    function getTotalSheepValue() public returns (uint256) {
        // Get balances from both proxy addresses via the SHEEPDOG contract
        uint256 aValue = 0;
        uint256 bValue = 0;
        
        if (addressA != address(0)) {
            bytes memory result = ISheepDogProxy(addressA).executeSheepDogFunction(
                abi.encodeWithSignature("totalSheepBalance()")
            );
            if (result.length > 0) {
                aValue = abi.decode(result, (uint256));
            }
        }
        
        if (addressB != address(0)) {
            bytes memory result = ISheepDogProxy(addressB).executeSheepDogFunction(
                abi.encodeWithSignature("totalSheepBalance()")
            );
            if (result.length > 0) {
                bValue = abi.decode(result, (uint256));
            }
        }
        
        uint256 contractBalance = ISheep(sheep).balanceOf(address(this));
        
        return aValue + bValue + contractBalance;
    }
    
    /**
     * @notice Get current APY based on reward accrual
     * @return APY (in basis points, e.g. 500 = 5%)
     */
    function getCurrentAPY() public view returns (uint256) {
        if (lastRewardSnapshot == 0 || lastRotationTimestamp == block.timestamp) {
            return 0;
        }
        
        uint256 timePassed = block.timestamp - lastRotationTimestamp;
        uint256 rewardsPerSecond = (cumulativeRewards * 1e18) / timePassed;
        uint256 annualRewards = rewardsPerSecond * 365 days;
        
        if (totalDeposits == 0) return 0;
        
        // Return APY in basis points (e.g. 500 = 5%)
        return (annualRewards * 10000) / (totalDeposits * 1e18);
    }
    
    /* ========== ADMIN FUNCTIONS ========== */
    
    /**
     * @notice Set the withdrawal interval
     * @param newInterval New interval in seconds
     */
    function setWithdrawalInterval(uint256 newInterval) external onlyAdmin {
        require(newInterval >= 1 days, "Interval too short");
        withdrawalInterval = newInterval;
        emit ParameterUpdated("withdrawalInterval", newInterval);
    }
    
    /**
     * @notice Set the gas reserve basis points
     * @param newGasReserveBps New gas reserve in basis points
     */
    function setGasReserveBps(uint256 newGasReserveBps) external onlyAdmin {
        require(newGasReserveBps <= 500, "Gas reserve too high"); // Max 5%
        gasReserveBps = newGasReserveBps;
        emit ParameterUpdated("gasReserveBps", newGasReserveBps);
    }
    
    /**
     * @notice Toggle emergency shutdown
     * @param status New shutdown status
     */
    function setEmergencyShutdown(bool status) external onlyAdmin {
        emergencyShutdown = status;
        emit EmergencyShutdownSet(status);
    }
    
    /**
     * @notice Transfer admin role
     * @param newAdmin New admin address
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }
    
    /**
     * @notice Emergency withdraw tokens
     * @param token Token to withdraw
     */
    function emergencyWithdraw(address token) external onlyAdmin {
        require(emergencyShutdown, "Not in emergency shutdown");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(admin, balance);
    }
    
    /**
     * @notice Buy wGasToken by swapping SHEEP
     * @param sheepAmount Amount of SHEEP to swap
     */
    function buyWGasToken(uint256 sheepAmount) external onlyAdmin {
        require(sheepAmount > 0, "Amount must be greater than 0");
        require(ISheep(sheep).balanceOf(address(this)) >= sheepAmount, "Not enough SHEEP");
        
        ISheep(sheep).approve(router, sheepAmount);
        IRouter(router).swapExactTokensForTokensSimple(
            sheepAmount,
            0, // Accept any amount
            sheep,
            wGasToken,
            false,
            address(this),
            block.timestamp + 300
        );
    }
    
    /**
     * @notice Force harvest rewards (emergency function)
     */
    function forceHarvestRewards() external onlyAdmin {
        uint256 beforeBalance = getTotalSheepValue();
        
        // Harvest from both proxies
        ISheepDogProxy(addressA).buySheep();
        ISheepDogProxy(addressB).buySheep();
        
        // Recover tokens from both proxies
        uint256 balanceA = ISheep(sheep).balanceOf(addressA);
        uint256 balanceB = ISheep(sheep).balanceOf(addressB);
        
        if (balanceA > 0) {
            ISheepDogProxy(addressA).recoverTokens(sheep, address(this), balanceA);
        }
        
        if (balanceB > 0) {
            ISheepDogProxy(addressB).recoverTokens(sheep, address(this), balanceB);
        }
        
        // Calculate rewards
        uint256 afterBalance = getTotalSheepValue();
        
        if (afterBalance > beforeBalance) {
            uint256 rewardAmount = afterBalance - beforeBalance;
            
            // Calculate the amount needed for user deposits
            uint256 amountNeededForDeposits = totalDeposits;
            
            // If we have excess SHEEP (rewards), send them to admin
            if (afterBalance > amountNeededForDeposits) {
                uint256 excessAmount = afterBalance - amountNeededForDeposits;
                ISheep(sheep).transfer(admin, excessAmount);
                
                // Update cumulative rewards
                cumulativeRewards += excessAmount;
                
                emit RewardHarvested(excessAmount);
            }
        }
    }
    
    /**
     * @notice Set the maximum withdrawal queue size
     * @param newMaxSize New maximum queue size
     */
    function setMaxWithdrawalQueueSize(uint256 newMaxSize) external onlyAdmin {
        require(newMaxSize >= 10 && newMaxSize <= 500, "Invalid queue size");
        maxWithdrawalQueueSize = newMaxSize;
        emit ParameterUpdated("maxWithdrawalQueueSize", newMaxSize);
    }
    
    // Allow the contract to receive ETH if needed
    receive() external payable {}
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