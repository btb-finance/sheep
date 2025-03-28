# BTB Contracts Deployment Guide

This document provides information about the deployed BTB (Back to Basics) contracts on Base Sepolia testnet.

## Deployed Contracts

| Contract | Address |
|----------|---------|
| SHEEP Token | 0x186bDbd61A33a5bd71A357f1106C0D840Bf2279d |
| SHEEPDOG | 0x3F22d29F8f6e6668F56E8472c10b0b842B83458c |
| WOLF | 0xB75361924bcD5Ffa74Dca345797bE5652b5884B2 |
| SheepDogManager | 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 |
| SheepDogProxy A | 0x39329955015b99591e7667e7e85b508c31d839d5 |
| SheepDogProxy B | 0xbaF02f7F77Cb0462EA06a9693208a268D3AEA9dF |

## Interacting with the Contracts

### Prerequisites

1. Have ETH in your wallet on Base Sepolia for gas
2. Install Foundry: https://getfoundry.sh/

### Getting SHEEP Tokens

Before you can interact with the SheepDogManager, you need to have SHEEP tokens:

1. Get WETH on Base Sepolia (this is needed to mint SHEEP)
2. Approve the SHEEP contract to spend your WETH:
   ```
   cast send 0x4200000000000000000000000000000000000006 "approve(address,uint256)" 0x186bDbd61A33a5bd71A357f1106C0D840Bf2279d 1000000000000000000 --rpc-url base_sepolia --private-key YOUR_PRIVATE_KEY
   ```
3. Mint SHEEP tokens by calling the mintForFee function:
   ```
   cast send 0x186bDbd61A33a5bd71A357f1106C0D840Bf2279d "mintForFee(uint256)" 1000000000000000000 --rpc-url base_sepolia --private-key YOUR_PRIVATE_KEY
   ```

### Depositing SHEEP into SheepDogManager

After you have SHEEP tokens:

1. Approve the SheepDogManager to spend your SHEEP:
   ```
   cast send 0x186bDbd61A33a5bd71A357f1106C0D840Bf2279d "approve(address,uint256)" 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 1000000000000000000 --rpc-url base_sepolia --private-key YOUR_PRIVATE_KEY
   ```
2. Deposit SHEEP into the SheepDogManager:
   ```
   cast send 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "deposit(uint256)" 1000000000000000000 --rpc-url base_sepolia --private-key YOUR_PRIVATE_KEY
   ```

### Checking Your Deposits

You can check your deposits in the SheepDogManager:

```
cast call 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "userDeposits(address)" YOUR_ADDRESS --rpc-url base_sepolia
```

### Requesting Withdrawals

To request a withdrawal:

```
cast send 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "requestWithdrawal(uint256)" 1000000000000000000 --rpc-url base_sepolia --private-key YOUR_PRIVATE_KEY
```

### Other Functions

Check the total SHEEP value across both proxies:

```
cast call 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "getTotalSheepValue()" --rpc-url base_sepolia
```

Check which address is active:

```
cast call 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "activeAddress()" --rpc-url base_sepolia
```

## Admin Functions

These functions should only be called by the admin:

Rotate the active and sleeping addresses:

```
cast send 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "rotateAddresses()" --rpc-url base_sepolia --private-key ADMIN_PRIVATE_KEY
```

Process pending withdrawal requests:

```
cast send 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "processWithdrawals()" --rpc-url base_sepolia --private-key ADMIN_PRIVATE_KEY
```

Harvest rewards:

```
cast send 0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0 "harvestRewards()" --rpc-url base_sepolia --private-key ADMIN_PRIVATE_KEY
```

## Contract Verification

The contracts are deployed and can be viewed on BaseScan:

- SheepDogManager: https://sepolia.basescan.org/address/0x35dC056B5954383E3CA37A6588Ca6528d05Fc0E0
- SheepDogProxy A: https://sepolia.basescan.org/address/0x39329955015b99591e7667e7e85b508c31d839d5
- SheepDogProxy B: https://sepolia.basescan.org/address/0xbaF02f7F77Cb0462EA06a9693208a268D3AEA9dF 