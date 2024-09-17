use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address, spy_events,
    EventSpyAssertionsTrait, DeclareResult, DeclareResultTrait
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_contracts::permission_manager::{
    IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
};
use starknet_contracts::redemption::{
    Redemption, IRedemptionDispatcher, IRedemptionDispatcherTrait, RedemptionData,
    RedemptionInitiated, RedemptionExecuted, RedemptionCanceled, hash_redemption_data
};
use starknet_contracts::roles::{
    MINTER_ROLE, WHITELISTED_ROLE, WHITELISTER_ROLE, BURNER_ROLE, PAUSER_ROLE,
    REDEMPTION_EXECUTOR_ROLE
};
use openzeppelin::token::erc20::{ERC20Component};
use openzeppelin::security::PausableComponent;

const MINT_AMOUNT: u256 = 3;
const REDEMPTION_SALT: felt252 = 0;
const TOKEN_DECIMALS: u8 = 5;

fn setup_permission_manager_contract() -> (
    IPermissionManagerDispatcher, ContractAddress, ContractAddress
) {
    let contract_admin_address: ContractAddress = 000.try_into().unwrap();
    let contract = declare("PermissionManager").unwrap().contract_class();
    let mut constructor_calldata: Array::<felt252> = array![contract_admin_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IPermissionManagerDispatcher { contract_address };
    (dispatcher, contract_address, contract_admin_address)
}

fn setup_token_contract() -> (ITokenDispatcher, ContractAddress, ContractAddress) {
    let contract_owner_address: ContractAddress = 001.try_into().unwrap();
    let contract = declare("Token").unwrap().contract_class();
    let mut constructor_calldata: Array::<felt252> = array![contract_owner_address.into()];
    let token_name: ByteArray =
        "MyToken"; // would like to reuse constant but can't have ByteArray constants ...
    let token_symbol: ByteArray = "TK";
    let decimals: u8 = TOKEN_DECIMALS;
    constructor_calldata.append_serde(token_name);
    constructor_calldata.append_serde(token_symbol);
    constructor_calldata.append_serde(decimals);
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    (dispatcher, contract_address, contract_owner_address)
}

fn setup_redemption_contract() -> (IRedemptionDispatcher, ContractAddress, ContractAddress) {
    let contract_owner_address: ContractAddress = 001.try_into().unwrap();
    let contract = declare("Redemption").unwrap().contract_class();
    let mut constructor_calldata: Array::<felt252> = array![contract_owner_address.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = IRedemptionDispatcher { contract_address };
    (dispatcher, contract_address, contract_owner_address)
}

#[test]
fn can_upgrade_token_contract() {
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    if let DeclareResult::Success(new_class_hash) = declare("Redemption")
        .unwrap() { // would need to upgrade with a contract that has the same interface to be more realistic
        token_contract_dispatcher.upgrade(new_class_hash.class_hash);
    } else {
        panic!("Class declaration failed");
    }
}

#[test]
fn can_upgrade_permission_manager_contract() {
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    if let DeclareResult::Success(new_class_hash) = declare("Token").unwrap() { // same here
        permission_manager_contract_dispatcher.upgrade(new_class_hash.class_hash);
    } else {
        panic!("Class declaration failed");
    }
}

#[test]
fn can_upgrade_redemption_contract() {
    let (
        redemption_contract_dispatcher,
        redemption_contract_address,
        redemption_contract_owner_address
    ) =
        setup_redemption_contract();
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    if let DeclareResult::Success(new_class_hash) = declare("PermissionManager")
        .unwrap() { // same here
        redemption_contract_dispatcher.upgrade(new_class_hash.class_hash);
    } else {
        panic!("Class declaration failed");
    }
}

#[test]
fn can_set_name_symbol_and_decimals() {
    let (token_contract_dispatcher, _token_contract_address, _token_contract_owner_address) =
        setup_token_contract();
    let token_name = token_contract_dispatcher.name();
    let token_symbol = token_contract_dispatcher.symbol();
    let token_decimals = token_contract_dispatcher.decimals();
    assert!(token_name == "MyToken", "Wrong token name");
    assert!(token_symbol == "TK", "Wrong token symbol");
    assert!(token_decimals == TOKEN_DECIMALS, "Wrong token decimals");
}

#[test]
fn minter_whitelisted_by_whitelister_can_mint_token() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    let mut spy = spy_events();

    // set contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    let whitelister_address: ContractAddress = 004.try_into().unwrap();

    // grant minter / whitelister roles
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTER_ROLE, whitelister_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // grant whitelisted role from whitelister
    start_cheat_caller_address(permission_manager_contract_address, whitelister_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    stop_cheat_caller_address(token_contract_address);

    // check minting event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: 0.try_into().unwrap(), to: receiver_address, value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    let owner_balance = token_contract_dispatcher.balance_of(receiver_address);
    assert!(owner_balance == MINT_AMOUNT, "Invalid balance");
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
}

// role should be whitelisted
#[should_panic(
    expected: "Wrong role: role should be 73912596405270985899152466852138375248387282755116208396838325475458431817"
)]
#[test]
fn minter_not_whitelisted_by_whitelister_can_not_mint_token() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    // set contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // grant minter / whitelister roles
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
}

