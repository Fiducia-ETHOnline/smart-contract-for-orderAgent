//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {OrderContract} from "../../src/orderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract OrderContractTest is Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    address pyUSD;
    address addressController;

    address public USER = makeAddr("user");


    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig) = deployer.run();
        (pyUSD, addressController, ) = helperConfig.activeNetworkConfig();
        ERC20Mock(pyUSD).mint(USER, 100 ether);
                
    }

    function testProposeOrderUpdatesVariables() public {
        // Arrange
        uint256 amountForCompute = 10 ether;
        bytes32 promptHash = keccak256(abi.encodePacked("Test Prompt"));
        

        uint256 expectedOfferId = 1;

        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(amountForCompute, promptHash);
        vm.stopPrank();
        // Assert
        bytes32 storedPromptHash = orderContract.addressToOfferIdToPromptHash(USER, offerId);
        assertEq(storedPromptHash, promptHash);
        assertEq(offerId, expectedOfferId);
    }
}