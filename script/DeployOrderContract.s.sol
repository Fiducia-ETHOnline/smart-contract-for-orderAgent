// SPDX-License-Identifier: MIT
// SPDX-Licnse-Identifier: MIT 

pragma solidity ^0.8.18;

import {OrderContract} from "../src/OrderContract.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {A3AToken} from "../src/A3Atoken.sol";
import "forge-std/console.sol"; // ✅ 加上这行
contract DeployOrderContract is Script {
    
    
    function run() public returns (OrderContract, HelperConfig, A3AToken) {
        HelperConfig helperConfig = new HelperConfig();
        
        (address pyUSD, address agentController, uint256 deployerKey )= helperConfig.activeNetworkConfig();
        
        vm.startBroadcast(deployerKey);
        A3AToken token = new A3AToken();
        OrderContract orderContract = new OrderContract(
        agentController,  pyUSD, address(token) // Replace with actual pyUSD token address
        );
        if (block.chainid == 31337) {
            address[] memory test_accounts = vm.envAddress("PUBLIC_KEYS",',');
            for (uint256 i = 0; i < test_accounts.length; i++) {
                token.mint(test_accounts[i], 1000000 ether);
                
            }            
        }
        token.transferOwnership(address(orderContract));

        vm.stopBroadcast();
        return (orderContract, helperConfig, token);
    }
}