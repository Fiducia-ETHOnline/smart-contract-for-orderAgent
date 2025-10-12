// SPDX-License-Identifier: MIT
// SPDX-Licnse-Identifier: MIT 

pragma solidity ^0.8.18;

import {OrderContract} from "../src/OrderContract.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployOrderContract is Script {
    
    
    function run() public returns (OrderContract, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address pyUSD, address agentController, uint256 deployerKey )= helperConfig.activeNetworkConfig();
        vm.startBroadcast(deployerKey);
        OrderContract orderContract = new OrderContract(
        agentController,  pyUSD // Replace with actual pyUSD token address
        );
        vm.stopBroadcast();
        return (orderContract, helperConfig);
    }
}