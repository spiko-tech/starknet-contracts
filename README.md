# Spiko Starknet Contracts

![lint and test](https://github.com/spiko-tech/starknet-contracts/actions/workflows/test.yml/badge.svg)
[![codecov](https://codecov.io/github/spiko-tech/starknet-contracts/graph/badge.svg?token=311N4K6AM3)](https://codecov.io/github/spiko-tech/starknet-contracts)

## Installation

- Install Rust
- Install asdf
- Install Scarb with the correct version (see [Scarb.toml](Scarb.toml))
- Install Starknet Foundry and Universal Sierra Compiler
- Create a file `snfoundry.toml`
- Create a dev account on Sepolia with `sncast account create --name <YOUR_NAME_ACCOUNT> --add-profile spiko-dev --url <STARKNET_SEPOLIA_RPC_URL>` - this will create a new profile in `snfoundry.toml`

## Introduction

### Overview of Smart Contracts

This repository contains three interrelated smart contracts
that collectively manage tokenized shares of a fund,
facilitating minting, redemption, and permission control:

1. **`lib.cairo`**: An ERC-20 token contract representing
   shares in a fund.
2. **`redemption.cairo`**: Manages the redemption process
   for users selling their shares back to the fund.
3. **`permission_manager.cairo`**: Handles role-based access
   control across the contracts, using roles defined in
   `roles.cairo`.

### Detailed Descriptions

#### `lib.cairo` (Token Contract)

**Purpose**: Implements an ERC-20 token that symbolizes
ownership shares in a fund.

**Key Features**:

- **Minting Tokens**: Tokens are minted to whitelisted users
  when they purchase shares.
- **Transfer Restrictions**: Enforces transfer limitations
  to comply with regulatory requirements, allowing transfers
  only between whitelisted addresses.
- **Redemption Initiation**: Provides a `redeem` function
  enabling users to initiate the redemption process by
  transferring tokens to the `redemption.cairo` contract.
- **Role Management**: Integrates with the
  `permission_manager.cairo` contract to verify roles like
  `MINTER`, `BURNER`, and `PAUSER`.

#### `redemption.cairo` (Redemption Contract)

**Purpose**: Oversees the redemption of tokens when users
wish to sell their fund shares back.

**Workflow**:

1. **Initiation**:

   - Users call the `redeem` function in `lib.cairo`,
     transferring their tokens to the `redemption.cairo`
     contract.
   - The `redemption.cairo` contract logs the redemption
     request and sets its status to `Pending`.

2. **Execution or Cancellation**:
   - An authorized external operator with the
     `REDEMPTION_EXECUTOR_ROLE` can:
     - **Execute Redemption**: Burns the tokens held in the
       `redemption.cairo` contract, finalizing the
       redemption.
     - **Cancel Redemption**: Transfers the tokens back to
       the user, canceling the redemption.

**Security Measures**:

- **Status Verification**: Each redemption request has a
  status (`Pending`, `Executed`, or `Canceled`) to prevent
  duplicate processing.
- **Unique Identifiers**: Redemptions are tracked using
  unique hashes derived from redemption data to avoid
  collisions.
- **Role Enforcement**: Only operators with specific roles
  can execute or cancel redemptions.

#### `permission_manager.cairo` (Permission Manager Contract)

**Purpose**: Manages roles and permissions across the token
and redemption contracts.

**Functionality**:

- **Role Definitions**: Establishes roles such as `MINTER`,
  `BURNER`, `WHITELISTER`, `WHITELISTED`,
  `REDEMPTION_EXECUTOR`, and `PAUSER`.
- **Role Assignment**: Allows the contract owner or
  designated administrators to grant or revoke roles to
  addresses.
- **Access Control**: Enforces role-based permissions,
  ensuring that only authorized addresses can perform
  sensitive operations.

**Integration**:

- Both `lib.cairo` and `redemption.cairo` consult the
  `permission_manager.cairo` contract to verify permissions
  before executing critical functions.

### Role Definitions (`roles.cairo`)

- **`MINTER_ROLE`**: Permission to mint new tokens.
- **`BURNER_ROLE`**: Permission to burn tokens.
- **`WHITELISTER_ROLE`**: Can assign the `WHITELISTED_ROLE`
  to addresses.
- **`WHITELISTED_ROLE`**: Allows an address to hold and
  transfer tokens.
- **`REDEMPTION_EXECUTOR_ROLE`**: Authorized to execute or
  cancel redemptions.
- **`PAUSER_ROLE`**: Can pause or unpause token transfers.

## Build

Install [Scarb](https://docs.swmansion.com/scarb/) (NOTE: it is
recommended to install Scarb with the [asdf version
manager](https://asdf-vm.com/):

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

To generate a test coverage `.lcov` file ,
install [cairo-coverage](https://github.com/software-mansion/cairo-coverage)
then run:

```bash
snforge test --coverage
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
