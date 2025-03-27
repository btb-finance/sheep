# SHEEPDOG Manager: Complete Implementation Plan

## I. System Architecture

### Overview
We'll create a manager contract that interfaces with the SHEEPDOG contract using two addresses in rotation. This system will handle deposits, withdrawals, reward accounting, and address rotation.

### Key Components
1. Main Manager Contract - Controls all logic and user accounting
2. Two SHEEPDOG Interaction Addresses - Rotate between active deposit and withdrawal phases

## II. Smart Contract Structure

### Main Manager Contract
1. **Storage Variables**
   - User balances and shares tracking
   - Total virtual shares across both addresses
   - Current state of each address (active, sleeping, withdrawing)
   - Withdrawal schedule and request queue
   - Total SHEEP value tracking
   - Historical reward data

2. **Access Control**
   - Owner/admin functions for emergency operations
   - User-facing functions for deposits and withdrawals
   - Automated functions for rotation and reward distribution

3. **External Contract Interfaces**
   - SHEEP token interface
   - SHEEPDOG interface
   - wGasToken interface
   - Optional: Router interface for swaps if needed

## III. User Management System

### Virtual Accounting System
1. Track proportional shares rather than raw SHEEP amounts
2. Each user gets assigned virtual shares based on deposit amount
3. Shares remain constant while underlying value changes with rewards

### User Information Storage
1. Mapping of user addresses to their share amounts
2. Mapping of user addresses to pending withdrawal requests
3. Historical deposit and withdrawal records

## IV. Deposit Handling

### Process
1. User deposits SHEEP tokens to the Manager Contract
2. Manager calculates shares based on current exchange rate
3. Manager deposits SHEEP to the currently active address
4. Manager updates user's virtual share balance

### Share Calculation
1. Initial exchange rate: 1 SHEEP = 1 share
2. After rewards accrue: 1 share = (totalSHEEP / totalShares)
3. New shares for deposit = depositAmount / currentExchangeRate

## V. Withdrawal Management

### Withdrawal Request System
1. Users submit withdrawal requests specifying amount or percentage
2. Requests are stored in a queue until next withdrawal cycle
3. System tracks total pending withdrawal amount

### Scheduled Withdrawals
1. On scheduled days, trigger dogSleep() on the active address
2. After 2-day waiting period, process all pending withdrawals
3. Calculate each user's withdrawal amount based on shares
4. Update user shares after withdrawal

## VI. Reward Distribution

### Reward Tracking
1. Regular snapshots of total SHEEP value in both addresses
2. Calculation of daily/weekly APY based on value changes
3. Transparent reporting of rewards to users

### Distribution Mechanism
1. Rewards automatically accrue through share value appreciation
2. No explicit distribution needed - value is captured when user withdraws
3. Fair distribution based on proportional share ownership

### buySheep() Management
1. Contract calls buySheep() daily through automated function
2. The 1% caller reward is either:
   - Retained by protocol to cover operational costs
   - Distributed proportionally to all users
   - Used to incentivize specific protocol behaviors

## VII. Address Rotation Mechanism

### Two-Address Cycle
1. Address A is active for deposits
2. On withdrawal day, put Address A to sleep
3. After waiting period, process withdrawals from Address A
4. Transfer remaining funds to Address B
5. Address B becomes active for deposits
6. Repeat cycle with roles reversed

### Rotation Tracking
1. Store current state of each address
2. Track last rotation timestamp
3. Schedule next rotation based on predetermined cycle

## VIII. Gas Token Management

### wGasToken Sourcing
1. Reserve a small percentage of deposits for gas costs
2. OR charge a small fee on deposits to cover gas
3. OR allow users to provide wGasToken with withdrawals

### Rent Payment
1. Calculate accumulated rent before withdrawal
2. Ensure contract has sufficient wGasToken for payment
3. Include buffer for gas price fluctuations

## IX. Security Considerations

### Access Controls
1. Multi-signature requirements for critical functions
2. Timelocks for major parameter changes
3. Emergency pause functionality

### Fund Safety
1. Maximum caps on deposits to limit risk
2. Withdrawal limits to prevent drain attacks
3. Sanity checks on all calculations

### Safeguards Against Common Vulnerabilities
1. Reentrancy protection
2. Integer overflow/underflow prevention
3. Oracle manipulation resistance
4. Front-running protection

## X. Testing Strategy

### Unit Tests
1. Test each function in isolation
2. Cover all edge cases and parameter boundaries
3. Verify correct accounting of shares and rewards

### Integration Tests
1. Test complete deposit-withdraw cycles
2. Simulate multiple users with varying deposit/withdrawal patterns
3. Verify reward calculation accuracy over time

### Simulation Testing
1. Model multiple withdrawal cycles
2. Test various market conditions and reward scenarios
3. Stress test with large user bases and extreme conditions

## XI. Deployment Strategy

### Phased Rollout
1. Alpha deployment with limited capacity and team testing
2. Beta with selected users and capped deposits
3. Full launch with gradual deposit cap increases

### Contract Verification
1. Public verification of contract code on block explorers
2. Documentation of all functions and parameters
3. Transparent explanation of fee structure and reward mechanics

## XII. Monitoring and Maintenance

### Ongoing Operations
1. Daily monitoring of address states and rotation timing
2. Regular verification of reward calculations
3. Management of wGasToken reserves

### Performance Analytics
1. Track effective APY delivered to users
2. Compare performance against direct SHEEPDOG usage
3. Monitor gas costs and optimize operations

### Emergency Response Plan
1. Define scenarios requiring intervention
2. Create action plans for each scenario
3. Test emergency procedures regularly

## XIII. User Experience Integration

### Frontend Requirements
1. Display current protocol state (active address, next withdrawal date)
2. Show user's current stake, share percentage, and estimated value
3. Provide clear withdrawal request interface with estimated returns
4. Transparently show historical performance and accrued rewards

### User Notifications
1. Alert users before withdrawal cycles
2. Notification when withdrawal requests are processed
3. Updates on significant reward events or protocol changes

This comprehensive plan provides a complete roadmap for developing your SHEEPDOG Manager system. By implementing this two-address rotation strategy with careful accounting of shares and rewards, you can create a seamless user experience despite the limitations of the original contract.

The system maintains the security benefits of SHEEPDOG (protection from WOLF) while offering more convenient deposit and withdrawal options to users, with fair and transparent reward distribution throughout.