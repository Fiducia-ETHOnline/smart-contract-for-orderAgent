//SPDX-License-Identifier: MIT

import {OrderContract} from "../../src/OrderContract.sol";
import {Test, console} from "forge-std/Test.sol";
import {A3AToken} from "../../src/A3Atoken.sol";


pragma solidity ^0.8.18;


contract FuzzHandler is Test {
    
    A3AToken public tokenContract;
    OrderContract public orderContract;

    uint64 public orderIdCounter = 0;
    uint64[] public orderIdArray;

    constructor(address orderContractAddress, address tokenAddress) {
        orderContract = OrderContract(orderContractAddress);
        tokenContract = A3AToken(tokenAddress);
        
    }

    function proposeOrder(bytes32 promptHash, address userWalletAddress) external {
        if (userWalletAddress == address(0)) {
            return;
        }
        orderIdCounter++;
        vm.prank(address(orderContract));
        tokenContract.mint(userWalletAddress, 1000 ether);
        vm.prank(userWalletAddress);
        tokenContract.approve(address(orderContract), 500 ether);
        vm.startPrank(address(5));
        orderContract.proposeOrder(promptHash, userWalletAddress);
        vm.stopPrank();
        orderIdCounter++;
        orderIdArray.push(orderIdCounter);

       
        
    }

    function proposeOrderAnswer(bytes32 answerHash, uint64 offerId, uint256 priceForOffer, address seller) external {
        if (seller == address(0)) {
            return;
        }
        if (orderIdArray.length == 0) {
            return;
        }
        uint64 offerID = orderIdArray[offerId % orderIdArray.length];
        
        if (offerID == 0) {
            return;
        }
        if (orderContract.getOfferStatus(offerID) != OrderContract.OrderStatus.InProgress) {
            return;
        }
        vm.prank(address(5));
        orderContract.proposeOrderAnswer(answerHash, offerID, priceForOffer, seller);
    }

}
