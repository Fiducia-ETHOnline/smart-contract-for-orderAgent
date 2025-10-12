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

contract OrderContract {
    /* errors */
    error notAgentController();
    /* state variables */
    uint256 private constant AGENT_FEE = 1 ether; // Fee for agent services. Adjust as needed.
    uint256 private constant HOLD_UNTIL = 600; // Time in seconds to hold the order. Adjust as needed.
    uint64 private offerID = 0; // Counter for offer IDs
    address private immutable agentController; // Address of the agent controller
    mapping(address => mapping(uint64 offerId => bytes32 promptHash)) public addressToOfferIdToPromptHash;

    modifier onlyAgentController() {
        // Placeholder for access control logic
        if (msg.sender != agentController) {
            revert notAgentController();
        }
        _;
        
    }
    constructor(address agentControllerAddress) {
        // Initialization logic if needed
        agentController = agentControllerAddress;
    }
    function proposeOrder(uint64 agentId, uint256 amountForCompute, bytes32 promptHash) public returns(uint64 offerId) {
        // Increment the offer ID counter
        offerID++;
        // Store the prompt hash associated with the sender's address and the new offer ID
        addressToOfferIdToPromptHash[msg.sender][offerID] = promptHash;
        // Return the new offer ID
        return offerID;
        
    }

}