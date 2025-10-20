-include .env
.PHONY: all test deploy

deploysepolia :; forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url $(SEPOLIA_RPC) --broadcast --private-key $(PRIVATE_KEY) --verify -vvvv
deployanvil :; forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url $(ANVIL_RPC) --broadcast --private-key $(DEFAULT_ANVIL_KEY) -vvvv