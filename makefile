-include .env
.PHONY: all test deploy

deploy :; forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url 127.0.0.1:8545 --broadcast --private-key $(DEFAULT_ANVIL_KEY) -vvvv