//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {OrderContract} from "../../src/OrderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {A3AToken} from "../../src/A3Atoken.sol";

contract OrderContractTest is Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    address pyUSD;
    address addressController;
    A3AToken a3aToken;

    uint256 constant amountForCompute = 10 ether;
    bytes32 constant promptHash = keccak256(abi.encodePacked("Test Prompt"));

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    address public SELLER = makeAddr("seller");

    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);


    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig, a3aToken) = deployer.run();
        (pyUSD, addressController, ) = helperConfig.activeNetworkConfig();
        ERC20Mock(pyUSD).mint(USER, 100 ether);
        ERC20Mock(pyUSD).mint(USER2, 100 ether);

        // approve the orderContract to spend USERs A3A tokens so no need to approve every time in tests
        vm.prank(USER);
        a3aToken.approve(address(orderContract), type(uint256).max);
        // buy A3A tokens for USER so tests work
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), 10e6);
        orderContract.buyA3AToken(10e6);
        vm.stopPrank();
        

                
    }
      //////////////////////////////////////
    //        Buy A3A tests               //
    //////////////////////////////////////
  
    function testBuyA3AToken() public {
        
        // Arrange
        uint256 amountToBuy = 10e6;
        uint256 expectedBalanceOfA3A = 1000 ether;
        // Act
        vm.startPrank(USER2);
        ERC20Mock(pyUSD).approve(address(orderContract), amountToBuy);
        orderContract.buyA3AToken(amountToBuy);
        vm.stopPrank();
        // Assert
        uint256 userBalanceAfter = a3aToken.balanceOf(USER2);
        assertEq(userBalanceAfter, expectedBalanceOfA3A);

    }
     //////////////////////////////////////
    //        proposeOrder tests          //
    //////////////////////////////////////

    function testOnlyUserWithA3ABalanceCanProposeOrder() public {
        // Arrange
        // Act / Assert
        vm.prank(USER2);
        a3aToken.approve(address(orderContract), 10e6);
        vm.prank(addressController);
        vm.expectRevert();
        orderContract.proposeOrder(promptHash, USER2);   
    
    }

    function testProposeOrderUpdatesVariables() public {
        

        uint256 expectedOfferId = 1;

        vm.startPrank(addressController);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        uint64 offerId = orderContract.proposeOrder(promptHash, USER);
        vm.stopPrank();
        // Assert
        bytes32 storedPromptHash = orderContract.getPromptHash(offerId);
        assertEq(storedPromptHash, promptHash);
        assertEq(offerId, expectedOfferId);
    }

    function testProposeOrderEmitsEvent() public {
        // Arrange
        
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        // Expect
        vm.expectEmit(true, true, true, false, address(orderContract));
        emit OrderProposed(USER, 1, promptHash);
        // Act
        vm.startPrank(addressController);
        orderContract.proposeOrder(promptHash, USER);
        vm.stopPrank();
    }


     //////////////////////////////////////
    //        Confirm Order tests        //
    //////////////////////////////////////

    modifier proposeOrderForUser() {
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        vm.startPrank(addressController);
        orderContract.proposeOrder(promptHash, USER);
        vm.stopPrank();
        _;
        
    }

    modifier orderProposedAnsweredByAgent(uint64 offerId, bytes32 answerHash) {
        uint256 priceForOffer = 5 ether;
        vm.prank(SELLER);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);
        _;
    }

    modifier merchantSetForOrder(uint64 offerId, address seller) {
        vm.prank(addressController);
        orderContract.setSellerForOrder(offerId, seller);
        _;
    }

    function testOnlyUserWithOfferCanConfirmOrder() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__userHasNoAccessToOffer.selector);
        orderContract.confirmOrder(offerId);   
    
    }

    function testConfirmOrderUpdatesAmountPaidAndTimeStamp() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
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
    
    function testConfirmOrderEmitsEvent() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))){
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

    function testOnlySellerCanProposeAnswer() public proposeOrderForUser {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__MerchantHasNoAccessToOffer.selector);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);  
    }
    
    function testProposeOrderAnswerUpdatesState() public proposeOrderForUser merchantSetForOrder(1, SELLER) {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act
        vm.prank(SELLER);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);   
        // Assert
        bytes32 storedAnswerHash = orderContract.getAnswerHash(offerId);
        assertEq(storedAnswerHash, answerHash);
        OrderContract.OrderStatus status = orderContract.getOfferStatus(offerId);
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.Proposed));
    }

    function testProposeOrderAnswerRevertsIfNotInProgress() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        bytes32 answerHash = keccak256(abi.encodePacked("Test Answer"));
        // Act / Assert
        vm.prank(SELLER);
        vm.expectRevert(OrderContract.OrderContract__CannotProposeOrderAnswerInCurrentState.selector);
        orderContract.proposeOrderAnswer(answerHash, offerId, priceForOffer);
    }

    
     //////////////////////////////////////
    //        finalizeOrder tests   //
    //////////////////////////////////////

    modifier orderConfirmed() {
        uint256 priceForOffer = 5 ether;
        vm.startPrank(addressController);
        orderContract.proposeOrder(promptHash, USER);
        vm.stopPrank();
        vm.prank(addressController);
        orderContract.setSellerForOrder(1, SELLER);
        vm.prank(SELLER);
        orderContract.proposeOrderAnswer(keccak256(abi.encodePacked("Test Answer")), 1, priceForOffer);
        uint256 expectedAmountPaid = 5 ether + orderContract.getAgentFee();
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), expectedAmountPaid);
        orderContract.confirmOrder(1);
        vm.stopPrank();
        _;
    }
     
    function testFinalizeOrderCanOnlyBeCalledWhenStateIsConfirmed() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(SELLER);
        vm.expectRevert(OrderContract.OrderContract__OrderCannotBeFinalizedInCurrentState.selector);
        orderContract.finalizeOrder(offerId);   
    }

    function testFinalizeOrderUpdatesState() public orderConfirmed {
        // Arrange
        uint64 offerId = 1;
        // Act
        vm.prank(SELLER);
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
        vm.prank(SELLER);
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
        uint256 expectedAgentFee = 1e6; // AGENT_FEE is set to 1 ether in the contract
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
    
    function testGetOrderIDsByMerchant() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act
        uint64[] memory orderIds = orderContract.getOrderIDsByMerchant(SELLER);
        // Assert
        assertEq(orderIds.length, 1);
        assertEq(orderIds[0], offerId);
    }

    function testGetMerchantOrderDetailsRevertsIfNotMerchant() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(OrderContract.OrderContract__NotOrderByMerchanProvided.selector);
        orderContract.getMerchantOrderDetails(USER, offerId);
    }

    function testGetMerchantOrderDetails() public proposeOrderForUser merchantSetForOrder(1, SELLER) orderProposedAnsweredByAgent(1, keccak256(abi.encodePacked("Test Answer"))) {
        // Arrange
        uint64 offerId = 1;
        // Act
        OrderContract.Offer memory offer = orderContract.getMerchantOrderDetails(SELLER, offerId);
        // Assert
        assertEq(offer.buyer, USER);
        assertEq(offer.seller, SELLER);
        assertEq(uint8(offer.status), uint8(OrderContract.OrderStatus.Proposed));
    }

    //////////////////////////////////////
    //    User Order Mapping Tests       //
    //////////////////////////////////////

    function testProposeOrderUpdatesUserMappings() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        // Act
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(testPromptHash, USER);
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
        
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(testPromptHash, USER);
        vm.stopPrank();
        
        // Act
        OrderContract.OrderStatus status = orderContract.getUserOrderStatus(USER, offerId);
        
        // Assert
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.InProgress));
    }

    

    function testGetUserOrderDetails() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(testPromptHash, USER);
        vm.stopPrank();
        
        // Act
        OrderContract.Offer memory offer = orderContract.getUserOrderDetails(USER, offerId);
        
        // Assert
        assertEq(offer.buyer, USER);
        assertEq(offer.promptHash, testPromptHash);
        assertEq(uint8(offer.status), uint8(OrderContract.OrderStatus.InProgress));
    }

  

    function testHasUserOrderReturnsFalseForNonExistentOrder() public view {
        // Act & Assert
        assertFalse(orderContract.hasUserOrder(USER, 999));
    }

    function testGetUserOrderStatusRevertsForNonUserOrder() public {
        // Arrange
        address otherUser = makeAddr("otherUser");
        
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), amountForCompute);
        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(promptHash, USER);
        vm.stopPrank();
        
        // Act & Assert
        vm.expectRevert(OrderContract.OrderContract__userHasNoAccessToOffer.selector);
        orderContract.getUserOrderStatus(otherUser, offerId);
    }

    function testUserGetsMintedBalance() public view {
        // Arrange
        uint256 expectedBalance = 1000000 ether; // 10e6 pyUSD buys 100 A3A tokens
        
        // Act
        uint256 userBalance = a3aToken.balanceOf(vm.envAddress("PUBLIC_KEY"));
        
        // Assert
        assertEq(userBalance, expectedBalance);
    }
    
    function testUserGetsMintedPyUsd() public view {
        // Arrange
        uint256 expectedBalance = 100 ether; // Anvil setup mints 100 pyUSD to PUBLIC_KEY
        
        // Act
        uint256 userBalance = ERC20Mock(pyUSD).balanceOf(vm.envAddress("PUBLIC_KEY"));
        
        // Assert
        assertEq(userBalance, expectedBalance);
    }

}