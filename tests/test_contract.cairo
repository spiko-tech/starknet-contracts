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

#[should_panic(expected: ('Caller is not the owner', ))]
#[test]
fn non_owner_can_not_mint_token() {
    let owner: ContractAddress = 123.try_into().unwrap();
    let contract = declare("Token").unwrap();
    let mut constructor_calldata: Array::<felt252> = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    dispatcher.mint(owner, 3);
}
