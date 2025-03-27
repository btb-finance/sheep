# Sheep Staking

This repository contains the smart contracts for the Sheep Ecosystem's staking mechanism called BTB Staking. The project is built using the Foundry framework for Ethereum smart contract development.

## Overview

The Sheep Ecosystem consists of several key components:

- **SheepToken**: The main ERC20 token of the ecosystem
- **SheepDog**: Contract that protects SHEEP tokens from the Wolf
- **Wolf**: A contract that interacts with the SHEEP token
- **SheepPool**: The BTB staking implementation that allows users to stake SHEEP tokens with a two-dog rotation system

## Latest Updates
* Added improved contract testing
* Enhanced security features
* Optimized gas usage

## Repository Structure

```
sheep-staking/
├── src/
│   ├── btb/           # Contains the BTB staking implementation
│   │   └── btbstaking.sol  # The main SheepPool contract implementation
│   └── sheep/         # Contains the Sheep ecosystem contracts
│       ├── wolf.sol        # Wolf contract implementation
│       └── ...             # Other Sheep ecosystem contracts
├── test/
│   ├── BTBStaking.t.sol         # Basic tests for the BTB staking contract
│   ├── SheepPoolTest.t.sol      # Comprehensive tests for the SheepPool
│   └── SheepPoolIntegration.t.sol # Integration tests for the SheepPool
├── script/
│   ├── DeployEcosystem.s.sol     # Script to deploy the ecosystem contracts
│   └── InteractWithPool.s.sol    # Script to interact with the deployed pool
├── foundry.toml        # Foundry configuration
└── remappings.txt      # Import remappings for dependencies
```

## BTB Staking Mechanism

The BTB staking mechanism implements a unique two-dog rotation system that provides users with:

1. **Protection from the Wolf**: Funds are always being protected by one of the Dog positions
2. **Predictable Withdrawal Schedule**: The rotation happens every 2 days, providing predictable withdrawal windows
3. **Gas Efficiency**: Withdrawals are processed in batches, reducing gas costs
4. **Continuous Protection**: The rotation ensures funds are always protected

### Key Features

- Two-dog rotation system (Dog A and Dog B) that alternates between active and sleeping states
- Deposit mechanism that includes a small fee (0.5%)
- Withdrawal requests that are processed during the next rotation
- Early withdrawal option with a higher fee (2%)
- Emergency withdrawal functionality for critical situations

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/)

### Installation

1. Clone the repository
```
git clone https://github.com/yourusername/sheep-staking.git
cd sheep-staking
```

2. Install dependencies
```
forge install
```

### Building

Compile the contracts:
```
forge build
```

### Testing

Run all tests:
```
forge test
```

Run specific test file:
```
forge test --match-contract SheepPoolTest
```

Run with verbose output:
```
forge test -vvv
```

### Deployment Scripts

Deploy the ecosystem:
```
forge script script/DeployEcosystem.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

Interact with the pool:
```
forge script script/InteractWithPool.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Testing the Withdrawal Mechanism

The SheepPool includes a comprehensive locking mechanism for withdrawals:

1. Users request a withdrawal which locks their shares
2. The locked shares are processed during the next rotation cycle
3. Users receive their SHEEP tokens once processing is complete

The tests verify this functionality through:
- `testWithdrawalRequestAndLocking`: Checks that shares are properly locked
- `testRotationAndWithdrawalProcessing`: Verifies withdrawals are processed during rotation
- `testCompleteWithdrawalCycle`: Tests the full cycle from deposit to withdrawal

## Mock Contracts

For testing purposes, we use mock versions of the ecosystem contracts:
- `MockSheepToken`: A simplified version of the SHEEP token
- `MockSheepDog`: A mock implementation of the SheepDog contract
- `MockWolf`: A mock implementation of the Wolf contract
- `MockWGasToken`: A mock implementation of the wrapped gas token

## License

This project is licensed under the MIT License.