// role should be minter
#[should_panic(
    expected: "Wrong role: role should be 1438109952812144829738888816133633444252201913124473511188290282179550336678"
)]
#[test]
fn non_minter_can_not_mint_token() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        _permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        _permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    // set permission manager contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // mint tokens
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    stop_cheat_caller_address(token_contract_address);
}

#[test]
fn pauser_can_pause_token() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    let mut spy = spy_events();

    // set permission manager contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let pauser_address: ContractAddress = 002.try_into().unwrap();

    // grant pauser role
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(PAUSER_ROLE, pauser_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // pause contract
    start_cheat_caller_address(token_contract_address, pauser_address);
    token_contract_dispatcher.pause();
    stop_cheat_caller_address(token_contract_address);

    // check minting event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    PausableComponent::Event::Paused(
                        PausableComponent::Paused { account: pauser_address }
                    )
                )
            ]
        );
}

// role should be pauser
#[should_panic(
    expected: "Wrong role: role should be 833306884038677809637860575724506334387531562138252562269278794760766457386"
)]
#[test]
fn non_pauser_can_not_pause_token() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        _permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        _permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    // set permission manager contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let pauser_address: ContractAddress = 002.try_into().unwrap();

    // pause contract
    start_cheat_caller_address(token_contract_address, pauser_address);
    token_contract_dispatcher.pause();
    stop_cheat_caller_address(token_contract_address);
}

#[should_panic(expected: ('Pausable: paused',))]
#[test]
fn minter_can_not_mint_token_if_paused() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
        setup_token_contract();
    let (
        permission_manager_contract_dispatcher,
        permission_manager_contract_address,
        permission_manager_contract_admin_address
    ) =
        setup_permission_manager_contract();

    // set permission manager contract address
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(token_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    let pauser_address: ContractAddress = 004.try_into().unwrap();

    // grant roles via permission manager
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
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    let receiver_balance = token_contract_dispatcher.balance_of(receiver_address);
    assert!(receiver_balance == MINT_AMOUNT, "Invalid balance");
    stop_cheat_caller_address(token_contract_address);
}

