#!/bin/bash

# Start local Anvil instance if not already running
if ! nc -z localhost 8545 2>/dev/null; then
    echo "Starting Anvil in the background..."
    anvil --chain-id 1337 &
    ANVIL_PID=$!
    echo "Anvil started with PID: $ANVIL_PID"
    
    # Give Anvil some time to start
    sleep 2
fi

# Set up environment for local deployment
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80  # First Anvil default private key

# Deploy the contracts
echo "Deploying contracts to local Anvil instance..."
forge script script/DeployFullEcosystem.s.sol:DeployFullEcosystemScript --rpc-url http://localhost:8545 --broadcast --private-key $PRIVATE_KEY -vvv

# Optional: Save the contract addresses to a file for easy reference
echo "Deployment completed. Check the logs above for contract addresses."
echo "You can copy these addresses to your .env file for interacting with them."

# Don't automatically kill Anvil, so you can interact with the deployed contracts
echo "Anvil instance is still running. Press Ctrl+C to stop it when done testing."

# If we started Anvil, make sure to kill it when the script is interrupted
if [ ! -z "$ANVIL_PID" ]; then
    trap "kill $ANVIL_PID" EXIT
fi 