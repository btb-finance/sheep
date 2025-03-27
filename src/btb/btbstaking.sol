// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Import OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interfaces for sheep ecosystem
interface ISheep {
    function transferOwnership(address newOwner) external;
    function eatSheep(address _victim, uint256 _amount, address _owner, uint256 _mintPercent) external;
    function transferFrom(address from, address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function burnSheep(uint256 balSheepHere) external;
    function owner() external view returns (address);
    function wGasToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ISheepDog {
    function protect(uint256 _amount) external;
    function dogSleep() external;
    function getSheep() external;
    function buySheep() external;
    function totalSheepBalance() external view returns (uint256);
    function getCurrentRent(address _user) external view returns (uint256);
    function sheepDogShares(address _user) external view returns (uint256);
    function wenToClaim(address _user) external view returns (uint256);
    function totalShares() external view returns (uint256);
    function totalSheep() external view returns (uint256);
}

/**
 * @title SheepPool
 * @dev A pooling contract for protecting SHEEP tokens using the SheepDog contract
 * Uses two alternating positions to ensure continuous withdrawal availability
 */
contract SheepPool is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Struct to track positions in the SheepDog contract
    struct DogPosition {
        bool isActive;          // Whether this position is accepting deposits
        uint256 sleepStartTime; // When dogSleep() was called
        uint256 sheepAmount;    // How much SHEEP is in this position
    }

    // Struct for withdrawal requests
    struct WithdrawalRequest {
        address user;           // User requesting withdrawal
        uint256 shareAmount;    // Amount of pool shares to withdraw
        uint256 sheepAmount;    // Calculated SHEEP amount at request time
        uint256 requestTime;    // When the withdrawal was requested
        bool processed;         // Whether this request has been processed
    }

    // Constants
    uint256 public constant MIN_DEPOSIT = 10 * 1e18;  // Minimum deposit amount
    uint256 public constant ROTATION_PERIOD = 2 days; // Time between position rotations
    uint256 public constant DEPOSIT_FEE_BPS = 50;     // 0.5% deposit fee in basis points (1/10000)
    uint256 public constant EARLY_WITHDRAWAL_FEE_BPS = 200; // 2% early withdrawal fee

    // State variables
    address public sheepToken;           // Address of the SHEEP token
    address public sheepDogContract;     // Address of the SheepDog contract
    address public wGasToken;            // Address of wrapped gas token for rent payments
    DogPosition public dogA;             // First position in SheepDog
    DogPosition public dogB;             // Second position in SheepDog
    uint256 public totalSheepDeposited;  // Total SHEEP tokens deposited
    uint256 public accumulatedRewards;   // Rewards from buybacks
    bool public emergencyMode;           // Emergency flag to enable direct withdrawals
    uint256 public gasTokenReserve;      // Reserve of gas tokens for rent payments
    
    // Withdrawal queue
    WithdrawalRequest[] public withdrawalRequests;
    
    // User info for tracking deposits
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public lockedShares; // Shares that are locked for withdrawal

    // Events
    event Deposited(address indexed user, uint256 sheepAmount, uint256 shareAmount);
    event WithdrawalRequested(address indexed user, uint256 shareAmount, uint256 sheepAmount);
    event Withdrawn(address indexed user, uint256 shareAmount, uint256 sheepAmount);
    event PositionsRotated(uint256 withdrawnAmount, uint256 rewardAmount);
    event EmergencyWithdrawn(address indexed user, uint256 shareAmount, uint256 sheepAmount);
    event RewardsDistributed(uint256 totalRewards);

    /**
     * @dev Constructor to initialize the SheepPool contract
     * @param _sheepToken Address of the SHEEP token
     * @param _sheepDogContract Address of the SheepDog contract
     * @param _wGasToken Address of the wrapped gas token
     */
    constructor(
        address _sheepToken,
        address _sheepDogContract,
        address _wGasToken
    ) ERC20("Protected SHEEP", "pSHEEP") {
        sheepToken = _sheepToken;
        sheepDogContract = _sheepDogContract;
        wGasToken = _wGasToken;
        
        // Initialize Dog A as active
        dogA.isActive = true;
        
        // Dog B starts in sleep mode (not active)
        dogB.isActive = false;
    }

    /**
     * @dev Initialize the two-dog rotation system
     * This should be called after the contract is deployed and funded with initial SHEEP
     * @param initialAmount Amount of SHEEP to use for initial position
     */
    function initializeRotation(uint256 initialAmount) external onlyOwner {
        require(dogB.sleepStartTime == 0, "Already initialized");
        
        // Ensure contract has enough SHEEP tokens
        require(ISheep(sheepToken).balanceOf(address(this)) >= initialAmount, "Insufficient SHEEP");
        
        // Set up Dog A with initial deposit
        ISheep(sheepToken).approve(sheepDogContract, initialAmount);
        ISheepDog(sheepDogContract).protect(initialAmount);
        dogA.sheepAmount = initialAmount;
        
        // Put Dog B to sleep immediately to start rotation cycle
        ISheepDog(sheepDogContract).dogSleep();
        dogB.sleepStartTime = block.timestamp;
        
        totalSheepDeposited = initialAmount;
    }

    /**
     * @dev Deposit SHEEP tokens to get pool shares
     * @param amount Amount of SHEEP to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount >= MIN_DEPOSIT, "Deposit too small");
        require(!emergencyMode, "Emergency mode: deposits disabled");
        
        // Calculate and take deposit fee (0.5%)
        uint256 depositFee = amount * DEPOSIT_FEE_BPS / 10000;
        uint256 depositAmountAfterFee = amount - depositFee;
        
        // Transfer SHEEP from user to this contract
        ISheep(sheepToken).transferFrom(msg.sender, address(this), amount);
        
        // Transfer deposit fee to owner (for gas tokens)
        if (depositFee > 0) {
            ISheep(sheepToken).transfer(owner(), depositFee);
            gasTokenReserve += depositFee;
        }
        
        // Calculate shares to mint
        uint256 sharesToMint;
        if (totalSupply() == 0) {
            sharesToMint = depositAmountAfterFee; // Initial 1:1 ratio
        } else {
            sharesToMint = depositAmountAfterFee * totalSupply() / totalPoolValue();
        }
        
        // Determine active dog and deposit
        DogPosition storage activeDog = dogA.isActive ? dogA : dogB;
        
        // Approve and deposit to SheepDog
        ISheep(sheepToken).approve(sheepDogContract, depositAmountAfterFee);
        ISheepDog(sheepDogContract).protect(depositAmountAfterFee);
        
        // Update accounting
        activeDog.sheepAmount += depositAmountAfterFee;
        totalSheepDeposited += depositAmountAfterFee;
        userDeposits[msg.sender] += depositAmountAfterFee;
        
        // Mint share tokens to the user
        _mint(msg.sender, sharesToMint);
        
        emit Deposited(msg.sender, depositAmountAfterFee, sharesToMint);
    }

    /**
     * @dev Request a withdrawal of pool shares
     * @param shareAmount Amount of shares to withdraw
     */
    function requestWithdrawal(uint256 shareAmount) external nonReentrant {
        require(shareAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= shareAmount, "Insufficient shares");
        require(lockedShares[msg.sender] + shareAmount <= balanceOf(msg.sender), "Shares already locked");
        
        // Calculate SHEEP amount based on current pool value
        uint256 sheepAmount = shareAmount * totalPoolValue() / totalSupply();
        
        // Lock shares so they can't be transferred
        lockedShares[msg.sender] += shareAmount;
        
        // Add withdrawal request to the queue
        withdrawalRequests.push(WithdrawalRequest({
            user: msg.sender,
            shareAmount: shareAmount,
            sheepAmount: sheepAmount,
            requestTime: block.timestamp,
            processed: false
        }));
        
        emit WithdrawalRequested(msg.sender, shareAmount, sheepAmount);
    }

    /**
     * @dev Request an early withdrawal with fee
     * @param shareAmount Amount of shares to withdraw early
     */
    function requestEarlyWithdrawal(uint256 shareAmount) external nonReentrant {
        require(shareAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= shareAmount, "Insufficient shares");
        require(!emergencyMode, "Use emergencyWithdraw in emergency mode");
        
        // Calculate equivalent SHEEP amount
        uint256 sheepAmount = shareAmount * totalPoolValue() / totalSupply();
        
        // Calculate early withdrawal fee (2%)
        uint256 feeAmount = sheepAmount * EARLY_WITHDRAWAL_FEE_BPS / 10000;
        uint256 withdrawAmount = sheepAmount - feeAmount;
        
        // Check if we have enough SHEEP available in the contract
        uint256 availableSheep = ISheep(sheepToken).balanceOf(address(this));
        require(availableSheep >= withdrawAmount, "Insufficient liquidity for early withdrawal");
        
        // Burn shares
        _burn(msg.sender, shareAmount);
        
        // Transfer SHEEP to user minus fee
        ISheep(sheepToken).transfer(msg.sender, withdrawAmount);
        
        // The fee stays in the contract for other users' benefit
        accumulatedRewards += feeAmount;
        
        emit Withdrawn(msg.sender, shareAmount, withdrawAmount);
    }

    /**
     * @dev Rotate positions between dogs
     * This should be called regularly (every 2 days) to maintain the withdrawal cycle
     */
    function rotatePositions() external nonReentrant {
        // Identify which dog is sleeping and which is active
        DogPosition storage sleepingDog = dogA.isActive ? dogB : dogA;
        DogPosition storage activeDog = dogA.isActive ? dogA : dogB;
        
        // Check if sleeping dog is ready for withdrawal
        require(block.timestamp >= sleepingDog.sleepStartTime + ROTATION_PERIOD, "Too early for rotation");
        
        // Record SHEEP balance before withdrawal
        uint256 balanceBefore = ISheep(sheepToken).balanceOf(address(this));
        
        // Calculate and pay rent
        uint256 rentDue = ISheepDog(sheepDogContract).getCurrentRent(address(this));
        require(ISheep(wGasToken).balanceOf(address(this)) >= rentDue, "Insufficient gas tokens for rent");
        
        // Approve and pay rent
        ISheep(wGasToken).approve(sheepDogContract, rentDue);
        
        // Withdraw SHEEP from sleeping dog
        ISheepDog(sheepDogContract).getSheep();
        
        // Calculate how much was withdrawn and any rewards
        uint256 balanceAfter = ISheep(sheepToken).balanceOf(address(this));
        uint256 withdrawnAmount = balanceAfter - balanceBefore;
        uint256 rewardAmount = 0;
        
        if (withdrawnAmount > sleepingDog.sheepAmount) {
            rewardAmount = withdrawnAmount - sleepingDog.sheepAmount;
            accumulatedRewards += rewardAmount;
        }
        
        // Process withdrawal requests
        processWithdrawalRequests();
        
        // Now switch roles
        // Put active dog to sleep
        ISheepDog(sheepDogContract).dogSleep();
        activeDog.sleepStartTime = block.timestamp;
        activeDog.isActive = false;
        
        // Get remaining SHEEP balance
        uint256 remainingSheep = ISheep(sheepToken).balanceOf(address(this));
        
        // Deposit remaining funds to SheepDog
        if (remainingSheep > 0) {
            ISheep(sheepToken).approve(sheepDogContract, remainingSheep);
            ISheepDog(sheepDogContract).protect(remainingSheep);
            
            // Update dog amount
            sleepingDog.sheepAmount = remainingSheep;
        } else {
            sleepingDog.sheepAmount = 0;
        }
        
        // Mark formerly sleeping dog as active
        sleepingDog.isActive = true;
        
        emit PositionsRotated(withdrawnAmount, rewardAmount);
    }

    /**
     * @dev Process pending withdrawal requests
     * Called internally by rotatePositions
     */
    function processWithdrawalRequests() internal {
        uint256 availableSheep = ISheep(sheepToken).balanceOf(address(this));
        uint256 processedIndex = 0;
        
        // Process as many requests as possible with available SHEEP
        for (uint256 i = 0; i < withdrawalRequests.length; i++) {
            WithdrawalRequest storage request = withdrawalRequests[i];
            
            if (request.processed) {
                processedIndex = i + 1;
                continue;
            }
            
            // If we have enough SHEEP to satisfy this request
            if (availableSheep >= request.sheepAmount) {
                // Unlock and burn shares
                lockedShares[request.user] -= request.shareAmount;
                _burn(request.user, request.shareAmount);
                
                // Transfer SHEEP to user
                ISheep(sheepToken).transfer(request.user, request.sheepAmount);
                
                // Update available SHEEP
                availableSheep -= request.sheepAmount;
                
                // Mark as processed
                request.processed = true;
                processedIndex = i + 1;
                
                emit Withdrawn(request.user, request.shareAmount, request.sheepAmount);
            } else {
                // Not enough SHEEP for this request, stop processing
                break;
            }
        }
        
        // Remove processed requests from the queue
        if (processedIndex > 0) {
            cleanWithdrawalQueue(processedIndex);
        }
    }

    /**
     * @dev Clean up processed withdrawal requests
     * @param upToIndex Removal boundary
     */
    function cleanWithdrawalQueue(uint256 upToIndex) internal {
        if (upToIndex >= withdrawalRequests.length) {
            // Reset the array if all requests processed
            delete withdrawalRequests;
        } else {
            // Remove processed requests
            uint256 remainingLength = withdrawalRequests.length - upToIndex;
            for (uint256 i = 0; i < remainingLength; i++) {
                withdrawalRequests[i] = withdrawalRequests[i + upToIndex];
            }
            
            // Resize the array
            for (uint256 i = 0; i < upToIndex; i++) {
                withdrawalRequests.pop();
            }
        }
    }

    /**
     * @dev Emergency withdrawal function
     * Only works when emergency mode is enabled
     * @param shareAmount Amount of shares to withdraw in emergency
     */
    function emergencyWithdraw(uint256 shareAmount) external nonReentrant {
        require(emergencyMode, "Not in emergency mode");
        require(shareAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= shareAmount, "Insufficient shares");
        
        // Calculate SHEEP amount based on current pool value and available balance
        uint256 totalShareSupply = totalSupply();
        uint256 availableSheep = ISheep(sheepToken).balanceOf(address(this));
        
        // Calculate proportional amount
        uint256 sheepAmount = shareAmount * availableSheep / totalShareSupply;
        
        // Burn shares
        _burn(msg.sender, shareAmount);
        
        // Transfer available SHEEP to user
        ISheep(sheepToken).transfer(msg.sender, sheepAmount);
        
        emit EmergencyWithdrawn(msg.sender, shareAmount, sheepAmount);
    }

    /**
     * @dev Function to deposit gas tokens for rent payments
     * @param amount Amount of gas tokens to deposit
     */
    function depositGasTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer gas tokens from user to this contract
        ISheep(wGasToken).transferFrom(msg.sender, address(this), amount);
        
        // Update gas token reserve
        gasTokenReserve += amount;
    }

