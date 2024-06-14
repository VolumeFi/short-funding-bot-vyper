# GMX Short Funding Bot

This project implements a smart contract system for GMX short funding bot, designed to interact with short order of GMX protocol. It includes a blueprint contract that will be deployed and owned by each user, and a factory contract to interact. The contracts are written in Vyper.


## Overview

The factory contract serves multiple purposes:

- It allows users to deposit funds and create new bots with specific parameters tailored to their trading strategies.
- It provides mechanisms for repaying bots.
- It offers functions to query the state and health of individual bots, enabling users to monitor their investments.

## Contract Functions

### `deposit`

This function is used to create a new bot, place a short order on the GMX protocol, and execute an exchange based on the specified parameters.

- **Parameters:**
  - `user` (address): The Ethereum address of the user who is creating the bot and depositing funds.
  - `amount0` (uint256): The amount of the first token being deposited into the bot for trading.
  - `order_params` (CreateOrderParams): A structured data type containing all necessary parameters to create a short order on the GMX protocol.
  - `swap_min_amount` (uint256): The minimum acceptable amount of tokens to be received from the swap operation.

### `withdraw`

This function withdraws funds from the specified bot contract.

- **Parameters:**
  - `bot` (address): The address of the bot contract.
  - `amount0` (uint256): The amount of funds to withdraw.
  - `order_params` (CreateOrderParams): The parameters for creating the order.
  - `swap_min_amount` (uint256): The minimum amount of tokens to get from swap.

### `withdraw_and_end_bot`

This function withdraws funds from the specified bot contract and ends it.

- **Parameters:**
  - `bot` (address): The address of the bot contract.
  - `amount0` (uint256): The amount of funds to withdraw.
  - `order_params` (CreateOrderParams): The parameters for creating the order.
  - `markets` (address[]): swap path in GMX.
  - `expected_token` (address): The token address to get from withdrawing.
  - `swap_min_amount` (uint256): The minimum amount of tokens to get from swap.

### `end_bot`

This function withdraws funds from the specified bot contract and ends it.

- **Parameters:**
  - `bot` (address): The address of the bot contract.
  - `markets` (address[]): swap path in GMX.
  - `expected_token` (address): The token address to get from withdrawing.
  - `swap_min_amount` (uint256): The minimum amount of tokens to get from swap.

## Events

### `BotDeployed`

This event is emitted when new bot contract deployed.

- **Parameters:**
  - `owner` (address): The address of the bot owner.
  - `bot` (address): The address of the bot contract.

### `Deposited`

This event is emitted when a new order deposited.

- **Parameters:**
  - `bot` (address): The address of the bot contract.
  - `amount0` (uint256): The address of the bot owner.
  - `order_params` (CreateOrderParams): The parameters for creating the order for deposit.

### `Withdrawn`

This event is emitted when an order withdrawn.

- **Parameters:**
  - `bot` (address): The address of the bot contract.
  - `amount0` (uint256): The address of the bot owner.
  - `order_params` (CreateOrderParams): The parameters for creating the order for withdraw.

### `Ended`

This event is emitted when a bot ended.

- **Parameters:**
  - `bot` (address): The address of the bot contract.

## Conclusion

The `factory.vy` contract is a foundational element of the GMX short funding bot system, enabling users to engage with the GMX protocol in a secure and efficient manner. Through its comprehensive set of functions, it provides users with the tools necessary to manage their trading strategies effectively.