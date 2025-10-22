//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {OrderContract} from "../../src/OrderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {A3AToken} from "../../src/A3Atoken.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerchantNft} from "../../src/MerchantNft.sol";

contract OrderContractTest is Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    address pyUSD;
    address addressController;
    A3AToken a3aToken;
    address owner;
    MerchantNft merchantNft;

    
    bytes32 constant PROMPT_HASH = keccak256(abi.encodePacked("Test Prompt"));
    uint256 constant DEFAULT_APPROVE_AMOUNT = 1000 ether;
    uint256 constant DEFAULT_BUY_AMOUNT = 1000e6;
    uint256 constant DEFAULT_MINT_AMOUNT = 1000000 ether;
    bytes32 constant TEST_ANSWER_HASH = keccak256(abi.encodePacked("Test Answer"));
    

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    address public SELLER = makeAddr("seller");

    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);


    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig, a3aToken, merchantNft) = deployer.run();
        (pyUSD, addressController,,owner) = helperConfig.activeNetworkConfig();
        ERC20Mock(pyUSD).mint(USER, DEFAULT_MINT_AMOUNT);
        ERC20Mock(pyUSD).mint(USER2, DEFAULT_MINT_AMOUNT);

        // approve the orderContract to spend USERs A3A tokens so no need to approve every time in tests
        vm.prank(USER);
        a3aToken.approve(address(orderContract), type(uint256).max);
        // buy A3A tokens for USER so tests work
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
        orderContract.buyA3AToken(DEFAULT_BUY_AMOUNT);
        vm.stopPrank();
        

                
    }
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier proposeOrderForUser() {
        vm.startPrank(addressController);
        orderContract.proposeOrder(PROMPT_HASH, USER);
        vm.stopPrank();
        _;
        
    }

    modifier orderProposedAnsweredByAgent() {
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(TEST_ANSWER_HASH, offerId, priceForOffer, SELLER);
        _;
    }


    /*//////////////////////////////////////////////////////////////
                             BUY A3A TESTS
    //////////////////////////////////////////////////////////////*/
    function testBuyA3AToken() public {
        
        // Arrange
        uint256 amountToBuy = 10e6;
        uint256 expectedBalanceOfA3A = 1000 ether;
        // Act
        vm.startPrank(USER2);
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_BUY_AMOUNT);
        orderContract.buyA3AToken(amountToBuy);
        vm.stopPrank();
        // Assert
        uint256 userBalanceAfter = a3aToken.balanceOf(USER2);
        assertEq(userBalanceAfter, expectedBalanceOfA3A);

    }


    /*//////////////////////////////////////////////////////////////
                          PROPOSE ORDER TESTS
    //////////////////////////////////////////////////////////////*/
    function testOnlyUserWithA3ABalanceCanProposeOrder() public {
        // Arrange
        // Act / Assert
        vm.prank(USER2);
        a3aToken.approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
        vm.prank(addressController);
        vm.expectRevert();
        orderContract.proposeOrder(PROMPT_HASH, USER2);   
    
    }

    function testProposeOrderUpdatesVariables() public {
        

        uint256 expectedOfferId = 1;

        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(PROMPT_HASH, USER);
        vm.stopPrank();
        // Assert
        bytes32 storedPromptHash = orderContract.getPromptHash(offerId);
        assertEq(storedPromptHash, PROMPT_HASH);
        assertEq(offerId, expectedOfferId);
    }

    function testProposeOrderEmitsEvent() public {
        // Expect
        vm.expectEmit(true, true, true, false, address(orderContract));
        emit OrderProposed(USER, 1, PROMPT_HASH);
        // Act
        vm.startPrank(addressController);
        orderContract.proposeOrder(PROMPT_HASH, USER);
        vm.stopPrank();
    }


    /*//////////////////////////////////////////////////////////////
                          CONFIRM ORDER TESTS
    //////////////////////////////////////////////////////////////*/
    function testOnlyUserWithOfferCanConfirmOrder() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__userHasNoAccessToOffer.selector);
        orderContract.confirmOrder(offerId);   
    
    }

    function testConfirmOrderUpdatesAmountPaidAndTimeStamp() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        uint256 expectedAmountPaid = priceForOffer; 
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
    
    function testConfirmOrderEmitsEvent() public proposeOrderForUser orderProposedAnsweredByAgent{
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        uint256 expectedAmountPaid = priceForOffer;
        
       
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

    function testConfirmOrderBurnsA3ATokens() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        uint256 priceForOffer = 5 ether;
        uint256 userA3ABalanceBefore = a3aToken.balanceOf(USER);
        uint256 expectedA3ABurned = 100 ether;
        // Act
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), priceForOffer);
        orderContract.confirmOrder(offerId);
        vm.stopPrank();
        uint256 userA3ABalanceAfter = a3aToken.balanceOf(USER);
        // Assert
        assertEq(userA3ABalanceBefore - userA3ABalanceAfter, expectedA3ABurned);
    }


    /*//////////////////////////////////////////////////////////////
                       PROPOSE ORDER ANSWER TESTS
    //////////////////////////////////////////////////////////////*/
    function testOnlyControllerCanProposeAnswer() public proposeOrderForUser {
        uint256 priceForOffer = 5 ether;
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(address(0x123));
        vm.expectRevert(OrderContract.OrderContract__notAgentController.selector);
        orderContract.proposeOrderAnswer(TEST_ANSWER_HASH, offerId, priceForOffer, SELLER);   
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
        // Act / Assert
        vm.prank(addressController);
        vm.expectRevert(OrderContract.OrderContract__CannotProposeOrderAnswerInCurrentState.selector);
        orderContract.proposeOrderAnswer(TEST_ANSWER_HASH, offerId, priceForOffer, SELLER);
    }

    
    /*//////////////////////////////////////////////////////////////
                          FINALIZE ORDER TESTS
    //////////////////////////////////////////////////////////////*/
    modifier orderConfirmed() {
        uint256 priceForOffer = 5 ether;
        uint64 offerId = 1;
        vm.startPrank(addressController);
        orderContract.proposeOrder(PROMPT_HASH, USER);
        vm.stopPrank();
        vm.prank(addressController);
        orderContract.proposeOrderAnswer(TEST_ANSWER_HASH, offerId, priceForOffer, SELLER);
        uint256 expectedAmountPaid = 5 ether + orderContract.getAgentFee();
        vm.startPrank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), expectedAmountPaid);
        orderContract.confirmOrder(offerId);
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
        uint256 expectedAmountPaid = 5 ether;
        // Act
        vm.prank(addressController);
        orderContract.finalizeOrder(offerId);   
        uint256 sellerBalanceAfter = ERC20Mock(pyUSD).balanceOf(SELLER);
        // Assert
        assertEq(sellerBalanceAfter - sellerBalanceBefore, expectedAmountPaid);
    }




    /*//////////////////////////////////////////////////////////////
                         GETTER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
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
    
    function testGetOrderIDsByMerchant() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        // Act
        uint64[] memory orderIds = orderContract.getOrderIDsByMerchant(SELLER);
        // Assert
        assertEq(orderIds.length, 1);
        assertEq(orderIds[0], offerId);
    }

    function testGetMerchantOrderDetailsRevertsIfNotMerchant() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(OrderContract.OrderContract__NotOrderByMerchanProvided.selector);
        orderContract.getMerchantOrderDetails(USER, offerId);
    }

    function testGetMerchantOrderDetails() public proposeOrderForUser orderProposedAnsweredByAgent {
        // Arrange
        uint64 offerId = 1;
        // Act
        OrderContract.Offer memory offer = orderContract.getMerchantOrderDetails(SELLER, offerId);
        // Assert
        assertEq(offer.buyer, USER);
        assertEq(offer.seller, SELLER);
        assertEq(uint8(offer.status), uint8(OrderContract.OrderStatus.Proposed));
    }

    /*//////////////////////////////////////////////////////////////
                           MERCHANT NFT TESTS
    //////////////////////////////////////////////////////////////*/
    function testMerchantNftMintingAndOwnership() public {
        // Arrange
        uint256 merchantId = 2;
        // Act
        vm.prank(owner);
        merchantNft.mintNft(merchantId, SELLER);
        // Assert
        address ownerOfNft = merchantNft.ownerOf(merchantId);
        assertEq(ownerOfNft, SELLER);
        bool isMerchant = merchantNft.isMerchant(SELLER, merchantId);
        assertTrue(isMerchant);

    }


    function testMerchantNftRevertsOnDuplicateMint() public {
        // Arrange
        uint256 merchantId = 2;
        vm.prank(owner);
        merchantNft.mintNft(merchantId, SELLER);
        // Act / Assert
        vm.prank(owner);
        vm.expectRevert(MerchantNft.MerchantNft__MerchantIdAlreadyMinted.selector);
        merchantNft.mintNft(merchantId, USER);

    }

    function testMerchantNftReturnsFalseIfNotOwner() public {
        // Arrange
        uint256 merchantId = 2;
        vm.prank(owner);
        merchantNft.mintNft(merchantId, SELLER);
        // Act
        bool isMerchant = merchantNft.isMerchant(USER, merchantId);
        // Assert
        assertFalse(isMerchant);
    }

    function testMerchantNftOnlyOwnerCanMint() public {
        // Arrange
        uint256 merchantId = 2;
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(MerchantNft.MerchantNft__OnlyOwnerCanCall.selector);
        merchantNft.mintNft(merchantId, USER);
    }

    /*//////////////////////////////////////////////////////////////
                           CANCEL ORDER TESTS
    //////////////////////////////////////////////////////////////*/
    function testCancelOrderUpdatesState() public orderConfirmed {
        // Arrange
        uint256 userBalanceBefore = ERC20Mock(pyUSD).balanceOf(USER);
        uint64 offerId = 1;
        vm.warp(block.timestamp + 700);
        vm.roll(1); // Move time forward to allow cancellation
        // Act
        vm.prank(USER);
        orderContract.cancelOrder(offerId);
        // Assert
        uint256 userBalanceAfter = ERC20Mock(pyUSD).balanceOf(USER);
        OrderContract.OrderStatus status = orderContract.getOfferStatus(offerId);
        assertEq(userBalanceAfter - userBalanceBefore, orderContract.getAmountPaid(offerId));
        assertEq(uint8(status), uint8(OrderContract.OrderStatus.Cancelled));
    }


    /*//////////////////////////////////////////////////////////////
                       USER ORDER MAPPINGS TESTS
    //////////////////////////////////////////////////////////////*/
    function testProposeOrderUpdatesUserMappings() public {
        // Arrange
        bytes32 testPromptHash = keccak256(abi.encodePacked("Test Prompt"));
        
        // Act
        vm.prank(USER);
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
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
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
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
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
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
        ERC20Mock(pyUSD).approve(address(orderContract), DEFAULT_APPROVE_AMOUNT);
        vm.startPrank(addressController);
        uint64 offerId = orderContract.proposeOrder(PROMPT_HASH, USER);
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