-include .env
.PHONY: all test deploy

deploy :; forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url $(SEPOLIA_RPC) --broadcast --private-key $(PRIVATE_KEY) --verify -vvvv