-include .env
.PHONY: all test deploy

deploy :; forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url http://127.0.0.1:8545 