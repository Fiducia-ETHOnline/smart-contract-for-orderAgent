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
    address public SELLER = makeAddr("seller");

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
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer, SELLER);
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
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer, SELLER);   
    }
    
    function testProposeOrderAnswerUpdatesState() public proposeOrderForUser {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer, SELLER);   
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
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer, SELLER);
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
        orderContract.proposeOrderAnswer(keccak256(abi.encodePacked("Test Answer")), 1, priceForOffer, SELLER);
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

    function testFinalizeOrderPaysMerchant() public orderConfirmed {
        // Arrange
        uint64 offerId = 1;
        uint256 sellerBalanceBefore = ERC20Mock(pyUSD).balanceOf(SELLER);
        uint256 expectedAmountPaid = 5 ether + orderContract.getAgentFee();
        // Act
        vm.prank(addressController);
        orderContract.finalizeOrder(offerId);   
        uint256 sellerBalanceAfter = ERC20Mock(pyUSD).balanceOf(SELLER);
        // Assert
        assertEq(sellerBalanceAfter - sellerBalanceBefore, expectedAmountPaid);
    }




    //////////////////////////////////////
    //        Getter function tests       //
    //////////////////////////////////////

    function testGetAgentFee() public view {
        // Arrange
        uint256 expectedAgentFee = 1 ether; // AGENT_FEE is set to 1 ether in the contract
        // Act
        uint256 agentFee = orderContract.getAgentFee();
        // Assert
        assertEq(agentFee, expectedAgentFee);
    }

    function testGetAgentController() public view {
        // Arrange
        address expectedController = addressController;
        // Act
        address controller = orderContract.getAgentController();
        // Assert
        assertEq(controller, expectedController);
    }
    
    function testGetOrderIDsByMerchant() public proposeOrderForUser orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act
        uint64[] memory orderIds = orderContract.getOrderIDsByMerchant(SELLER);
        // Assert
        assertEq(orderIds.length, 1);
        assertEq(orderIds[0], offerId);
    }

    //////////////////////////////////////
    //    User Order Mapping Tests       //
    //////////////////////////////////////

    function testProposeOrderUpdatesUserMappings() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        // Act
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(testPromptHash);
        vm.stopPrank();
        
        // Assert
        uint64[] memory userOrderIds = orderContract.getUserOrderIds(USER);
        assertEq(userOrderIds.length, 1);
        assertEq(userOrderIds[0], offerId);
        assertTrue(orderContract.hasUserOrder(USER, offerId));
    }

    function testGetUserOrderStatus() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(testPromptHash);
        vm.stopPrank();
        
        // Act
        OrderContract.OrderStatus status = orderContract.getUserOrderStatus(USER, offerId);
        
        // Assert
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.InProgress));
    }

    function testGetUserOrdersWithStatus() public {
        // Arrange
        bytes32 testPromptHash1 = keccak256(abi.encodePacked("Test Prompt 1"));
        bytes32 testPromptHash2 = keccak256(abi.encodePacked("Test Prompt 2"));
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute * 2);
        uint64 offerId1 = orderContract.proposeOrder(testPromptHash1);
        uint64 offerId2 = orderContract.proposeOrder(testPromptHash2);
        vm.stopPrank();
        
        // Act
        (uint64[] memory orderIds, OrderContract.OrderStatus[] memory statuses) = orderContract.getUserOrdersWithStatus(USER);
        
        // Assert
        assertEq(orderIds.length, 2);
        assertEq(statuses.length, 2);
        assertEq(orderIds[0], offerId1);
        assertEq(orderIds[1], offerId2);
        assertEq(uint8(statuses[0]), uint8(OrderContract.OrderStatus.InProgress));
        assertEq(uint8(statuses[1]), uint8(OrderContract.OrderStatus.InProgress));
    }

    function testGetUserOrderDetails() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(testPromptHash);
        vm.stopPrank();
        
        // Act
        OrderContract.Offer memory offer = orderContract.getUserOrderDetails(USER, offerId);
        
        // Assert
        assertEq(offer.buyer, USER);
        assertEq(offer.promptHash, testPromptHash);
        assertEq(uint8(offer.status), uint8(OrderContract.OrderStatus.InProgress));
    }

    function testGetUserOrdersByStatus() public proposeOrderForUser {
        // Arrange - we already have one order in InProgress from the modifier
        uint64 initialOfferId = 1;
        
        // Propose answer to move to Proposed status
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(keccak256(abi.encodePacked("Test Answer")), initialOfferId, 5 ether, SELLER);
        
        // Create another order that stays InProgress
        bytes32 testPromptHash2 = keccak256(abi.encodePacked("Test Prompt 2"));
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId2 = orderContract.proposeOrder(testPromptHash2);
        vm.stopPrank();
        
        // Act
        uint64[] memory proposedOrders = orderContract.getUserOrdersByStatus(USER, OrderContract.OrderStatus.Proposed);
        uint64[] memory inProgressOrders = orderContract.getUserOrdersByStatus(USER, OrderContract.OrderStatus.InProgress);
        
        // Assert
        assertEq(proposedOrders.length, 1);
        assertEq(proposedOrders[0], initialOfferId);
        assertEq(inProgressOrders.length, 1);
        assertEq(inProgressOrders[0], offerId2);
    }

    function testHasUserOrderReturnsFalseForNonExistentOrder() public {
        // Act & Assert
        assertFalse(orderContract.hasUserOrder(USER, 999));
    }

    function testGetUserOrderStatusRevertsForNonUserOrder() public {
        // Arrange
        address otherUser = makeAddr("otherUser");
        
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(promptHash);
        vm.stopPrank();
        
        // Act & Assert
        vm.expectRevert(OrderContract.OrderContract__userHasNoAccessToOffer.selector);
        orderContract.getUserOrderStatus(otherUser, offerId);
    }

}