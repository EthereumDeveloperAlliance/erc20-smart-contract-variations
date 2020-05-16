# ERC20 Smart Contract Example

A small collection of various ERC20 smart contract examples for the Ethereum blockchain.

- Standard
- Certificate
- Fee

### Standard Token

A barebones ERC20 token smart contract.

### Certificate Token

A ERC20 token smart contract with unique "certificate" properties. A certificate can be generated and issued by "token minters" which allows issuance of tokens using the `mint` functionality and requiring the receipient of tokens to pay the gas tokens

#### Unique Features

- Receipient pays gas costs for receiving tokens.

### Certificate Token

A ERC20 token smart contract with unique fee properties. The smart contract emulates functionality found in the Tether ERC20 smart contract, which includes the ability to add a fees for transfering tokens.

#### Unique Features

- Adds fee to token transfers.

## Deploy

The smart contracts can be deployed using a number of different methods. To continue to interact with the deployed smart contracts we recommend using the OpenZeppelin CLI

Setup the project using the OpenZeppelin CLI to easily interact with deployed contracts directly from the CLI.

### Open Zeppelin

```.sh
$ oz init
$ oz deploy
```

### Truffle

```.sh
$ truffle compile
$ truffle deploy --network [NETWORK]
```

## Send Transactions

If the contracts are deployed using the OpenZeppelin CLI you can continue to interact with contracts using several CLI commands.

```
$ oz call
$ oz send-tx
```

## Contributors

| Name               | Website                      |
| ------------------ | ---------------------------- |
| **Kames Geraghty** | <https://github.com/kamescg> |
| **Joe Bernitt**    | <https://github.com/joeb000> |

## License

[MIT](LICENSE) © [Ethereum Developer Alliance](https://github.com/EthereumDeveloperAlliance)
