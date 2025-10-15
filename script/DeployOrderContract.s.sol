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
        address[10] memory anvilAccounts = [
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            0x90F79bf6EB2c4f870365E785982E1f101E93b906,
            0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
            0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
            0x976EA74026E726554dB657fA54763abd0C3a0aa9,
            0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
            0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
            0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
        ];

        // 先 mint 给测试账户
        if (block.chainid == 31337) {
            uint256 amount = 1_000_000 * 1e18;
            for (uint i = 0; i < anvilAccounts.length; i++) {
                token.mint(anvilAccounts[i], amount);
                console.log("Minted %s to %s", amount, anvilAccounts[i]);
            }
        }
        token.transferOwnership(address(orderContract));

        vm.stopBroadcast();
        return (orderContract, helperConfig, token);
    }
}