# 🧠 A3A — AI-Driven Commerce on Chain

**ETHGlobal Hackathon Submission (Built with Foundry)**

**A3A** connects **AI agents**, **verified merchants**, and **on-chain payments** into a single trustless system.
Orders, validation, and settlement all happen transparently on-chain — powered by three smart contracts:

* **MerchantNft** → verifies merchants
* **OrderContract** → manages orders and escrow
* **A3AToken** → handles platform fees and incentives

> 🧩 All contracts are **deployed and verified on Sepolia** testnet.
> OrderContract Sepolia: 0x1417178178d35E5638c30B4070eB4F4ccC0aEaD0
> MerchantNft Sepolia: 0xe2d8c380db7d124D03DACcA07645Fea659De9738
> A3AToken Sepolia: 0xE643887beaE652270d071D61F8d1F900A02b550C

---

## ⚙️ Tech Stack

* **Language:** Solidity ^0.8.18
* **Framework:** Foundry
* **Dependencies:** OpenZeppelin Contracts
* **Network:** Sepolia (testnet)
* **Frontend:** AI-powered dashboard (demo to follow)

---

## 🏗️ Contract Overview

| Contract             | Description                                                                                                     | File                    |
| -------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------- |
| 🪪 **MerchantNft**   | ERC-721 NFT for verified merchants. Lets approved merchants access a dashboard to manage products and listings. | `src/MerchantNft.sol`   |
| 🧾 **OrderContract** | Handles the full order lifecycle — prompt creation, merchant response, confirmation, and settlement.            | `src/OrderContract.sol` |
| 🔥 **A3AToken**      | ERC-20 utility token used for platform fees, minted and burned by protocol.                                     | `src/A3AToken.sol`      |

---

## 🔁 High-Level Flow

```
User (Buyer)
   │  prompt
   ▼
AI Order Agent (Controller)
   │ proposeOrder()
   ▼
OrderContract
   │ proposeOrderAnswer() ← Merchant’s response posted by AI Agent
   ▼
Buyer confirms payment (confirmOrder)
   │
Funds escrowed in pyUSD + A3A burn
   │
Merchant paid on finalizeOrder()
```

---

## 💡 Why the Order Agent Calls `proposeOrderAnswer()`

In this MVP, **the Order Agent (AI controller)** — not the merchant — calls `proposeOrderAnswer()`.
This design ensures that **only validated answers** are posted on-chain, preventing fake or low-quality submissions and removing the need for on-chain dispute resolution.

> ⚖️ *The controller acts as a trusted validator between the AI system and the blockchain.*

---

## 🧩 MerchantNft (ERC-721)

**Core Features**

* `applyForMerchantNft()` → merchant requests verification
* `approveApplicant(address)` → owner approves and mints NFT
* `rejectApplicant(address)` → mark application as rejected
* `ownerBurn(tokenId)` → revoke merchant
* `isMerchant(address, id)` → verify ownership

**Purpose:**
Holding this NFT unlocks the **merchant dashboard**, allowing listing management and merchant-only tools.

---

## ⚙️ OrderContract (Core Logic)

**Lifecycle**

1. **AI Agent:** `proposeOrder(promptHash, userAddr)`
2. **AI Agent:** `proposeOrderAnswer(answerHash, offerId, price, sellerAddr)` *(merchant’s response)*
3. **Buyer:** `confirmOrder(offerId)` → transfers pyUSD, burns A3A, marks order confirmed
4. **Agent:** `finalizeOrder(offerId)` → releases payment to merchant
5. **Buyer:** `cancelOrder(offerId)` → refunds if merchant doesn’t deliver in time

**Other Functions**

* `buyA3AToken()` — buy A3A tokens with pyUSD
* `getUserOrderDetails()`, `getOrderIDsByMerchant()`, etc.

---

## 💰 A3AToken (ERC-20)

* `mint(address, amount)` → owner-only mint
* `burn(amount)` → owner-only burn
* Used for service fees

---

## 🧠 Quickstart (Foundry)

### Prerequisites

* Foundry installed (`curl -L https://foundry.paradigm.xyz | bash`)
* `.env` with private key, RPC URL and etherscan api key.
* Fund your account with Sepolia ETH

### Deploy

make deploysepolia
make deployanvil

---

## 🧪 Testing

```bash
forge test -vv
```
---

## 🔒 Security Notes

* **ReentrancyGuard** on fund-handling functions
* Strict caller checks (`onlyAgentController`, `onlyOwner`, etc.)
* Verified pyUSD transfers with revert protection
* Refund lock period (`HOLD_UNTIL`) before cancellation
* **Centralized validation (MVP)** for safety — decentralized reputation coming soon

---

## 🛣️ Roadmap

* ✅ **MVP** — AI agent validates & executes full on-chain flow
* 🔜 **Merchant autonomy** — allow MerchantNft holders to post answers

---

## 📄 License

MIT

---
