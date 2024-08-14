use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, test_address, start_cheat_caller_address, stop_cheat_caller_address
};
use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};

#[test]
fn complex() {
    let contract = declare("Token").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = ITokenDispatcher { contract_address };
    let spender: ContractAddress = 123.try_into().unwrap();
    dispatcher.mint(spender, 3);
    let spender_balance = dispatcher.balance_of(spender);
    assert(spender_balance == 3, 'invalid spender balance');
}
