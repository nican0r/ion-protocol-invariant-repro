```
,-. .---.  .-. .-.  ,---.  ,---.    .---.  _______  .---.    ,--,  .---.  ,-.     
|(|/ .-. ) |  \| |  | .-.\ | .-.\  / .-. )|__   __|/ .-. ) .' .') / .-. ) | |     
(_)| | |(_)|   | |  | |-' )| `-'/  | | |(_) )| |   | | |(_)|  |(_)| | |(_)| |     
| || | | | | |\  |  | |--' |   (   | | | | (_) |   | | | | \  \   | | | | | |     
| |\ `-' / | | |)|  | |    | |\ \  \ `-' /   | |   \ `-' /  \  `-.\ `-' / | `--.  
`-' )---'  /(  (_)  /(     |_| \)\  )---'    `-'    )---'    \____\)---'  |( __.' 
   (_)    (__)     (__)        (__)(_)             (_)            (_)     (_)     
```

# Ion Protocol
Ion Protocol is a decentralized money market purpose-built for all types of staked and restaked assets. Ion protocol unlocks capital efficiency for yield-bearing staking collaterals using reactive interest rates, collateral-specific utilization, and price-agnostic liquidations. Borrowers can collateralize their yield-bearing staking assets to borrow WETH, and lenders can gain exposure to the boosted staking yield generated by borrower collateral. 

## Documentation 

To learn more about Ion Protocol without code, please visit:
- [Our website](https://ionprotocol.io)
- [User Docs](https://docs.ionprotocol.io)

To learn more about the protocol's technical details, please visit:
- [Audit Docs for Security Researchers](https://ionprotocol.notion.site/Ion-Protocol-Audit-Docs-c871ff178bf54447bd28018cd5a88f75?pvs=74)

## Audits 
> Please report any white hat findings for potential vulnerabilities to security@molecularlabs.io

- OpenZeppelin Audit December 2023
    - [Open Zepplin Audit Report](https://blog.openzeppelin.com/ion-protocol-audit)
- [Hats Finance January 2024](https://app.hats.finance/audit-competitions) 
    - Regular Audit and Formal Verification Competition with Certora
    - [Competition Completed]

## Community

To engage in conversations around Ion Protocol and the staking/restaking ecosystem, please join the [Discord](https://t.co/6np4WvIx70) channel or follow [@ionprotocol](https://twitter.com/ionprotocol) on X. 

## Usage

### Installing Dependencies 

Install Bun 
```shell
curl -fsSL https://bun.sh/install | bash 
```

Run Bun install for javascript dependencies
```shell
bun install
```

Install jq 
```shell
brew install jq 
```

### Environmental Variables 

Copy .env.example to .env and add environmental variables. 

```bash
MAINNET_RPC_URL=https://mainnet.infura.io/v3/
MAINNET_ARCHIVE_RPC_URL= # Archive node used for creating fork environments 
MAINNET_ETHERSCAN_URL=https://api.etherscan.io/api
ETHERSCAN_API_KEY=
RPC_URL= # RPC of the desired testnet used in deployment scripts
```

### Test

1. The test suite includes fork tests that require foundry ffi. 
2. Add RPC_URLs to the .env and run forge test with the --ffi flag. 
```shell
forge test --ffi 
```
### Testnet Setup
1. Set up anvil as a mainnet fork. 
    - For the contracts using mainnet contract addresses as constants to work properly, the testnet needs to be a fork of a mainnet environment. 
    ```bash 
    anvil --fork-url $MAINNET_ARCHIVE_RPC_URL --chain-id 31337
    ```
2. Set anvil as the target RPC for the deployment script in `.env`
    ```bash
    # ...other environmental variables 
    RPC_URL=http://localhost:8545 

    ```
3. Run the testnet deployment script 
    ```bash 
    bash node.sh 
    ```
4. Run the foundry script to verify that the contracts are working properly. 
    ```bash 
    forge script script/__TestFlashLeverage.s.sol --rpc-url $RPC_URL 
    ```

### Format

```bash
$ forge fmt
```
