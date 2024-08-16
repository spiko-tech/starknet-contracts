use starknet::ContractAddress;

#[starknet::interface]
pub trait IToken<TContractState> {
    fn mint(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256
    );
    fn balance_of(ref self: TContractState, account: ContractAddress) -> u256;
}

#[starknet::contract]
mod Token {
    use OwnableComponent::InternalTrait;
use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

   // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
	    #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
	#[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name = "Token";
        let symbol = "TK";

        self.erc20.initializer(name, symbol);
	self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn mint(
        ref self: ContractState,
        recipient: ContractAddress,
        amount: u256
    ) {        
        self.ownable.assert_only_owner();
        self.erc20.mint(recipient, amount);
    }
}
