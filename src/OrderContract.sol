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
import {A3AToken} from "./A3Atoken.sol";

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
    error OrderContract__NotOrderByMerchanProvided();

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
        address seller;
        bytes32 promptHash;
        bytes32 answerHash;
        uint256 price; 
        uint256 paid; 
        uint256 timestamp;
        OrderStatus status;
    }
    /* state variables */
    uint256 private constant ADDITIONAL_PRECISION = 1e12; // To handle decimals for tokens with less than 18 decimals
    uint256 private constant AGENT_FEE = 1e6; // Fee for agent services. Adjust as needed.
    uint256 private constant HOLD_UNTIL = 600; // Time in seconds to hold the order. Adjust as needed.
    uint64 private offerID = 0; // Counter for offer IDs
    address private immutable i_agentController; // Address of the agent controller
    address private immutable i_pyUSD; // Address of the pyUSD token contract
    address private immutable i_a3aToken; // Address of the A3A token contract
    

    mapping(uint64 => Offer) public offers;
    mapping(address => uint64[]) private userOrderIds;
    mapping(address => uint64[]) private merchantOrderIds;

    
    /* events */
    event OrderProposed(address indexed user, uint64 indexed offerId, bytes32 indexed promptHash);
    event OrderConfirmed(address indexed user, uint64 indexed offerId, uint256 indexed amountPaid);
    event orderFinalized(address indexed user, uint64 indexed offerId);
    /* modifiers */
    modifier onlyAgentController() {
        // Placeholder for access control logic
        if (msg.sender != i_agentController) {
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
    constructor(address agentControllerAddress, address pyUSDAddress, address a3aTokenAddress) {
        // Initialization logic if needed
        i_agentController = agentControllerAddress;
        i_pyUSD = pyUSDAddress;
        i_a3aToken = a3aTokenAddress;
    }

    /**
     * @notice Propose a new order on the platform. Saves the prompt hash
     * and user wallet address and marks order as InProgress. Only our order agent can call
     * @param promptHash The hash/CID from user prompt
     * @param userWalletAddress The address of the user wallet using the platform
     */
    function proposeOrder(bytes32 promptHash, address userWalletAddress) external onlyAgentController nonReentrant returns(uint64 offerId) {
        
        // Increment the offer ID counter
        offerID++;
        
        // offerIdToStatus[offerID] = OrderStatus.InProgress;
        offers[offerID].status = OrderStatus.InProgress;
        offers[offerID].buyer = userWalletAddress;
        offers[offerID].promptHash = promptHash;
        
        // Update user order mappings
       
        userOrderIds[userWalletAddress].push(offerID);
      

        emit OrderProposed(offers[offerID].buyer, offerID, offers[offerID].promptHash);
        // Burn 10 A3A tokens from uses. This acts as Fee for using the platform.
        _burnA3A(10 ether, userWalletAddress);
        return offerID;
        
    }

    /**
     * 
     * @param amount the amount of A3A tokens to burn
     * @param A3AFrom the address from which to burn A3A tokens
     */
    function _burnA3A(uint256 amount,address A3AFrom) private {
        
        bool success = A3AToken(i_a3aToken).transferFrom(A3AFrom, address(this), amount);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
        A3AToken(i_a3aToken).burn(amount);
    }


    /**
     * @notice User confirms the order by paying the amount + agent fee. Marks order as confirmed.
     * Only user who proposed the order can confirm it.
     * @param offerId The ID of the offer to confirm
     */
    function confirmOrder(uint64 offerId) external nonReentrant onlyUserWithOffer(offerId) {
        if ( offers[offerId].status != OrderStatus.Proposed) {
            revert OrderContract__OrderCannotBeConfirmedInCurrentState();
        }
        // update amount paid for the offer by the user
        uint256 amountToPay = offers[offerId].price + AGENT_FEE;
    
        offers[offerId].paid = amountToPay;
        offers[offerId].status = OrderStatus.Confirmed;
       
        offers[offerId].timestamp = block.timestamp;
        bool success= ERC20(i_pyUSD).transferFrom(msg.sender, address(this), amountToPay);
        
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
        emit OrderConfirmed(msg.sender, offerId, amountToPay);
        
    }


    /**
     * @notice Agent controller proposes the answer for the order. Marks order as Proposed.
     * @param answerHash The hash/CID of the answer generated for the prompt. The order that user should later confirm.
     * @param offerId The ID of the offer to propose answer for
     * @param priceForOffer amount the user should pay for the offer
     * @param seller the merchant/seller address fulfilling the order.
     */
    function proposeOrderAnswer(bytes32 answerHash, uint64 offerId, uint256 priceForOffer, address seller) external onlyAgentController {
        if (offers[offerId].status != OrderStatus.InProgress) {
            revert OrderContract__CannotProposeOrderAnswerInCurrentState();
        }
        // offerIdToAnswerHash[offerId] = answerHash;
        // offerIdToStatus[offerId] = OrderStatus.Proposed;
        offers[offerId].answerHash = answerHash;
        offers[offerId].status = OrderStatus.Proposed;
        offers[offerId].price = priceForOffer;
        offers[offerId].seller = seller;
        merchantOrderIds[seller].push(offerId);
    }
    /**
     * @notice Finalize the order by transferring the paid amount to the seller.
     * Marks order as Completed. Only our order agent should be able to confirm. To prevent fraud.
     * @param offerId The ID of the offer to finalize
     * @return bool indicating successful finalization
     */
    function finalizeOrder(uint64 offerId) external onlyAgentController nonReentrant returns(bool){
        if (offers[offerId].status != OrderStatus.Confirmed) {
            revert OrderContract__OrderCannotBeFinalizedInCurrentState();
        }
        // offerIdToStatus[offerId] = OrderStatus.Completed;
        offers[offerId].status = OrderStatus.Completed;
        uint256 amountPaid = offers[offerId].paid;
        emit orderFinalized(getUserByOfferId(offerId), offerId);
        bool success = ERC20(i_pyUSD).transfer(offers[offerId].seller, amountPaid);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }

        return true;

    }
    /**
     * @notice Cancel the order if enough time has passed since confirmation. Marks order as Cancelled. Only user who proposed and confirmed the order can cancel it.
     * @param offerId The ID of the offer to cancel
     */
    function cancelOrder(uint64 offerId) external nonReentrant onlyUserWithOffer(offerID) {
        if (block.timestamp - offers[offerId].timestamp < HOLD_UNTIL) {
            revert OrderContract__EnoughTimeHasNotPassed();
        }
        if (offers[offerId].status != OrderStatus.Confirmed) {
            revert OrderContract__OrderCannotBeCanceledInCurrentState();
        }
        // offerIdToStatus[offerId] = OrderStatus.Cancelled;
        offers[offerId].status = OrderStatus.Cancelled;
        bool success = ERC20(i_pyUSD).transfer(msg.sender, offers[offerId].paid);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
    }

    /**
     * @notice Buy A3A tokens by spending pyUSD tokens. Users can buy A3A tokens to use our platform.
     * @param PyUsdAmount amount of pyUSD to spend on buying A3A tokens
     */
    function buyA3AToken(uint256 PyUsdAmount) external nonReentrant {

        bool success = ERC20(i_pyUSD).transferFrom(msg.sender, address(this), PyUsdAmount);
        if (!success) {
            revert OrderContract__ERC20TransferFailed();
        }
        A3AToken(i_a3aToken).mint(msg.sender, (PyUsdAmount*ADDITIONAL_PRECISION)*100);
    }



    /* getter functions */
    function getPromptHash(uint64 offerId) external view returns (bytes32) {
        return offers[offerId].promptHash;
    }
    
    function getAmountPaid(uint64 offerId) external view returns (uint256) {
        return offers[offerId].paid;
    }

    function getAgentController() external view returns (address) {
        return i_agentController;
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
    
    function getOrderIDsByMerchant(address merchant) external view returns (uint64[] memory) {
        return merchantOrderIds[merchant];
    }

    function getMerchantOrderDetails(address merchant, uint64 orderId) external view returns (Offer memory) {
        // Check if the order belongs to the merchant
        if (offers[orderId].seller != merchant) {
            revert OrderContract__NotOrderByMerchanProvided();
        }
        return offers[orderId];
    }

    function getA3ATokenAddress() external view returns (address) {
        return i_a3aToken;
    }

    // User order query functions for backend integration
    
    /**
     * @notice Get all order IDs for a specific user
     * @param user The address to query orders for
     * @return Array of order IDs belonging to the user
     */
    function getUserOrderIds(address user) external view returns (uint64[] memory) {
        return userOrderIds[user];
    }
    
    /**
     * @notice Check if a user has a specific order
     * @param user The user address
     * @param orderId The order ID to check
     * @return bool indicating if the user has this order
     */
    function hasUserOrder(address user, uint64 orderId) public view returns (bool) {
        if (offers[orderId].buyer == user) {
            return true;
        } else {
            return false;
        }
    }
    
    /**
     * @notice Get the status of a specific order for a user
     * @param user The user address
     * @param orderId The order ID
     * @return OrderStatus of the specified order
     */
    function getUserOrderStatus(address user, uint64 orderId) external view returns (OrderStatus) {
        if (offers[orderId].buyer != user) {
            revert OrderContract__userHasNoAccessToOffer();
        }
        // require(userOrders[user][orderId], "Order does not belong to user");
        return offers[orderId].status;
    }
  
    
    
    /**
     * @notice Get complete order details for a user's specific order
     * @param user The user address
     * @param orderId The order ID
     * @return Complete Offer struct for the specified order
     */
    function getUserOrderDetails(address user, uint64 orderId) external view returns (Offer memory) {
        if (hasUserOrder(user, orderId) == false) {
            revert OrderContract__userHasNoAccessToOffer();
        }
        return offers[orderId];
    }
    
   
   


}
