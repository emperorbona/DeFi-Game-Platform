# 🎲 DeFi Game Platform

A decentralized gaming platform starting with a **provably fair on-chain Dice Game**, built on the Avalanche Fuji Testnet and powered by Chainlink VRF for secure randomness.

This project demonstrates how on-chain games can be transparent, trustless, and fun—while integrating DeFi mechanics such as staking and automated payouts.

---

## ✨ Features

### Dice Game

* **Stake & Play**: Two players stake AVAX (minimum \$1 USD equivalent) and roll virtual dice.
* **Provably Fair Randomness**: Chainlink VRF generates unbiased dice rolls.
* **Automated Payouts**: Winners are paid instantly from the GameWallet smart contract.
* **Dynamic Game Fee**: 3% standard fee, 5% for higher-pot games.

### GameWallet

* **Per-User Balances**: Each player deposits AVAX into their own balance inside the contract.
* **Secure Fund Handling**: Supports deposits, withdrawals, and fund locking during active games.
* **Access Control**: Only approved game contracts can deduct stakes.

### AdminWallet

* **Fee Collection**: Receives game fees and stores them securely.
* **Role-Based Access**: Uses OpenZeppelin AccessControl for admin permissions.
* **Flexible Management**: Owner can withdraw or update settings when needed.

---

## 🏽️ Architecture

```
Players <-> GameWallet <-> DiceGame
                          |
                       Chainlink VRF
                          |
                       AdminWallet (collects fees)
```

* **DiceGame.sol** – Core gameplay logic, VRF randomness, fee handling.
* **GameWallet.sol** – Manages user deposits, stakes, and winnings.
* **AdminWallet.sol** – Stores and manages platform fees.
* **PriceConverter.sol** – Chainlink price feeds to enforce minimum \$1 stakes.

---

## 🚀 Deployment

1. **Clone the repo**

   ```bash
   git clone https://github.com/<your-username>/defi-game-platform.git
   cd defi-game-platform
   ```

2. **Install dependencies**

   ```bash
   forge install
   ```

3. **Set environment variables**
   Create a `.env` file and set:

   ```
   PRIVATE_KEY=<your-wallet-key>
   RPC_URL=<avalanche-fuji-rpc>
   VRF_COORDINATOR=<chainlink-vrf-coordinator>
   LINK_TOKEN=<link-token-address>
   KEY_HASH=<vrf-keyhash>
   SUBSCRIPTION_ID=<chainlink-sub-id>
   ```

4. **Deploy**

   ```bash
   forge script script/diceGameDeploy/DeployDiceGame.s.sol --broadcast --verify
   ```

---

## 🧪 Testing

Unit and integration tests are written with **Foundry**.

```bash
forge test
```

Tests include:

* Game creation and joining
* VRF randomness fulfillment
* Winnings distribution
* AdminWallet fee collection and withdrawals
* Edge cases for deposits/withdrawals

---

## 🛠️ Tech Stack

* **Solidity ^0.8.20**
* **Foundry** (Forge & Cast)
* **Chainlink VRF & Price Feeds**
* **OpenZeppelin AccessControl & ReentrancyGuard**
* **Avalanche Fuji Testnet**

---

## 🗺️ Roadmap

* [x] Core Dice Game with VRF randomness
* [x] GameWallet and AdminWallet contracts
* [x] Dynamic fee structure
* [ ] Frontend UI with wallet connection
* [ ] Multi-game support (chess, tic-tac-toe, etc.)
* [ ] Mainnet deployment and audit

---

## 🤝 Contributing

Pull requests are welcome!
If you’d like to join as a developer or collaborator, open an issue or reach out.

---

## 📜 License

MIT License © 2025 \Bonaventure Edetan