#[test]
fn minter_can_redeem_with_redemption_executed_by_executor() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
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

    let mut spy = spy_events();

    // set redemption / permission manager contract addresses
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);
    redemption_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(redemption_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    let redemption_executor_address: ContractAddress = 004.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher.grant_role(BURNER_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTER_ROLE, permission_manager_contract_admin_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTED_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    permission_manager_contract_dispatcher
        .grant_role(REDEMPTION_EXECUTOR_ROLE, redemption_executor_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens + check tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
    stop_cheat_caller_address(token_contract_address);

    // check minting event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: 0.try_into().unwrap(), to: receiver_address, value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    assert!(token_contract_dispatcher.balance_of(receiver_address) == 0, "Invalid owner balance");
    assert!(
        token_contract_dispatcher.balance_of(redemption_contract_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    stop_cheat_caller_address(token_contract_address);

    // check redemption initiated event
    spy
        .assert_emitted(
            @array![
                (
                    redemption_contract_address,
                    Redemption::Event::RedemptionInitiated(
                        RedemptionInitiated {
                            data: RedemptionData {
                                token: token_contract_address,
                                from: receiver_address,
                                amount: MINT_AMOUNT
                            },
                            hash: hash_redemption_data(
                                token_contract_address,
                                receiver_address,
                                MINT_AMOUNT,
                                REDEMPTION_SALT
                            )
                        }
                    )
                )
            ]
        );

    // check transfer to redemption contract event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: receiver_address,
                            to: redemption_contract_address,
                            value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    // execute redemption + check tokens are burned
    start_cheat_caller_address(redemption_contract_address, redemption_executor_address);
    redemption_contract_dispatcher
        .execute_redemption(token_contract_address, receiver_address, MINT_AMOUNT, REDEMPTION_SALT);
    stop_cheat_caller_address(redemption_contract_address);

    // check redemption executed event
    spy
        .assert_emitted(
            @array![
                (
                    redemption_contract_address,
                    Redemption::Event::RedemptionExecuted(
                        RedemptionExecuted {
                            data: RedemptionData {
                                token: token_contract_address,
                                from: receiver_address,
                                amount: MINT_AMOUNT
                            },
                            hash: hash_redemption_data(
                                token_contract_address,
                                receiver_address,
                                MINT_AMOUNT,
                                REDEMPTION_SALT
                            )
                        }
                    )
                )
            ]
        );

    // check burning event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: redemption_contract_address,
                            to: 0.try_into().unwrap(),
                            value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    assert!(token_contract_dispatcher.total_supply() == 0, "Invalid total supply");
}

// role should be redemption executor
#[should_panic(
    expected: "Wrong role: role should be 1755078849743812584117181869573714026665097150780435520223569283416289084708"
)]
#[test]
fn non_executor_can_not_execute_redemption() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
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
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);
    redemption_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(redemption_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher.grant_role(BURNER_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTER_ROLE, permission_manager_contract_admin_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTED_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens + check tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
    stop_cheat_caller_address(token_contract_address);

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    assert!(token_contract_dispatcher.balance_of(receiver_address) == 0, "Invalid owner balance");
    assert!(
        token_contract_dispatcher.balance_of(redemption_contract_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    stop_cheat_caller_address(token_contract_address);

    redemption_contract_dispatcher
        .execute_redemption(token_contract_address, receiver_address, MINT_AMOUNT, REDEMPTION_SALT);
}

#[test]
fn minter_can_redeem_with_redemption_canceled_by_executor() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
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

    let mut spy = spy_events();

    // set redemption / permission manager contract addresses
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);
    redemption_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(redemption_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();
    let redemption_executor_address: ContractAddress = 004.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTER_ROLE, permission_manager_contract_admin_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTED_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    permission_manager_contract_dispatcher
        .grant_role(REDEMPTION_EXECUTOR_ROLE, redemption_executor_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens + check tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
    stop_cheat_caller_address(token_contract_address);

    // check minting event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: 0.try_into().unwrap(), to: receiver_address, value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    assert!(token_contract_dispatcher.balance_of(receiver_address) == 0, "Invalid owner balance");
    assert!(
        token_contract_dispatcher.balance_of(redemption_contract_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    stop_cheat_caller_address(token_contract_address);

    // check redemption initiated event
    spy
        .assert_emitted(
            @array![
                (
                    redemption_contract_address,
                    Redemption::Event::RedemptionInitiated(
                        RedemptionInitiated {
                            data: RedemptionData {
                                token: token_contract_address,
                                from: receiver_address,
                                amount: MINT_AMOUNT
                            },
                            hash: hash_redemption_data(
                                token_contract_address,
                                receiver_address,
                                MINT_AMOUNT,
                                REDEMPTION_SALT
                            )
                        }
                    )
                )
            ]
        );

    // check transfer to redemption contract event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: receiver_address,
                            to: redemption_contract_address,
                            value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    // execute redemption + check tokens are burned
    start_cheat_caller_address(redemption_contract_address, redemption_executor_address);
    redemption_contract_dispatcher
        .cancel_redemption(token_contract_address, receiver_address, MINT_AMOUNT, REDEMPTION_SALT);
    stop_cheat_caller_address(redemption_contract_address);

    // check redemption canceled event
    spy
        .assert_emitted(
            @array![
                (
                    redemption_contract_address,
                    Redemption::Event::RedemptionCanceled(
                        RedemptionCanceled {
                            data: RedemptionData {
                                token: token_contract_address,
                                from: receiver_address,
                                amount: MINT_AMOUNT
                            },
                            hash: hash_redemption_data(
                                token_contract_address,
                                receiver_address,
                                MINT_AMOUNT,
                                REDEMPTION_SALT
                            )
                        }
                    )
                )
            ]
        );

    // check transfer back event
    spy
        .assert_emitted(
            @array![
                (
                    token_contract_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: redemption_contract_address,
                            to: receiver_address,
                            value: MINT_AMOUNT
                        }
                    )
                )
            ]
        );

    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
}

// role should be redemption executor
#[should_panic(
    expected: "Wrong role: role should be 1755078849743812584117181869573714026665097150780435520223569283416289084708"
)]
#[test]
fn non_executor_can_not_cancel_redemption() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
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
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);
    redemption_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(redemption_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTER_ROLE, permission_manager_contract_admin_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTED_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens + check tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == MINT_AMOUNT, "Invalid total supply");
    stop_cheat_caller_address(token_contract_address);

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    assert!(token_contract_dispatcher.balance_of(receiver_address) == 0, "Invalid owner balance");
    assert!(
        token_contract_dispatcher.balance_of(redemption_contract_address) == MINT_AMOUNT,
        "Invalid owner balance"
    );
    stop_cheat_caller_address(token_contract_address);

    // execute redemption + check tokens are burned
    redemption_contract_dispatcher
        .cancel_redemption(token_contract_address, receiver_address, MINT_AMOUNT, REDEMPTION_SALT);
}

