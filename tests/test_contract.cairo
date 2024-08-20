use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, test_address, start_cheat_caller_address, stop_cheat_caller_address
};

use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_contracts::permission_manager::{
    IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
};

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");

fn setup_permission_manager_contract() -> (
    IPermissionManagerDispatcher, ContractAddress, ContractAddress
) {
    let contract_admin_address: ContractAddress = 000.try_into().unwrap();
    let contract = declare("PermissionManager").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![contract_admin_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IPermissionManagerDispatcher { contract_address };
    (dispatcher, contract_address, contract_admin_address)
}

fn setup_token_contract() -> (ITokenDispatcher, ContractAddress, ContractAddress) {
    let contract_owner_address: ContractAddress = 001.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![contract_owner_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    (dispatcher, contract_address, contract_owner_address)
}

#[test]
fn minter_can_mint_token() {
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    stop_cheat_caller_address(permission_manager_contract_address);
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, 3);
    stop_cheat_caller_address(token_contract_address);
    let owner_balance = token_contract_dispatcher.balance_of(receiver_address);
    assert(owner_balance == 3, 'invalid');
}

#[should_panic]
#[test]
fn non_minter_can_not_mint_token() {
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        _permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        _permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, 3);
}

#[test]
fn pauser_can_pause_token() {
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    let pauser_address: ContractAddress = 002.try_into().unwrap();
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(PAUSER_ROLE, pauser_address);
    stop_cheat_caller_address(permission_manager_contract_address);
    start_cheat_caller_address(token_contract_address, pauser_address);
    token_contract_dispatcher.pause();
}

#[should_panic]
#[test]
fn non_pauser_can_not_pause_token() {
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        _permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        _permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    let pauser_address: ContractAddress = 002.try_into().unwrap();
    start_cheat_caller_address(token_contract_address, pauser_address);
    token_contract_dispatcher.pause();
}

#[should_panic(expected: ('Pausable: paused',))]
#[test]
fn minter_can_not_mint_token_if_paused() {
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    let pauser_address: ContractAddress = 004.try_into().unwrap();
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher.grant_role(PAUSER_ROLE, pauser_address);
    stop_cheat_caller_address(permission_manager_contract_address);
    start_cheat_caller_address(token_contract_address, pauser_address);
    token_contract_dispatcher.pause();
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, 3);
    let owner_balance = token_contract_dispatcher.balance_of(receiver_address);
    assert(owner_balance == 3, 'invalid');
}
