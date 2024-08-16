use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, test_address, start_cheat_caller_address, stop_cheat_caller_address
};
use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};

#[test]
fn owner_can_mint_token() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 3);
    let owner_balance = dispatcher.balance_of(owner);
    assert(owner_balance == 3, 'invalid owner balance');
}

#[should_panic(expected: ('Caller is not the owner',))]
#[test]
fn non_owner_can_not_mint_token() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    dispatcher.mint(owner, 3);
}

#[test]
fn owner_can_pause_token_if_non_null_balance() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1);
    dispatcher.pause();
}

#[should_panic(expected: ('Caller is not the owner',))]
#[test]
fn non_owner_can_not_pause_token() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    dispatcher.pause();
}

#[should_panic(expected: ('Caller is not the owner',))]
#[test]
fn non_owner_can_not_unpause_token() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.pause();
    stop_cheat_caller_address(contract_address);
    dispatcher.unpause();
}

#[should_panic(expected: ('Pausable: not paused',))]
#[test]
fn owner_can_not_unpause_token_if_non_null_balance_and_token_not_paused() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1);
    dispatcher.unpause();
}

#[test]
fn owner_can_unpause_token_if_non_null_balance_and_token_paused() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1);
    dispatcher.pause();
    dispatcher.unpause();
}

#[should_panic(expected: ('Pausable: paused',))]
#[test]
fn owner_can_not_mint_token_if_paused() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1);
    dispatcher.pause();
    dispatcher.mint(owner, 1);
}

#[test]
fn owner_can_mint_token_if_paused_and_unpaused() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, 1);
    dispatcher.pause();
    dispatcher.unpause();
    dispatcher.mint(owner, 1);
    let owner_balance = dispatcher.balance_of(owner);
    assert(owner_balance == 2, 'invalid owner balance');
}
