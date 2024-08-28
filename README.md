# Spiko Starknet Contracts

![lint and test](https://github.com/spiko-tech/starknet-contracts/actions/workflows/test.yml/badge.svg)

## Build

Install [Scarb](https://docs.swmansion.com/scarb/) (NOTE: it is
recommended to install Scarb with the [asdf version
manager](https://asdf-vm.com/) and it is **required to use version
2.6.5** as it is the one supported by Starknet at the moment), then
run:

```bash
scarb build
```

## Test

Install [Starknet
Foundry](https://github.com/foundry-rs/starknet-foundry).

Build the contracts, then run:

```bash
snforge test
```

## Deploy

To deploy contracts locally, you can use [Starknet
Devnet](https://0xspaceshard.github.io/starknet-devnet-rs/), which
will also provide pre-funded account contract credentials to declare
and deploy the smart contracts.

First, [setup
sncast](https://foundry-rs.github.io/starknet-foundry/projects/configuration.html#sncast)
by creating a local `snfoundry.toml` file.

Then, declare each contract as follows:

```bash
sncast --profile <YOUR_SNFOUNDRY_PROFILE> declare --package starknet_contracts
--contract-name <CONTRACT_NAME> --fee-token strk
```

Once a contract is declared, use its [class
hash](https://docs.starknet.io/quick-start/declare-a-smart-contract/#expected_result)
to deploy the contract:

```bash
sncast --profile <YOUR_SNFOUNDRY_PROFILE> deploy --class-hash <CONTRACT_CLASS_HASH>
--fee-token strk --constructor-calldata <CONSTRUCTOR_CALLDATA>
```

Constructor data needs to be serialized as [explained in the Starknet
Docs](https://docs.starknet.io/architecture-and-concepts/smart-contracts/serialization-of-cairo-types/).

For example, the
`(0x34ba56f92265f0868c57d3fe72ecab144fc96f97954bbbc4252cef8e8a979ba,
Token, TK, 5)` parameters with type `(ContractAddress, ByteArray,
ByteArray, u8)` would be serialized as:
`0x34ba56f92265f0868c57d3fe72ecab144fc96f97954bbbc4252cef8e8a979ba 0x0
0x546f6b656e 0x5 0x0 0x544b 0x2 0x5`.

The [converter from
Stark-utils](https://stark-utils.vercel.app/converter) might come in
handy.

## Interact

The functions exposed by the contract can be interacted with as
follows - with the calldata serialization built in the same way as
above:

```bash
 sncast --profile account1 invoke --contract-address <CONTRACT_ADDRESS>
 --function "<FUNCTION_NAME>" --calldata <FUNCTION_CALLDATA> --fee-token strk
 ```
