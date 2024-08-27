use starknet::{ContractAddress};

#[derive(Drop, Hash)]
struct RedemptionData {
    token: ContractAddress,
    from: ContractAddress,
    amount: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
enum RedemptionStatus {
    Null,
    Pending,
    Executed,
    Canceled
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct RedemptionDetails {
    status: RedemptionStatus,
    deadline: u64,
}

#[starknet::interface]
pub trait IRedemption<TContractState> {
    fn on_redeem(
        ref self: TContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    );
    fn execute_redemption(
        ref self: TContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    );
    fn cancel_redemption(
        ref self: TContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    );
    fn set_token_contract_address(ref self: TContractState, contract_address: ContractAddress);
}

#[starknet::contract]
mod Redemption {
    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_block_timestamp};
    use core::dict::Felt252Dict;
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token_contract_address: ContractAddress,
        redemption_details: LegacyMap::<felt252, super::RedemptionDetails>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn set_token_contract_address(ref self: ContractState, contract_address: ContractAddress) {
        self.ownable.assert_only_owner();
        self.token_contract_address.write(contract_address);
    }

    fn hash_redemption_data(
        token: ContractAddress, from: ContractAddress, amount: u256, salt: felt252
    ) -> felt252 {
        let redemption_data = super::RedemptionData { token, from, amount };
        PedersenTrait::new(salt).update_with(redemption_data).finalize()
    }

    #[external(v0)]
    fn on_redeem(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let redemption_details = super::RedemptionDetails {
            status: super::RedemptionStatus::Pending, deadline: get_block_timestamp()
        };
        self.redemption_details.write(redemption_data_hash, redemption_details);
    }

    #[external(v0)]
    fn execute_redemption(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        self.ownable.assert_only_owner();
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let mut redemption_data = self
            .redemption_details
            .read(redemption_data_hash); // does read panic if data is not there ?
        let dispatcher = ITokenDispatcher { contract_address: self.token_contract_address.read() };
        dispatcher.burn(amount);
        redemption_data.status = super::RedemptionStatus::Executed;
        self.redemption_details.write(redemption_data_hash, redemption_data);
    }

    #[external(v0)]
    fn cancel_redemption(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        self.ownable.assert_only_owner();
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let mut redemption_data = self.redemption_details.read(redemption_data_hash);
        let dispatcher = ITokenDispatcher { contract_address: self.token_contract_address.read() };
        dispatcher.transfer(from, amount);
        redemption_data.status = super::RedemptionStatus::Canceled;
        self.redemption_details.write(redemption_data_hash, redemption_data);
    }
}
