# Các địa chỉ Web có thể lấy ETH miễn phí

- **Sepolia POW Faucet:** [https://sepolia-faucet.pk910.de/#/]
- **Etherium Sepolia Faucet:** [https://cloud.google.com/application/web3/faucet/ethereum/sepolia]

---

# 🚩 Challenge 1: Decentralized Staking App

This is the first challenge of the Speed Run Ethereum curriculum. The goal is to build a **Decentralized Staking App** (similar to Kickstarter) where users can pool funds together to meet a threshold.

If the threshold is met by the deadline, the funds are sent to an external contract (e.g., to buy a shared asset). If not, users can withdraw their funds.

### 🌟 Live Demo

- **Frontend (Vercel):** [https://challenge-decentralized-staking-six.vercel.app/]

---

## 🚀 Features & Checkpoints Completed

I have successfully completed Checkpoints 1 to 6

---

## 💻 How to Run Locally

1. **Clone the repo & install dependencies:**

```bash
yarn install
```

2. **How to run the code:**

```bash
# CMD 1
yarn chain
```

```bash
# CMD 2
yarn deloy --reset
yarn deloy
```

```bash
# CMD 3
yarn start
```

```bash
yarn account
yarn generate
```

3. **Test in FE:**

Lấy tiền từ Ví - **Wallet** rồi đến **Stacker UI** và kiểm tra **The Contact** mà mình deloy lên.
Hoặc là đi đến **Debug Contact** để có thểm nhiều thông tin và hàm.

Sau đó bạn có thể Stack tiền vào **Stacker Contact**, Nếu đến hạn mà đủ quỹ thì Excute, còn không thì **nhấn Excute rồi Withdraw** để nhận tiền.

---

# 🚩 Challenge 2: 🏵 Token Vendor 🤖

This is the second challenge of the Speed Run Ethereum curriculum. The goal is to build a **Token Vendor** (like a Vending Machine) that handles the buying and selling of your own ERC20 token using ETH.

Users can exchange ETH for tokens and vice versa. It involves handling `approve` patterns for ERC20 transfers and managing contract balances.

### 🌟 Live Demo

- **Frontend (Vercel):** [https://challenge-token-vendor.vercel.app/]

---

## 🚀 Features & Checkpoints Completed

I have successfully completed Checkpoints 1 to 6

- **Alert**:
  Ở Checkpoint 2 nên có đủ ETH để có thể giao dịch. Nếu **Vendor** muốn có token phải lấy từ **Deloyer**, mà trước đó ta phải mint vào Deloyer lẫn Ví Frontend.

---

## 💻 How to Run Locally

1. **Clone the repo & install dependencies:**

```bash
yarn install
```

2. **How to run the code:**

```bash
# CMD 1
yarn chain
```

```bash
# CMD 2
yarn deloy --reset
yarn deloy
```

```bash
# CMD 3
yarn start
```

```bash
yarn account
yarn generate
```

3. **Test in FE:**

Bạn có thể mua Token hoặc là bán Token cho **Vendor**, mọi phương thức đều cần ETH. Sau đó nếu bạn là người **Owner** bạn còn có thể rút tiền từ Vendor về Ví - **Wallet** của mình

---

# 🚩 Challenge 3: 🎲 Dice Game

This is the third challenge of the Speed Run Ethereum curriculum. The goal is to learn about determinism on the blockchain and how to exploit weak randomness to guarantee a win in a gambling contract.

Instead of playing the game manually, you will build an Attacking Contract (RiggedRoll.sol) that predicts the outcome of the dice roll before the transaction is even finalized.

### 🌟 Live Demo

- **Frontend (Vercel):** [https://challenge-dice-game-iota.vercel.app/]

---

## 🚀 Features & Checkpoints Completed

I have successfully completed Checkpoints 1 to 6

---

## 💻 How to Run Locally

1. **Clone the repo & install dependencies:**

```bash
yarn install
```

2. **How to run the code:**

```bash
# CMD 1
yarn chain
```

```bash
# CMD 2
yarn deloy --reset
yarn deloy
```

```bash
# CMD 3
yarn start
```

```bash
yarn account
yarn generate
```

3. **Test in FE:**

Đăng nhập vào Ví - **Wallet** trước, sau đó bạn có thể **Roll the dice** để xem có may mắn không, hoặc có thể kiểm soát nó bằng **Rigger Roll**. Nếu thành công thì bạn sẽ nhận được tiền.

Nhưng mà nếu bạn không phải là chủ của Rigger thì không thể rút tiền thưởng đâu.

---

# 🚩 Challenge 4: ⚖️ Build a DEX

This is the fourth challenge in the Speedrun Ethereum curriculum. The goal is to understand and build a decentralized exchange (DEX) using an Automated Market Maker (AMM) model, similar to Uniswap V2.

Instead of a traditional order book, you will build a smart contract that uses mathematical formulas to facilitate swaps and manage liquidity for the ETH and $BALLOONS (an ERC20 token) pair.

### 🌟 Live Demo

- **Frontend (Vercel):** []

---

## 🚀 Features & Checkpoints Completed

I have successfully completed Checkpoints 1 to 4

- **Alert:**
  Ở Checkpoint 4: Trading 🤝, cần **Aprrove** ở dưới **Ballon** trước khi dùng hàm **tokenToEth**.

---

## 💻 How to Run Locally

1. **Clone the repo & install dependencies:**

```bash
yarn install
```

2. **How to run the code:**

```bash
# CMD 1
yarn chain
```

```bash
# CMD 2
yarn deloy --reset
yarn deloy
```

```bash
# CMD 3
yarn start
```

```bash
yarn account
yarn generate
```

3. **Test in FE:**

---
