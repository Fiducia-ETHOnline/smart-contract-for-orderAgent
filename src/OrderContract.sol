// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OrderContract is ReentrancyGuard{
    /* errors */
    error OrderContract__notAgentController();
    error OrderContract__ERC20TransferFailed();
    error OrderContract__userHasNoAccessToOffer();
    error OrderContract__OrderCannotBeConfirmedInCurrentState();
    error OrderContract__OrderCannotBeCanceledInCurrentState();
    error OrderContract__OrderCannotBeFinalizedInCurrentState();
    error OrderContract__EnoughTimeHasNotPassed();
    error OrderContract__CannotProposeOrderAnswerInCurrentState();

    /* type declarations */
    enum OrderStatus {
        Proposed,
        Confirmed,
        InProgress,
        Completed,
        Cancelled      
    }

    struct Offer {
        address buyer;
        bytes32 promptHash;
        bytes32 answerHash;
        uint256 price; 
        uint256 paid; 
        uint256 timestamp;
        OrderStatus status;
    }
    /* state variables */
    uint256 private constant AGENT_FEE = 1 ether; // Fee for agent services. Adjust as needed.
    uint256 private constant HOLD_UNTIL = 600; // Time in seconds to hold the order. Adjust as needed.
    uint64 private offerID = 0; // Counter for offer IDs
    address private immutable agentController; // Address of the agent controller
    address private immutable pyUSD; // Address of the pyUSD token contract
    
    // will make mappings to struct!!! thus too messy.
    //////////////////////////////////////////////
    //  FIX THIS!!!!
    ///////////////////////////////////
    // mapping(address => mapping(uint64 offerId => bytes32 promptHash)) private addressToOfferIdToPromptHash;
    // mapping(uint64 offerId => uint256 timestamp) private offerIdToTimestamp;
    // mapping(uint64 offerId => mapping(address user => uint256 amountPaid)) private offerIdToUserToAmountPaid;
    // mapping(uint64 offerId => OrderStatus status) private offerIdToStatus;
    // mapping(uint64 offerId => bytes32 answerHash) private offerIdToAnswerHash;
    // mapping(uint64 => address) private offerIdToUser;

    mapping(uint64 => Offer) public offers;
    /* events */
    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);
    event orderFinalized(address indexed user, uint64 indexed offerId);
    /* modifiers */
    modifier onlyAgentController() {
        // Placeholder for access control logic
        if (msg.sender != agentController) {
            revert OrderContract__notAgentController();
        }
        _;
    }
    modifier onlyUserWithOffer(uint64 offerId) {
        // Ensure the caller has a valid offer
        if (offers[offerId].buyer != msg.sender) {
            revert OrderContract__userHasNoAccessToOffer();
        }
        _;
        
    }
    constructor(address agentControllerAddress, address pyUSDAddress) {
        // Initialization logic if needed
        agentController = agentControllerAddress;
        pyUSD = pyUSDAddress;
    }
    function proposeOrder(bytes32 promptHash) external returns(uint64 offerId) {
        
        // Increment the offer ID counter
        offerID++;
        
        // offerIdToStatus[offerID] = OrderStatus.InProgress;
        offers[offerID].status = OrderStatus.InProgress;
        offers[offerID].buyer = msg.sender;
        offers[offerID].promptHash = promptHash;
        // addressToOfferIdToPromptHash[msg.sender][offerID] = promptHash;
        // offerIdToUser[offerID] = msg.sender;
        emit OrderProposed(offers[offerID].buyer, offerID, offers[offerID].promptHash);
        
        return offerID;
        
    }



    function confirmOrder(uint64 offerId) external nonReentrant onlyUserWithOffer(offerId) {
        if ( offers[offerId].status != OrderStatus.Proposed) {
            revert OrderContract__OrderCannotBeConfirmedInCurrentState();
        }
        // update amount paid for the offer by the user
        uint256 amountToPay = offers[offerId].price + AGENT_FEE;
        // offerIdToUserToAmountPaid[offerId][msg.sender] += amountToPay;
        // offerIdToStatus[offerId] = OrderStatus.Confirmed;
        offers[offerId].paid = amountToPay;
        offers[offerId].status = OrderStatus.Confirmed;
        // Record the current timestamp for the offer
        // offerIdToTimestamp[offerId] = block.timestamp;
        offers[offerId].timestamp = block.timestamp;
        bool success= ERC20(pyUSD).transferFrom(msg.sender, address(this), amountToPay);
        
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
        emit OrderConfirmed(msg.sender, offerId, amountToPay);
        
    }


    // Save answer from propose order. Answer will be the proposed order. Set orderStatus to proposed.
    function proposeOrderAnswer(bytes32 answerHash, uint64 offerId, uint256 priceForOffer) external onlyAgentController {
        if (offers[offerId].status != OrderStatus.InProgress) {
            revert OrderContract__CannotProposeOrderAnswerInCurrentState();
        }
        // offerIdToAnswerHash[offerId] = answerHash;
        // offerIdToStatus[offerId] = OrderStatus.Proposed;
        offers[offerId].answerHash = answerHash;
        offers[offerId].status = OrderStatus.Proposed;
        offers[offerId].price = priceForOffer;
    }

    function finalizeOrder(uint64 offerId) external onlyAgentController nonReentrant returns(bool){
        if (offers[offerId].status != OrderStatus.Confirmed) {
            revert OrderContract__OrderCannotBeFinalizedInCurrentState();
        }
        // offerIdToStatus[offerId] = OrderStatus.Completed;
        offers[offerId].status = OrderStatus.Completed;
        uint256 amountPaid = offers[offerId].paid;
        emit orderFinalized(getUserByOfferId(offerId), offerId);
        bool success = ERC20(pyUSD).transfer(agentController, amountPaid);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }

        return true;

    }

    function cancelOrder(uint64 offerId) external nonReentrant onlyUserWithOffer(offerID) {
        if (block.timestamp - offers[offerId].timestamp < HOLD_UNTIL) {
            revert OrderContract__EnoughTimeHasNotPassed();
        }
        if (offers[offerId].status != OrderStatus.Confirmed) {
            revert OrderContract__OrderCannotBeCanceledInCurrentState();
        }
        // offerIdToStatus[offerId] = OrderStatus.Cancelled;
        offers[offerId].status = OrderStatus.Cancelled;
        bool success = ERC20(pyUSD).transfer(msg.sender, offers[offerId].paid);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
    }



    /* getter functions */
    function getPromptHash(uint64 offerId) external view returns (bytes32) {
        return offers[offerId].promptHash;
    }
    
    function getAmountPaid(uint64 offerId) external view returns (uint256) {
        return offers[offerId].paid;
    }

    function getAgentController() external view returns (address) {
        return agentController;
    }

    function getAgentFee() external pure returns (uint256) {
        return AGENT_FEE;
    }

    function getOfferIdToTimestamp(uint64 offerId) external view returns (uint256) {
        return offers[offerId].timestamp;
    }



    function getUserByOfferId(uint64 offerId) public view returns (address) {
        return offers[offerId].buyer;
    }

    function getOfferStatus(uint64 offerId) external view returns (OrderStatus) {
        return offers[offerId].status;
    }
    
    function getAnswerHash(uint64 offerId) external view returns (bytes32) {
        return offers[offerId].answerHash;
    }



}