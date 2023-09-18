# DeFi: Indian Rupee Stablecoin (INRC)

A DeFi Stablecoin project using
1. Foundry
2. Chainlink Feeds
3. Formal Verification with **Branching Tree Technique (BTT)**: See [Testing Overview](#testing-overview) for more details on Testing.

<hr/>

- [DeFi: Indian Rupee Stablecoin](#defi-indian-rupee-stablecoin-inrc)
- [Tasklist](#tasklist)
- [Getting Started](#getting-started)
    - [Characteristics](#characteristics)
    - [Process Overview](#process-overview)
    - [Testing Overview](#testing-overview)
        - [Methodology](#methodology)
        - [Coverage](#coverage)
        - [Forked Testnet Testing](#forked-testnet-testing)
- [Development](#development)
    - [Requirements](#requirements)
    - [Quickstart](#quickstart)
    - [Formatting](#formatting)
- [Usage](#usage)
    - [Start a local node](#start-a-local-node)
    - [Library](#library)
    - [Deploy](#deploy)
    - [Deploy - Other Network](#deploy---other-network)
    - [Testing](#testing)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
    - [Process](#process)
    - [Estimate gas](#estimate-gas)


## Tasklist
- [x] Foundry Project Dockerized Setup
- [x] INRC ERC20 Contract
- [x] **INRCEngine**
    - [x] Deposit & Minting
    - [x] Redeem Collateral
    - [x] Burn INRC
    - [x] Liquidate
    - [x] Helper Functions
- [x] Scripts
    - [x] BaseScript
    - [x] ~~INRC~~ *(Not really needed)*
    - [x] INRCEngine
    - [ ] Interactions (if needed)
- [x] Testing: Formal Verification with BTT
    - [x] ~~BaseScript~~
        - [x] ~~Broadcast~~ *(Requires rewriting to accomodate function params instead of environment variables update)*
    - [x] **INRCEngine**
        - [x] Constructor
        - [x] Deposit Collateral
        - [x] Mint INRC
        - [x] Redeem Collateral
        - [x] Burn INRC
        - [x] Liquidate
        - [ ] Helper Functions
            - [x] getINRValueOf
            - [x] getINRValueOfCollateralFor
            - [ ] getTknCxEquivalentOfINRC
            - [ ] Getters
                - [x] getCollateralDepositedBy
                - [ ] getINRCMintedBy
                - [ ] getHealthFactor
    - [ ] INRC
- [x] Makefile
- [x] README
- [ ] Generalize to make it **Any Currency stablecoin** *(Requires nomenclature update. Already works perfectly as JPY coin in Sepolia tests)*

## Getting Started

### Characteristics
1. Relative Stability: *Pegged* or *Floating*?
    - **Pegged** to ₹ (INR) => 1.00 INRC = ₹ 1.00
2. Stability Method: *Governed* or *Algorithmic*?
    - **Algorithmic (Decentralized)**
3. Collateral Type: *Endogenous* or *Exogenous*?
    - **Exogenous (Crypto)**
        - wETH
        - wBTC

### Process Overview
- Chainlink Price Feeds are used to get us ETH & BTC equivalent of USD($) and subsequently INR(₹).
- Users with enough collateral can mint stablecoin.
- Users are incentivized to liquidate under-collateralized users.

## Testing Overview

### Methodology

In this project, we use Formal Verification using **Branching Tree Technique (BTT)**

The focus is on the following Foundry test categories:

1. Unit Testing: Functions involving a single contract
2. Integration Testing: Functions involving a multiple contracts
3. Invariant Testing: Expressions that always hold true
4. Fork Testing: Tests running against a production chain

using Foundry's test-subcategories:
1. Concrete Testing: Standard deterministic tests the takes no inputs
2. Fuzz Testing: Non-deterministic tests that takes fuzzed inputs


### Coverage

| File                                  | % Lines         | % Statements     | % Branches     | % Funcs        |
|---------------------------------------|-----------------|------------------|----------------|----------------|
| src/INRC.sol                          | 100.00% (3/3)   | 100.00% (3/3)    | 100.00% (0/0)  | 100.00% (2/2)  |
| src/INRCEngine.sol                    | 89.04% (65/73)  | 92.31% (96/104)  | 81.82% (18/22) | 89.47% (17/19) |


### Forked Testnet Testing

The test suites use JPY price feed on Sepolia Testnet as Chainlink doesn't offer INR Price Feeds on Sepolia.

> Update the current currency rates (`WETH_JPY_PRICE`, etc.) in `INRCEngine.t.sol` at the time of running forked tests. An update is likely to be good for a couple of hours. Tests have a built-in tolerance of handling upto 1% change in price and still pass.


## Development

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

### Quickstart

```shell
git clone https://github.com/shobhit-gupta/IndianRupeeStablecoin
cd IndianRupeeStablecoin
make build
```

### Formatting

To run code formatting:

```shell
make fmt
```


## Usage

### Start a local node

```shell
make anvil
```

### Library

If you're having a hard time installing the libraries, you can optionally run this command.

```shell
make install
```

### Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```shell
make deploy
```

### Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

### Testing

Generally you'll want to set private keys for test users (`ADMIN`, `ALICE`, `BOB` & `EVE`) as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`. All of these users might not be used. For instance, this project doesn't make use of `EVE` so far. **NOTE:** FOR DEVELOPMENT, PLEASE USE KEYS THAT DON'T HAVE ANY REAL FUNDS ASSOCIATED WITH THEM.

```shell
forge test -vvv
```

or

```shell
source .env
forge test -vvv --fork-url $SEPOLIA_RPC_URL
```

```shell
make coverage
```

## Deployment to a testnet or mainnet

### Process

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` & `MAINNET_RPC_URL` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with.
- `MAINNET_RPC_URL`:  This is url of the mainnet node you're working with.

You can get setup with these for free from [Alchemy](https://www.alchemy.com)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).


2. Get testnet ETH
Head over to [faucets.chain.link](https://faucets.chain.link/) or [sepoliafaucet.com](https://sepoliafaucet.com) and get some testnet ETH. You should see the ETH show up in your metamask.


3. Deploy

```shell
make deploy ARGS="--network sepolia"
```

### Estimate gas

You can estimate how much gas things cost by running:

```shell
make snapshot
```

And you'll see an output file called `.gas-snapshot`