    /**
     * @dev Enable or disable emergency mode
     * @param _emergencyMode New emergency mode state
     */
    function setEmergencyMode(bool _emergencyMode) external onlyOwner {
        emergencyMode = _emergencyMode;
    }

    /**
     * @dev Recover ERC20 tokens accidentally sent to contract
     * @param tokenAddress Address of token to recover
     * @param amount Amount to recover
     */
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        // Cannot recover SHEEP or pSHEEP tokens
        require(tokenAddress != sheepToken, "Cannot recover SHEEP tokens");
        require(tokenAddress != address(this), "Cannot recover pool share tokens");
        
        ISheep(tokenAddress).transfer(owner(), amount);
    }

    /**
     * @dev Calculate total value of the pool in SHEEP tokens
     */
    function totalPoolValue() public view returns (uint256) {
        // Sum of both positions plus any SHEEP in this contract
        return dogA.sheepAmount + dogB.sheepAmount + ISheep(sheepToken).balanceOf(address(this));
    }

    /**
     * @dev Calculate a user's share of the pool in SHEEP tokens
     * @param user Address of the user
     */
    function userPoolValue(address user) external view returns (uint256) {
        uint256 userShares = balanceOf(user);
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) return 0;
        
        return userShares * totalPoolValue() / totalShares;
    }

    /**
     * @dev Get detailed metrics for a user
     * @param user Address of the user
     * @return depositedAmount Original amount deposited
     * @return currentValue Current value in SHEEP
     * @return rewardAmount Estimated reward amount
     * @return rewardPercentage Estimated reward percentage (in basis points)
     */
    function getUserMetrics(address user) external view returns (
        uint256 depositedAmount,
        uint256 currentValue,
        uint256 rewardAmount,
        uint256 rewardPercentage
    ) {
        depositedAmount = userDeposits[user];
        
        uint256 userShares = balanceOf(user);
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) {
            return (depositedAmount, 0, 0, 0);
        }
        
        currentValue = userShares * totalPoolValue() / totalShares;
        
        if (currentValue > depositedAmount) {
            rewardAmount = currentValue - depositedAmount;
            rewardPercentage = rewardAmount * 10000 / depositedAmount; // In basis points
        } else {
            rewardAmount = 0;
            rewardPercentage = 0;
        }
    }

    /**
     * @dev Get information about pending withdrawal requests
     * @return total Total number of pending requests
     * @return totalSheepAmount Total SHEEP amount requested
     */
    function getPendingWithdrawals() external view returns (
        uint256 total,
        uint256 totalSheepAmount
    ) {
        total = 0;
        totalSheepAmount = 0;
        
        for (uint256 i = 0; i < withdrawalRequests.length; i++) {
            if (!withdrawalRequests[i].processed) {
                total++;
                totalSheepAmount += withdrawalRequests[i].sheepAmount;
            }
        }
    }

    /**
     * @dev Check if a position rotation is ready
     * @return isReady Whether rotation is ready
     * @return nextRotationTime Timestamp when next rotation is possible
     */
    function isRotationReady() external view returns (
        bool isReady,
        uint256 nextRotationTime
    ) {
        // Identify which dog is sleeping
        DogPosition storage sleepingDog = dogA.isActive ? dogB : dogA;
        
        nextRotationTime = sleepingDog.sleepStartTime + ROTATION_PERIOD;
        isReady = block.timestamp >= nextRotationTime;
    }

    /**
     * @dev Override ERC20 transfer to handle locked shares
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(amount <= balanceOf(msg.sender) - lockedShares[msg.sender], "Shares locked for withdrawal");
        return super.transfer(to, amount);
    }

    /**
     * @dev Override ERC20 transferFrom to handle locked shares
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(amount <= balanceOf(from) - lockedShares[from], "Shares locked for withdrawal");
        return super.transferFrom(from, to, amount);
    }
}