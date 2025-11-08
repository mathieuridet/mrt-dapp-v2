-include .env

export ETH_SEPOLIA_RPC_URL
export PRIVATE_KEY
export ETHERSCAN_API_KEY

.PHONY: deploy-sepolia

deploy-sepolia:
	cd backend && forge script script/DeployAll.s.sol:DeployAll \
	  --rpc-url $$ETH_SEPOLIA_RPC_URL \
	  --private-key $$PRIVATE_KEY \
	  --broadcast \
	  --verify \
	  --etherscan-api-key $$ETHERSCAN_API_KEY