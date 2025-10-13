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
    error notAgentController();
    error ERC20TransferFailed();
    error userHasNoAccessToOffer();
    error OrderCannotBeConfirmedInCurrentState();

    /* type declarations */
    enum OrderStatus {
        Proposed,
        Confirmed,
        InProgress,
        Completed,
        Cancelled      
    }
    /* state variables */
    uint256 private constant AGENT_FEE = 1 ether; // Fee for agent services. Adjust as needed.
    uint256 private constant HOLD_UNTIL = 600; // Time in seconds to hold the order. Adjust as needed.
    uint64 private offerID = 0; // Counter for offer IDs
    address private immutable agentController; // Address of the agent controller
    address private immutable pyUSD; // Address of the pyUSD token contract
    mapping(address => mapping(uint64 offerId => bytes32 promptHash)) private addressToOfferIdToPromptHash;
    mapping(uint64 offerId => uint256 timestamp) private offerIdToTimestamp;
    mapping(uint64 offerId => mapping(address user => uint256 amountPaid)) private offerIdToUserToAmountPaid;
    mapping(uint64 offerId => OrderStatus status) private offerIdToStatus;
    mapping(uint64 offerId => bytes32 answerHash) private offerIdToAnswerHash;

    /* events */
    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);
    
    /* modifiers */
    modifier onlyAgentController() {
        // Placeholder for access control logic
        if (msg.sender != agentController) {
            revert notAgentController();
        }
        _;
    }
    modifier onlyUserWithOffer(uint64 offerId) {
        // Ensure the caller has a valid offer
        if (addressToOfferIdToPromptHash[msg.sender][offerId] == bytes32(0)) {
            revert userHasNoAccessToOffer();
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

        offerIdToStatus[offerID] = OrderStatus.InProgress;
        addressToOfferIdToPromptHash[msg.sender][offerID] = promptHash;
        emit OrderProposed(msg.sender, offerID, promptHash);
        
        return offerID;
        
    }



    function confirmOrder(uint64 offerId, uint256 priceForOffer) external nonReentrant onlyUserWithOffer(offerId) {
        if ( offerIdToStatus[offerId] != OrderStatus.Proposed) {
            revert OrderCannotBeConfirmedInCurrentState();
        }
        // update amount paid for the offer by the user
        uint256 amountToPay = priceForOffer + AGENT_FEE;
        offerIdToUserToAmountPaid[offerId][msg.sender] += amountToPay;
        offerIdToStatus[offerId] = OrderStatus.Confirmed;
        // Record the current timestamp for the offer
        offerIdToTimestamp[offerId] = block.timestamp;
        bool success= ERC20(pyUSD).transferFrom(msg.sender, address(this), priceForOffer + AGENT_FEE);
        
        if (!success) {
            revert ERC20TransferFailed();
        }
        emit OrderConfirmed(msg.sender, offerId, amountToPay);
        
    }


    // Save answer from propose order. Answer will be the proposed order. Set orderStatus to proposed.
    function proposeOrderAnswer(bytes32 answerHash, uint64 offerId) external onlyAgentController {
        offerIdToAnswerHash[offerId] = answerHash;
        offerIdToStatus[offerId] = OrderStatus.Proposed;
    }

    function finalizeBooking (uint64 offerId) external onlyAgentController {
        if (offerIdToStatus[offerId] != OrderStatus.Confirmed) {
            revert OrderCannotBeConfirmedInCurrentState();
        }
        offerIdToStatus[offerId] = OrderStatus.Completed;
        uint256 amountPaid = offerIdToUserToAmountPaid[offerId][msg.sender];
        bool success = ERC20(pyUSD).transfer(msg.sender, amountPaid - AGENT_FEE);
        if (!success) {
            revert ERC20TransferFailed();
        }
    }



    /* getter functions */
    function getPromptHash(address user, uint64 offerId) external view returns (bytes32) {
        return addressToOfferIdToPromptHash[user][offerId];
    }
    
    function getAmountPaid(uint64 offerId, address user) external view returns (uint256) {
        return offerIdToUserToAmountPaid[offerId][user];
    }

    function getAgentController() external view returns (address) {
        return agentController;
    }

    function getAgentFee() external pure returns (uint256) {
        return AGENT_FEE;
    }

    function getOfferIdToTimestamp(uint64 offerId) external view returns (uint256) {
        return offerIdToTimestamp[offerId];
    }










}