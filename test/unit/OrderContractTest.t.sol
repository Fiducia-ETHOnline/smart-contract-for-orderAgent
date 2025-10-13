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

    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);


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
        uint64 offerId = orderContract.proposeOrder(promptHash);
        vm.stopPrank();
        // Assert
        bytes32 storedPromptHash = orderContract.getPromptHash(offerId);
        assertEq(storedPromptHash, promptHash);
        assertEq(offerId, expectedOfferId);
    }

    function testProposeOrderEmitsEvent() public {
        // Arrange
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        // Expect
        vm.expectEmit(true, true, true, false, address(orderContract));
        emit OrderProposed(USER, 1, promptHash);
        // Act
        orderContract.proposeOrder(promptHash);
        vm.stopPrank();
    }


     //////////////////////////////////////
    //        Confirm Order tests        //
    //////////////////////////////////////

    modifier proposeOrderForUser() {
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        orderContract.proposeOrder(promptHash);
        vm.stopPrank();
        _;
        
    }

    modifier orderProposedAnsweredByAgent(uint64 offerId, bytes32 answerHash) {
        uint256 priceForOffer = 5 ether;
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);
        _;
    }

    function testOnlyUserWithOfferCanConfirmOrder() public proposeOrderForUser orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__userHasNoAccessToOffer.selector);
        orderContract.confirmOrder(offerId);   
    
    }

    function testConfirmOrderUpdatesAmountPaidAndTimeStamp() public proposeOrderForUser orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        uint256 expectedAmountPaid = priceForOffer + orderContract.getAgentFee(); // AGENT_FEE i 1 ether
        uint256 expectedTimeStamp = block.timestamp;
        // Act
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), expectedAmountPaid);
        orderContract.confirmOrder(offerId);
        vm.stopPrank();
        // Assert
        uint256 amountPaid = orderContract.getAmountPaid(offerId);
        assertEq(amountPaid, expectedAmountPaid);
        assertEq(orderContract.getOfferIdToTimestamp(offerId), expectedTimeStamp);
    }
    
    function testConfirmOrderEmitsEvent() public proposeOrderForUser orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))){
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        uint256 expectedAmountPaid = priceForOffer + orderContract.getAgentFee(); // AGENT_FEE is 1 ether
        
       
        // Act
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), expectedAmountPaid);
        vm.expectEmit(true, true, true, false, address(orderContract));
        emit OrderConfirmed(USER, offerId, expectedAmountPaid);
        orderContract.confirmOrder(offerId);
        vm.stopPrank();

    
    }

    function testConfirmOrderRevertsIfOrderNotProposed() public proposeOrderForUser {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(OrderContract.OrderContract__OrderCannotBeConfirmedInCurrentState.selector);
        orderContract.confirmOrder(offerId);
    }
     //////////////////////////////////////
    //        proposeOrderAnswer tests    //
    //////////////////////////////////////

    function testOnlyControllerCanProposeAnswer() public proposeOrderForUser {
        uint256 priceForOffer = 5 ether;
        // Arrange
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__notAgentController.selector);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);   
    }
    
    function testProposeOrderAnswerUpdatesState() public proposeOrderForUser {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);   
        // Assert
        bytes32 storedAnswerHash = orderContract.getAnswerHash(offerId);
        assertEq(storedAnswerHash, answerHash);
        OrderContract.OrderStatus status = orderContract.getOfferStatus(offerId);
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.Proposed));
    }

    function testProposeOrderAnswerRevertsIfNotInProgress() public {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act / Assert
        vm.prank(addressController);
        vm.expectRevert(OrderContract.OrderContract__CannotProposeOrderAnswerInCurrentState.selector);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);
    }

    
     //////////////////////////////////////
    //        finalizeOrder tests   //
    //////////////////////////////////////

    modifier orderConfirmed() {
        uint256 priceForOffer = 5 ether;
        vm.startPrank(USER);
        orderContract.proposeOrder(promptHash);
        vm.stopPrank();
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(keccak256(abi.encodePacked("Test Answer")), 1, priceForOffer);
        uint256 expectedAmountPaid = 5 ether + orderContract.getAgentFee();
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), expectedAmountPaid);
        orderContract.confirmOrder(1);
        vm.stopPrank();
        _;
    }
     
    function testFinalizeOrderCanOnlyBeCalledWhenStateIsConfirmed() public {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(addressController);
        vm.expectRevert(OrderContract.OrderContract__OrderCannotBeFinalizedInCurrentState.selector);
        orderContract.finalizeOrder(offerId);   
    }

    function testFinalizeOrderUpdatesState() public orderConfirmed {
        // Arrange
        uint64 offerId = 1;
        // Act
        vm.prank(addressController);
        orderContract.finalizeOrder(offerId);   
        // Assert
        OrderContract.OrderStatus status = orderContract.getOfferStatus(offerId);
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.Completed));
    }

    function testFinalizeOrderPaysController() public orderConfirmed {
        // Arrange
        uint64 offerId = 1;
        uint256 controllerBalanceBefore = ERC20Mock(pyUSD).balanceOf(addressController);
        uint256 expectedAmountPaid = 5 ether + orderContract.getAgentFee();
        // Act
        vm.prank(addressController);
        orderContract.finalizeOrder(offerId);   
        uint256 controllerBalanceAfter = ERC20Mock(pyUSD).balanceOf(addressController);
        // Assert
        assertEq(controllerBalanceAfter - controllerBalanceBefore, expectedAmountPaid);
    }


}
