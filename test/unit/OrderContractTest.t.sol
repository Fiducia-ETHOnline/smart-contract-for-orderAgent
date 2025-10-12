//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {OrderContract} from "../../src/OrderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract OrderContractTest is Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    address pyUSD;
    address addressController;

    uint256 constant amountForCompute = 10 ether;
    bytes32 constant promptHash = keccak256(abi.encodePacked("Test Prompt"));

    address public USER = makeAddr("user");

    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash, uint256 amountForCompute);


    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig) = deployer.run();
        (pyUSD, addressController, ) = helperConfig.activeNetworkConfig();
        ERC20Mock(pyUSD).mint(USER, 100 ether);
                
    }
     //////////////////////////////////////
    //        proposeOrder tests          //
    //////////////////////////////////////
    function testProposeOrderUpdatesVariables() public {
        

        uint256 expectedOfferId = 1;

        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(amountForCompute, promptHash);
        vm.stopPrank();
        // Assert
        bytes32 storedPromptHash = orderContract.getPromptHash(USER, offerId);
        assertEq(storedPromptHash, promptHash);
        assertEq(offerId, expectedOfferId);
    }

    function testProposeOrderEmitsEvent() public {
        // Arrange
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        // Expect
        vm.expectEmit(true, true, true, true, address(orderContract));
        emit OrderProposed(USER, 1, promptHash, amountForCompute);
        // Act
        orderContract.proposeOrder(amountForCompute, promptHash);
        vm.stopPrank();
    }


     //////////////////////////////////////
    //        Confirm Order tests        //
    //////////////////////////////////////

    modifier proposeOrderForUser() {
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        orderContract.proposeOrder(amountForCompute, promptHash);
        vm.stopPrank();
        _;
        
    }

    function testOnlyUserWithOfferCanConfirmOrder() public proposeOrderForUser {
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.userHasNoAccessToOffer.selector);
        orderContract.confirmOrder(offerId, priceForOffer);   
    
    }

    

}