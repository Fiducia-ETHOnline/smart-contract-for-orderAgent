// SPDX-License-Identifier: MIT
// SPDX-Licnse-Identifier: MIT 

pragma solidity ^0.8.18;

import {OrderContract} from "../src/OrderContract.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {A3AToken} from "../src/A3Atoken.sol";
import {MerchantNft} from "../src/MerchantNft.sol";
contract DeployOrderContract is Script {
    
    
    function run() public returns (OrderContract, HelperConfig, A3AToken, MerchantNft) {
        HelperConfig helperConfig = new HelperConfig();
        
        (address pyUSD, address agentController, uint256 deployerKey, address owner)= helperConfig.activeNetworkConfig();
        
        vm.startBroadcast(deployerKey);
        A3AToken token = new A3AToken();
        MerchantNft merchantNft = new MerchantNft();
        OrderContract orderContract = new OrderContract(
        agentController,  pyUSD, address(token), owner // Replace with actual pyUSD token address
        );
        if (block.chainid == 31337) {
            merchantNft.mintNft(1);
            token.mint(vm.envAddress("PUBLIC_KEY"), 1000000 ether);
            
        }
        token.transferOwnership(address(orderContract));

        
        
        vm.stopBroadcast();
        return (orderContract, helperConfig, token, merchantNft);
    }
}