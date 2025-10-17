// SPDX-License-Identifier: MIT


pragma solidity ^0.8.18;
import "forge-std/console.sol";
import {Script} from  "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
<<<<<<< HEAD
contract PyUSDMock is ERC20Mock {
    constructor() ERC20Mock() {
        uint256 mintAmount = 1_000_000 ether;

        address[10] memory accounts = [
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

        for (uint256 i = 0; i < accounts.length; i++) {
            _mint(accounts[i], mintAmount);
        }
    }
}
=======

>>>>>>> origin/main
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
<<<<<<< HEAD
        PyUSDMock pyUSD = new PyUSDMock();
        console.log("pyUSD deployed at:", address(pyUSD));
        vm.stopBroadcast();
        return NetworkConfig({
            pyUSD: address(pyUSD),
            agentController: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
            deployerKey: vm.envUint("PRIVATE_KEY")
=======
        ERC20Mock pyUSD = new ERC20Mock();
        pyUSD.mint(vm.envAddress("PUBLIC_KEY"), 100 ether);
        
        vm.stopBroadcast();
        return NetworkConfig({
            pyUSD: address(pyUSD),
            agentController: address(5),
            deployerKey: vm.envUint("DEFAULT_ANVIL_KEY")
>>>>>>> origin/main
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