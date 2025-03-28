# Sheep Staking Deployment Guide

This guide provides step-by-step instructions on how to deploy and verify the Sheep Staking contracts on Base Sepolia.

## Prerequisites

1. Install Foundry: https://getfoundry.sh/
2. Have ETH in your wallet on Base Sepolia for gas
3. Have a BaseScan API key for verification

## Step 1: Set Up Environment Variables

Create a `.env` file in the project root:

```
private_key=YOUR_PRIVATE_KEY_HERE
basescanapi_key=YOUR_BASESCAN_API_KEY_HERE
```

Replace `YOUR_PRIVATE_KEY_HERE` with your wallet's private key and `YOUR_BASESCAN_API_KEY_HERE` with your BaseScan API key.

## Step 2: Deploy Contracts

Run the following command to deploy all contracts:

```bash
forge script script/DeployVerify.s.sol:DeployScript --rpc-url https://sepolia.base.org --broadcast --verify
```

This will:
1. Deploy the SHEEP token
2. Deploy the SHEEPDOG contract
3. Deploy the WOLF contract
4. Configure the contracts
5. Save the contract addresses to files for verification

## Step 3: Verify Contracts

After deployment, verify the contracts on BaseScan:

```bash
forge script script/DeployVerify.s.sol:VerifyScript --rpc-url https://sepolia.base.org
```

Alternatively, you can manually run the verification commands that will be printed after deployment.

## Deployment Details

The deployment script will:

- Deploy the SHEEP token with WETH and POL addresses
- Deploy the SHEEPDOG contract with the SHEEP token and router addresses
- Deploy the WOLF contract with the SHEEP token, SHEEPDOG, and market addresses
- Set the wolf address in the SHEEP token
- Start the SHEEP token sale
- Take SHEEP out of pasture

## Contract Addresses

After deployment, the contract addresses will be saved to the following files:
- `.sheep_address`: The SHEEP token contract address
- `.sheepdog_address`: The SHEEPDOG contract address
- `.wolf_address`: The WOLF contract address

## Troubleshooting

- If the deployment fails with "out of gas" errors, increase the gas limit
- If verification fails, check that your BaseScan API key is correct
- If you need to redeploy, simply run the deployment command again 