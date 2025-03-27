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

/**
 * @title SheepDogManager
 * @dev Manager contract for handling SHEEPDOG staking with two-address rotation
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
    
    // User accounting
    uint256 public totalVirtualShares;       // Total shares across both addresses
    mapping(address => uint256) public userShares; // User's virtual shares
    
    // Withdrawal requests
    mapping(address => WithdrawalRequest) public withdrawalRequests;
    address[] public withdrawalQueue; // Users who have requested withdrawals
    
    // Protocol metrics
    uint256 public totalValueLocked;  // Total SHEEP value across both addresses
    uint256 public cumulativeRewards; // Total rewards accrued since inception
    uint256 public lastRewardSnapshot; // Last recorded TVL for reward calculation
    
    // Fee settings
    uint256 public gasReserveBps = 50;  // 0.5% reserved for gas payments (in basis points)
    uint256 public protocolFeeBps = 100; // 1% fee for protocol operations (in basis points)
    
    // Owner address
    address public owner;
    
    // Platform state
    bool public emergencyShutdown; // Emergency pause
    
    /* ========== STRUCTS ========== */
    
    struct WithdrawalRequest {
        uint256 shareAmount;      // Amount of shares to withdraw
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
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event WithdrawalRequested(address indexed user, uint256 shareAmount);
    event Withdrawn(address indexed user, uint256 shareAmount, uint256 sheepAmount);
    event AddressRotated(address oldActive, address newActive);
    event RewardsUpdated(uint256 oldTotalValue, uint256 newTotalValue, uint256 rewardAmount);
    event EmergencyShutdownSet(bool status);
    event ParameterUpdated(string parameter, uint256 value);
    
    /* ========== CONSTRUCTOR ========== */
    
    constructor(
        address _sheep,
        address _sheepDog,
        address _router,
        address _addressA,
        address _addressB
    ) {
        sheep = _sheep;
        sheepDog = _sheepDog;
        wGasToken = ISheep(_sheep).wGasToken();
        router = _router;
        
        addressA = _addressA;
        addressB = _addressB;
        
        // Set Address A as the initial active address
        activeAddress = addressA;
        
        // Set initial protocol parameters
        lastRotationTimestamp = block.timestamp;
        nextWithdrawalTimestamp = block.timestamp + withdrawalInterval;
        
        // Set owner
        owner = msg.sender;
    }
    
    /* ========== MODIFIERS ========== */
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
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
        
        // Calculate shares based on current exchange rate
        uint256 sharesToMint = calculateSharesToMint(amount);
        
        // Transfer SHEEP from user to this contract
        ISheep(sheep).transferFrom(msg.sender, address(this), amount);
        
        // Set approval for active SHEEPDOG address
        ISheep(sheep).approve(activeAddress, amount);
        
        // Handle gas reserve and protocol fee if enabled
        uint256 gasReserveAmount = (amount * gasReserveBps) / 10000;
        uint256 protocolFeeAmount = (amount * protocolFeeBps) / 10000;
        uint256 netDepositAmount = amount - gasReserveAmount - protocolFeeAmount;
        
        // Deposit to active SHEEPDOG address through delegatecall
        (bool success,) = activeAddress.delegatecall(
            abi.encodeWithSignature("protect(uint256)", netDepositAmount)
        );
        require(success, "Deposit failed");
        
        // Update user shares and total
        userShares[msg.sender] += sharesToMint;
        totalVirtualShares += sharesToMint;
        
        // Update total value locked
        totalValueLocked += amount;
        
        // Update address state
        addressStates[activeAddress].depositedSheep += netDepositAmount;
        
        emit Deposited(msg.sender, amount, sharesToMint);
    }
    
    /**
     * @notice Request withdrawal of shares
     * @param shareAmount Amount of shares to withdraw
     */
    function requestWithdrawal(uint256 shareAmount) external notEmergencyShutdown {
        require(shareAmount > 0, "Cannot withdraw 0");
        require(shareAmount <= userShares[msg.sender], "Not enough shares");
        
        // Add or update withdrawal request
        if (withdrawalRequests[msg.sender].shareAmount == 0) {
            withdrawalQueue.push(msg.sender);
        }
        
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            shareAmount: shareAmount,
            requestTimestamp: block.timestamp,
            processed: false
        });
        
        emit WithdrawalRequested(msg.sender, shareAmount);
    }
    
    /**
     * @notice Get estimnated SHEEP amount for shares
     * @param shareAmount Amount of shares
     * @return Estimated SHEEP amount
     */
    function estimateSheepForShares(uint256 shareAmount) public view returns (uint256) {
        if (totalVirtualShares == 0) return 0;
        return (getTotalSheepValue() * shareAmount) / totalVirtualShares;
    }
    
    /**
     * @notice Get user's claimable SHEEP amount
     * @param user User address
     * @return Claimable SHEEP amount
     */
    function getUserClaimableAmount(address user) public view returns (uint256) {
        return estimateSheepForShares(userShares[user]);
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
        
        // Call dogSleep on the active address
        (bool success,) = activeAddress.delegatecall(
            abi.encodeWithSignature("dogSleep()")
        );
        require(success, "Failed to put dog to sleep");
        
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
     * @notice Check if the sleeping address is ready for withdrawal
     * @return Whether the address is ready for withdrawal
     */
    function canCompleteRotation() public view returns (bool) {
        // Make sure at least 2 days have passed since initiating sleep
        return 
            sleepingAddress != address(0) && 
            addressStates[sleepingAddress].isSleeping &&
            block.timestamp >= addressStates[sleepingAddress].sleepTimestamp + 2 days;
    }
    
    /**
     * @notice Complete the rotation by processing withdrawals and moving funds to the other address
     */
    function completeRotation() external notEmergencyShutdown {
        require(canCompleteRotation(), "Not ready to complete rotation");
        
        // Save reference to which address is which
        address withdrawalAddress = sleepingAddress;
        address nextActiveAddress = (withdrawalAddress == addressA) ? addressB : addressA;
        
        // Take snapshot of current total value before withdrawal for reward calculation
        uint256 beforeValue = getTotalSheepValue();
        
        // Prepare wGasToken for rent payment
        uint256 rentAmount = ISheepDog(sheepDog).getCurrentRent(withdrawalAddress);
        require(IERC20(wGasToken).balanceOf(address(this)) >= rentAmount, "Not enough wGasToken");
        IERC20(wGasToken).approve(withdrawalAddress, rentAmount);
        
        // Call getSheep to withdraw funds from sleeping address
        (bool success,) = withdrawalAddress.delegatecall(
            abi.encodeWithSignature("getSheep()")
        );
        require(success, "Withdrawal failed");
        
        // Process withdrawal requests
        processWithdrawalRequests();
        
        // Calculate the remaining SHEEP balance to transfer to the next active address
        uint256 remainingSheep = ISheep(sheep).balanceOf(address(this));
        
        // Deposit remaining SHEEP to the next active address
        if (remainingSheep > 0) {
            ISheep(sheep).approve(nextActiveAddress, remainingSheep);
            (success,) = nextActiveAddress.delegatecall(
                abi.encodeWithSignature("protect(uint256)", remainingSheep)
            );
            require(success, "Redeposit failed");
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
        
        // Calculate rewards from this cycle
        uint256 afterValue = getTotalSheepValue();
        if (afterValue > beforeValue) {
            uint256 rewardAmount = afterValue - beforeValue;
            cumulativeRewards += rewardAmount;
            emit RewardsUpdated(beforeValue, afterValue, rewardAmount);
        }
        
        emit AddressRotated(withdrawalAddress, activeAddress);
    }
    
    /**
     * @notice Process all pending withdrawal requests
     */
    function processWithdrawalRequests() internal {
        uint256 queueLength = withdrawalQueue.length;
        if (queueLength == 0) return;
        
        uint256 totalWithdrawalShares = 0;
        
        // First pass: calculate total shares to withdraw
        for (uint256 i = 0; i < queueLength; i++) {
            address user = withdrawalQueue[i];
            WithdrawalRequest memory request = withdrawalRequests[user];
            
            if (!request.processed && request.shareAmount > 0) {
                totalWithdrawalShares += request.shareAmount;
            }
        }
        
        if (totalWithdrawalShares == 0) return;
        
        // Calculate SHEEP value per share
        uint256 sheepBalance = ISheep(sheep).balanceOf(address(this));
        uint256 sheepPerShare = (sheepBalance * 1e18) / totalWithdrawalShares;
        
        // Second pass: process each withdrawal
        for (uint256 i = 0; i < queueLength; i++) {
            address user = withdrawalQueue[i];
            WithdrawalRequest memory request = withdrawalRequests[user];
            
            if (!request.processed && request.shareAmount > 0) {
                // Calculate SHEEP to withdraw
                uint256 sheepToWithdraw = (request.shareAmount * sheepPerShare) / 1e18;
                
                // Transfer SHEEP to user
                if (sheepToWithdraw > 0) {
                    ISheep(sheep).transfer(user, sheepToWithdraw);
                }
                
                // Update user shares
                userShares[user] -= request.shareAmount;
                totalVirtualShares -= request.shareAmount;
                
                // Mark request as processed
                withdrawalRequests[user].processed = true;
                
                emit Withdrawn(user, request.shareAmount, sheepToWithdraw);
            }
        }
        
        // Clear the withdrawal queue
        delete withdrawalQueue;
    }
    
    /* ========== REWARD FUNCTIONS ========== */
    
    /**
     * @notice Call buySheep on the active address to realize rewards
     */
    function harvestRewards() external notEmergencyShutdown {
        uint256 beforeBalance = getTotalSheepValue();
        
        // Call buySheep on the active SHEEPDOG contract
        (bool success,) = activeAddress.delegatecall(
            abi.encodeWithSignature("buySheep()")
        );
        require(success, "Failed to harvest rewards");
        
        // Calculate new rewards
        uint256 afterBalance = getTotalSheepValue();
        uint256 rewardAmount = 0;
        
        if (afterBalance > beforeBalance) {
            rewardAmount = afterBalance - beforeBalance;
            cumulativeRewards += rewardAmount;
        }
        
        // Update the reward snapshot
        lastRewardSnapshot = afterBalance;
        
        emit RewardsUpdated(beforeBalance, afterBalance, rewardAmount);
    }
    
    /* ========== VIEW FUNCTIONS ========== */
    
    /**
     * @notice Get total SHEEP value across both addresses
     * @return Total SHEEP value
     */
    function getTotalSheepValue() public view returns (uint256) {
        uint256 aBalance = ISheepDog(sheepDog).totalSheepBalance();
        uint256 bBalance = ISheepDog(sheepDog).totalSheepBalance();
        uint256 contractBalance = ISheep(sheep).balanceOf(address(this));
        
        return aBalance + bBalance + contractBalance;
    }
    
    /**
     * @notice Calculate shares to mint for a deposit
     * @param depositAmount Amount of SHEEP being deposited
     * @return Number of shares to mint
     */
    function calculateSharesToMint(uint256 depositAmount) public view returns (uint256) {
        if (totalVirtualShares == 0 || getTotalSheepValue() == 0) {
            return depositAmount; // Initial shares 1:1 with SHEEP
        } else {
            return (depositAmount * totalVirtualShares) / getTotalSheepValue();
        }
    }
    
    /**
     * @notice Get the current exchange rate between shares and SHEEP
     * @return Exchange rate (in 1e18 precision)
     */
    function getExchangeRate() public view returns (uint256) {
        if (totalVirtualShares == 0) return 1e18; // 1:1 rate initially
        return (getTotalSheepValue() * 1e18) / totalVirtualShares;
    }
    
    /**
     * @notice Get the historical APY based on reward accrual
     * @param lookbackDays Number of days to look back
     * @return APY (in 1e18 precision)
     */
    function getHistoricalAPY(uint256 lookbackDays) public view returns (uint256) {
        // This would require storing historical values to implement properly
        // For now, return a simple estimation based on cumulative rewards
        return 0; // Placeholder
    }
    
    /* ========== ADMIN FUNCTIONS ========== */
    
    /**
     * @notice Set the withdrawal interval
     * @param newInterval New interval in seconds
     */
    function setWithdrawalInterval(uint256 newInterval) external onlyOwner {
        require(newInterval >= 1 days, "Interval too short");
        withdrawalInterval = newInterval;
        emit ParameterUpdated("withdrawalInterval", newInterval);
    }
    
    /**
     * @notice Set the gas reserve basis points
     * @param newGasReserveBps New gas reserve in basis points
     */
    function setGasReserveBps(uint256 newGasReserveBps) external onlyOwner {
        require(newGasReserveBps <= 500, "Gas reserve too high"); // Max 5%
        gasReserveBps = newGasReserveBps;
        emit ParameterUpdated("gasReserveBps", newGasReserveBps);
    }
    
    /**
     * @notice Set the protocol fee basis points
     * @param newProtocolFeeBps New protocol fee in basis points
     */
    function setProtocolFeeBps(uint256 newProtocolFeeBps) external onlyOwner {
        require(newProtocolFeeBps <= 300, "Protocol fee too high"); // Max 3%
        protocolFeeBps = newProtocolFeeBps;
        emit ParameterUpdated("protocolFeeBps", newProtocolFeeBps);
    }
    
    /**
     * @notice Toggle emergency shutdown
     * @param status New shutdown status
     */
    function setEmergencyShutdown(bool status) external onlyOwner {
        emergencyShutdown = status;
        emit EmergencyShutdownSet(status);
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
    
    /**
     * @notice Emergency withdraw tokens
     * @param token Token to withdraw
     */
    function emergencyWithdraw(address token) external onlyOwner {
        require(emergencyShutdown, "Not in emergency shutdown");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }
    
    /**
     * @notice Buy wGasToken by swapping SHEEP
     * @param sheepAmount Amount of SHEEP to swap
     */
    function buyWGasToken(uint256 sheepAmount) external onlyOwner {
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
}