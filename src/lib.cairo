pub mod permission_manager;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IToken<TContractState> {
    fn set_permission_manager_contract_address(
        ref self: TContractState, contract_address: ContractAddress
    );
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn balance_of(ref self: TContractState, account: ContractAddress) -> u256;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}

#[starknet::contract]
mod Token {
    use OwnableComponent::InternalTrait;

    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::PausableComponent;

    use starknet::ContractAddress;
    use starknet::get_caller_address;

    use starknet_contracts::permission_manager::{
        IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
    };


    const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
    const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);


    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        permission_manager_contract_address: ContractAddress,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name = "Token";
        let symbol = "TK";

        self.erc20.initializer(name, symbol);
        self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn set_permission_manager_contract_address(
        ref self: ContractState, contract_address: ContractAddress
    ) {
        self.permission_manager_contract_address.write(contract_address);
    }

    fn check_address_has_role(ref self: ContractState, role: felt252, address: ContractAddress) {
        let permission_manager_dispatcher = IPermissionManagerDispatcher {
            contract_address: self.permission_manager_contract_address.read()
        };
        if !permission_manager_dispatcher.has_role(role, address) {
            panic!("Wrong role")
        };
    }

    #[external(v0)]
    fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
        check_address_has_role(ref self, MINTER_ROLE, get_caller_address());
        self.pausable.assert_not_paused();
        self.erc20.mint(recipient, amount);
    }

    #[external(v0)]
    fn pause(ref self: ContractState) {
        check_address_has_role(ref self, PAUSER_ROLE, get_caller_address());
        self.pausable.pause();
    }

    #[external(v0)]
    fn unpause(ref self: ContractState) {
        check_address_has_role(ref self, PAUSER_ROLE, get_caller_address());
        self.pausable.unpause();
    }
}
