# OrderContract Backend Integration Guide

## Overview

This guide provides comprehensive instructions for integrating with the OrderContract smart contract from your backend application. The contract now includes user order mapping functionality that allows efficient querying of user orders and their statuses.

## New Features Added

### User Order Mapping
- **Nested mapping structure**: Tracks which orders belong to which users
- **Efficient querying**: Get all orders for a user without scanning all orders
- **Status tracking**: Query order status by user and order ID
- **Filtering capabilities**: Get orders by specific status

## Contract Details

### Network Information
- **Contract Address**: `[TO BE DEPLOYED]`
- **Supported Networks**: Ethereum Sepolia (testnet), Local Anvil
- **pyUSD Token Address**: `0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9` (Sepolia)

### Key Constants
- **AGENT_FEE**: 1 ether (1 pyUSD)
- **HOLD_UNTIL**: 600 seconds (10 minutes)

## Order Status Enum

```solidity
enum OrderStatus {
    Proposed,    // 0 - Order has been proposed by agent with price
    Confirmed,   // 1 - User has confirmed and paid for the order
    InProgress,  // 2 - Order has been created but no answer proposed yet
    Completed,   // 3 - Order has been finalized and payment released
    Cancelled    // 4 - Order has been cancelled and refunded
}
```

## Core Functions

### For Users

#### `proposeOrder(bytes32 promptHash) → uint64 offerId`
Creates a new order with the given prompt hash.
- **Status after**: InProgress
- **User mapping**: Automatically updated

#### `confirmOrder(uint64 offerId)`
Confirms an order that has been proposed by the agent.
- **Requires**: Order must be in Proposed status
- **Payment**: price + AGENT_FEE must be transferred
- **Status after**: Confirmed

#### `cancelOrder(uint64 offerId)`
Cancels a confirmed order after hold period.
- **Requires**: Order in Confirmed status, hold period elapsed
- **Status after**: Cancelled
- **Refund**: Full payment returned to user

### For Agent Controller

#### `proposeOrderAnswer(bytes32 answerHash, uint64 offerId, uint256 priceForOffer)`
Proposes an answer and price for an InProgress order.
- **Status after**: Proposed

#### `finalizeOrder(uint64 offerId) → bool`
Finalizes a confirmed order and releases payment.
- **Status after**: Completed
- **Payment**: Full amount transferred to agent controller

## New User Query Functions

### `getUserOrderIds(address user) → uint64[]`
Returns all order IDs for a specific user.

```javascript
// Example usage
const userOrderIds = await contract.getUserOrderIds(userAddress);
console.log(`User has ${userOrderIds.length} orders:`, userOrderIds);
```

### `hasUserOrder(address user, uint64 orderId) → bool`
Checks if a specific order belongs to a user.

```javascript
const hasOrder = await contract.hasUserOrder(userAddress, orderId);
```

### `getUserOrderStatus(address user, uint64 orderId) → OrderStatus`
Gets the status of a specific order for a user.

```javascript
const status = await contract.getUserOrderStatus(userAddress, orderId);
// status will be 0-4 corresponding to the OrderStatus enum
```

### `getUserOrdersWithStatus(address user) → (uint64[], OrderStatus[])`
Gets all orders and their statuses for a user.

```javascript
const [orderIds, statuses] = await contract.getUserOrdersWithStatus(userAddress);
// Returns parallel arrays
```

### `getUserOrderDetails(address user, uint64 orderId) → Offer`
Gets complete order details for a user's order.

```javascript
const orderDetails = await contract.getUserOrderDetails(userAddress, orderId);
// Returns: { buyer, promptHash, answerHash, price, paid, timestamp, status }
```

### `getUserOrdersByStatus(address user, OrderStatus status) → uint64[]`
Gets all orders for a user filtered by status.

```javascript
// Get all InProgress orders
const inProgressOrders = await contract.getUserOrdersByStatus(userAddress, 2);
// Get all Completed orders
const completedOrders = await contract.getUserOrdersByStatus(userAddress, 3);
```

## JavaScript/TypeScript Integration Examples

### Setup

```javascript
const { ethers } = require('ethers');
const OrderContractABI = require('./OrderContract_ABI.json');

// Provider setup
const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const contract = new ethers.Contract(CONTRACT_ADDRESS, OrderContractABI, provider);

// For transactions, you'll need a signer
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const contractWithSigner = contract.connect(wallet);
```

### Backend Helper Functions

