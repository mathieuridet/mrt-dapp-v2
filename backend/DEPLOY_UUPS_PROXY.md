# Testing UUPS Proxy on Anvil or Sepolia

## Quick Test (Forge Test)

Run the test locally:
```bash
cd backend
forge test --match-contract "UpgradesTest" -vvv
```

## Testing on Anvil (Local Network)

### 1. Start Anvil
```bash
anvil
anvil --fork-url $ETH_SEPOLIA_RPC_URL --chain-id 11155111
```

### 2. Deploy Script
```bash
# Set your private key (for anvil, use the default account)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Run the script
forge script script/MRToken.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast -vvvv
forge script script/DeployAll.s.sol:DeployAll --rpc-url http://127.0.0.1:8545 --broadcast -vvvv
```

### 3. Store proxy address
```bash
export PROXY_ADDRESS=0xa513e6e4b8f2a923d98304ec87f64353c4d5c853
```

### 4. Upgrade Script
```bash
forge script script/MRToken.s.sol:UpgradeScript --rpc-url http://localhost:8545 --broadcast -vvvv
```

# Interact with proxy
```bash
cast call 0xfcc25e6d7ab3f9de86a32ddaab6d707ab5ce5a3c "rewardRate()" --rpc-url http://127.0.0.1:8545
```

## Testing on Sepolia (Testnet)

### 1. Set up environment
```bash
# Set your private key (DO NOT commit this!)
export PRIVATE_KEY=your_private_key_here

# Get Sepolia RPC URL (e.g., from Alchemy, Infura)
export SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_API_KEY
```

### 2. Deploy and Upgrade
```bash
forge script script/poc-uups-proxy/DeployAndUpgrade.s.sol:DeployAndUpgradeScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

## What the Script Does

1. **Deploys ContractA** as the implementation
2. **Deploys UUPSProxy** with ContractA and initializes it
3. **Verifies** `myNumber()` returns `1` (from ContractA)
4. **Deploys ContractB** as the new implementation
5. **Upgrades** the proxy to ContractB
6. **Verifies**:
   - Proxy address stays the same ✅
   - Implementation address changes ✅
   - `myNumber()` now returns `2` (from ContractB) ✅

## Manual Verification

After deployment, you can verify:

```solidity
// Get proxy address from script output
address proxy = 0x...;

// Check implementation
ERC1967Utils.getImplementation(proxy); // Should show ContractB address

// Call functions
ContractB(proxy).myNumber(); // Should return 2
ContractB(proxy).owner(); // Should return deployer address
```

## Key Points

- ✅ **Proxy address never changes** - this is the contract users interact with
- ✅ **Implementation address changes** - this is what gets upgraded
- ✅ **Storage persists** - any state variables in ContractA remain after upgrade
- ✅ **Only owner can upgrade** - `_authorizeUpgrade` is protected by `onlyOwner`

## Troubleshooting

### "Sender doesn't have enough funds"
Make sure your account has enough ETH for gas fees.

### "Initialization failed"
The proxy must be initialized during deployment. Check that `initData` is correct.

### "Ownable: caller is not the owner"
Make sure you're calling `upgradeToAndCall` from the owner address.

