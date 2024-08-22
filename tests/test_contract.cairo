use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, test_address, start_cheat_caller_address, stop_cheat_caller_address
};

use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_contracts::permission_manager::{
    IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
};
use starknet_contracts::redemption::{IRedemptionDispatcher, IRedemptionDispatcherTrait};

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");

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

fn setup_redemption_contract() -> (IRedemptionDispatcher, ContractAddress, ContractAddress) {
    let contract_owner_address: ContractAddress = 001.try_into().unwrap();
    let contract = declare("Redemption").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![contract_owner_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IRedemptionDispatcher { contract_address };
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

#[test]
fn minter_can_redeem() {
    let MINT_AMOUNT = 3;
    let REDEMPTION_SALT = 0;

    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    let (
        redemption_contract_dispatcher,
        redemption_contract_address,
        redemption_contract_owner_address
    ) =
        setup_redemption_contract();

    // set redemption / permission manager contract addresses
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher.grant_role(BURNER_ROLE, redemption_contract_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens + check tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        'invalid owner balance'
    );
    assert(token_contract_dispatcher.total_supply() == MINT_AMOUNT, 'invalid total supply');
    stop_cheat_caller_address(token_contract_address);

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    assert(token_contract_dispatcher.balance_of(receiver_address) == 0, 'invalid owner balance');
    stop_cheat_caller_address(token_contract_address);

    // execute redemption + check tokens are burned
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher
        .execute_redemption(token_contract_address, receiver_address, MINT_AMOUNT, REDEMPTION_SALT);
    stop_cheat_caller_address(redemption_contract_address);
    assert(token_contract_dispatcher.total_supply() == 0, 'invalid total supply');
}