#[should_panic(expected: "Redemption already exists")]
#[test]
fn cant_initiate_redemption_with_same_arguments() {
    // deploy contracts
    let (token_contract_dispatcher, token_contract_address, token_contract_owner_address) =
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
    start_cheat_caller_address(token_contract_address, token_contract_owner_address);
    token_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    token_contract_dispatcher.set_redemption_contract_address(redemption_contract_address);
    stop_cheat_caller_address(token_contract_address);
    start_cheat_caller_address(redemption_contract_address, redemption_contract_owner_address);
    redemption_contract_dispatcher.set_token_contract_address(token_contract_address);
    redemption_contract_dispatcher
        .set_permission_manager_contract_address(permission_manager_contract_address);
    stop_cheat_caller_address(redemption_contract_address);

    let minter_address: ContractAddress = 002.try_into().unwrap();
    let receiver_address: ContractAddress = 003.try_into().unwrap();

    // grant roles via permission manager
    start_cheat_caller_address(
        permission_manager_contract_address, permission_manager_contract_admin_address
    );
    permission_manager_contract_dispatcher.grant_role(MINTER_ROLE, minter_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTER_ROLE, permission_manager_contract_admin_address);
    permission_manager_contract_dispatcher
        .grant_role(WHITELISTED_ROLE, redemption_contract_address);
    permission_manager_contract_dispatcher.grant_role(WHITELISTED_ROLE, receiver_address);
    stop_cheat_caller_address(permission_manager_contract_address);

    // mint tokens twice (so end of test doesn't fail because of insufficient balance) + check
    // tokens have been minted
    start_cheat_caller_address(token_contract_address, minter_address);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    token_contract_dispatcher.mint(receiver_address, MINT_AMOUNT);
    assert!(
        token_contract_dispatcher.balance_of(receiver_address) == 2 * MINT_AMOUNT,
        "Invalid owner balance"
    );
    assert!(token_contract_dispatcher.total_supply() == 2 * MINT_AMOUNT, "Invalid total supply");
    stop_cheat_caller_address(token_contract_address);

    // redeem tokens + check tokens have been transferred
    start_cheat_caller_address(token_contract_address, receiver_address);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
    token_contract_dispatcher.redeem(MINT_AMOUNT, REDEMPTION_SALT);
}