```javascript
class OrderContractHelper {
    constructor(contractAddress, provider, signerPrivateKey = null) {
        this.contract = new ethers.Contract(contractAddress, OrderContractABI, provider);
        this.provider = provider;
        
        if (signerPrivateKey) {
            this.wallet = new ethers.Wallet(signerPrivateKey, provider);
            this.contractWithSigner = this.contract.connect(this.wallet);
        }
    }

    // Get all user orders with details
    async getUserOrdersDetailed(userAddress) {
        try {
            const [orderIds, statuses] = await this.contract.getUserOrdersWithStatus(userAddress);
            
            const orders = [];
            for (let i = 0; i < orderIds.length; i++) {
                const details = await this.contract.getUserOrderDetails(userAddress, orderIds[i]);
                orders.push({
                    orderId: orderIds[i].toString(),
                    status: this.getStatusName(statuses[i]),
                    statusCode: statuses[i],
                    buyer: details.buyer,
                    promptHash: details.promptHash,
                    answerHash: details.answerHash,
                    price: ethers.formatEther(details.price),
                    paid: ethers.formatEther(details.paid),
                    timestamp: new Date(Number(details.timestamp) * 1000),
                });
            }
            
            return orders;
        } catch (error) {
            console.error('Error fetching user orders:', error);
            throw error;
        }
    }

    // Get orders by status for frontend filtering
    async getUserOrdersByStatus(userAddress, status) {
        try {
            const orderIds = await this.contract.getUserOrdersByStatus(userAddress, status);
            return orderIds.map(id => id.toString());
        } catch (error) {
            console.error('Error fetching orders by status:', error);
            throw error;
        }
    }

    // Create new order
    async createOrder(promptHash) {
        if (!this.contractWithSigner) {
            throw new Error('Signer required for transactions');
        }
        
        try {
            const tx = await this.contractWithSigner.proposeOrder(promptHash);
            const receipt = await tx.wait();
            
            // Extract order ID from events
            const event = receipt.logs.find(log => 
                log.topics[0] === ethers.id("OrderProposed(address,uint64,bytes32)")
            );
            
            if (event) {
                const decoded = this.contract.interface.parseLog(event);
                return decoded.args.offerId.toString();
            }
            
            throw new Error('OrderProposed event not found');
        } catch (error) {
            console.error('Error creating order:', error);
            throw error;
        }
    }

    // Helper to convert status code to readable name
    getStatusName(statusCode) {
        const statusNames = ['Proposed', 'Confirmed', 'InProgress', 'Completed', 'Cancelled'];
        return statusNames[statusCode] || 'Unknown';
    }

    // Listen for order events
    setupEventListeners(userAddress, callback) {
        // Listen for new orders
        this.contract.on('OrderProposed', (user, offerId, promptHash, event) => {
            if (user.toLowerCase() === userAddress.toLowerCase()) {
                callback('OrderProposed', {
                    user,
                    offerId: offerId.toString(),
                    promptHash,
                    transactionHash: event.transactionHash
                });
            }
        });

        // Listen for order confirmations
        this.contract.on('OrderConfirmed', (user, offerId, amountPaid, event) => {
            if (user.toLowerCase() === userAddress.toLowerCase()) {
                callback('OrderConfirmed', {
                    user,
                    offerId: offerId.toString(),
                    amountPaid: ethers.formatEther(amountPaid),
                    transactionHash: event.transactionHash
                });
            }
        });

        // Listen for order finalizations
        this.contract.on('orderFinalized', (user, offerId, event) => {
            if (user.toLowerCase() === userAddress.toLowerCase()) {
                callback('orderFinalized', {
                    user,
                    offerId: offerId.toString(),
                    transactionHash: event.transactionHash
                });
            }
        });
    }
}
```

### Usage Examples

```javascript
// Initialize helper
const orderHelper = new OrderContractHelper(
    'CONTRACT_ADDRESS',
    provider,
    'AGENT_CONTROLLER_PRIVATE_KEY' // Optional, for transactions
);

// Get all orders for a user
app.get('/api/orders/:userAddress', async (req, res) => {
    try {
        const orders = await orderHelper.getUserOrdersDetailed(req.params.userAddress);
        res.json({ success: true, orders });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Get orders by status
app.get('/api/orders/:userAddress/status/:status', async (req, res) => {
    try {
        const status = parseInt(req.params.status);
        const orderIds = await orderHelper.getUserOrdersByStatus(req.params.userAddress, status);
        res.json({ success: true, orderIds });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Create new order
app.post('/api/orders', async (req, res) => {
    try {
        const { promptHash } = req.body;
        const orderId = await orderHelper.createOrder(promptHash);
        res.json({ success: true, orderId });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
```

## Error Handling

The contract includes custom errors that should be handled in your backend:

- `OrderContract__notAgentController()`: Only agent controller can call this function
- `OrderContract__ERC20TransferFailed()`: Token transfer failed
- `OrderContract__userHasNoAccessToOffer()`: User doesn't own this order
- `OrderContract__OrderCannotBeConfirmedInCurrentState()`: Order not in correct state
- `OrderContract__OrderCannotBeCanceledInCurrentState()`: Order not in correct state
- `OrderContract__OrderCannotBeFinalizedInCurrentState()`: Order not in correct state
- `OrderContract__EnoughTimeHasNotPassed()`: Hold period not elapsed
- `OrderContract__CannotProposeOrderAnswerInCurrentState()`: Order not in correct state

## Frontend Integration

For frontend applications, you can use the same functions but with a web3 provider:

```javascript
// With MetaMask
if (window.ethereum) {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const contract = new ethers.Contract(CONTRACT_ADDRESS, OrderContractABI, signer);
    
    // Get user's orders
    const userAddress = await signer.getAddress();
    const orders = await contract.getUserOrdersWithStatus(userAddress);
}
```

## Testing

You can test the integration using a local Anvil instance:

```bash
# Start Anvil
anvil

# Deploy contract (in another terminal)
forge script script/DeployOrderContract.s.sol --rpc-url http://localhost:8545 --broadcast

# The contract address will be shown in the deployment output
```

## Security Considerations

1. **Input Validation**: Always validate user inputs before calling contract functions
2. **Error Handling**: Implement proper error handling for all contract calls
3. **Rate Limiting**: Implement rate limiting for contract interactions
4. **Private Key Security**: Never expose private keys in client-side code
5. **Transaction Monitoring**: Monitor transactions for failures and implement retry logic

## File Locations

- **Contract ABI**: `OrderContract_ABI.json`
- **Contract Bytecode**: `OrderContract_Bytecode.txt`
- **Contract Source**: `src/OrderContract.sol`
- **Tests**: `test/unit/OrderContractTest.t.sol`

## Support

For questions or issues with the integration, please refer to:
- Contract source code in `src/OrderContract.sol`
- Test examples in `test/unit/OrderContractTest.t.sol`
- This integration guide

## Next Steps

1. Deploy the contract to your target network
2. Update the contract address in your backend configuration
3. Implement the helper functions in your backend
4. Test the integration thoroughly
5. Set up monitoring and logging for contract interactions