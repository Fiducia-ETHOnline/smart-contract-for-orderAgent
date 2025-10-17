// SPDX-License-Identifier: MIT


pragma solidity ^0.8.18;
import "forge-std/console.sol";
import {Script} from  "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
contract HelperConfig is Script {
    
    struct NetworkConfig {
        address pyUSD;
        address agentController;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
          pyUSD: 0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9,
          agentController: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc, // replace with actual address
          deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.pyUSD != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        ERC20Mock pyUSD = new ERC20Mock();
        pyUSD.mint(vm.envAddress("PUBLIC_KEY"), 100 ether);
        
        vm.stopBroadcast();
        return NetworkConfig({
            pyUSD: address(pyUSD),
            agentController: address(5),
            deployerKey: vm.envUint("DEFAULT_ANVIL_KEY")
        });
    
}

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }
}