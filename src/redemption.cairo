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
    fn on_transfer_received(
        ref self: TContractState, token: ContractAddress, from: ContractAddress, amount: u256
    );
}

#[starknet::contract]
mod Redemption {
    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::{ContractAddress, get_block_timestamp};
    use core::dict::Felt252Dict;
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use starknet::storage::Map;
    use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token_contract_address: ContractAddress,
        redemption_details: Map::<felt252, super::RedemptionDetails>,
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

    fn hash_redemption_data(
        token: ContractAddress, from: ContractAddress, amount: u256
    ) -> felt252 {
        let redemption_data = super::RedemptionData { token, from, amount };
        PedersenTrait::new(0).update_with(redemption_data).finalize()
    }

    #[external(v0)]
    fn on_transfer_received(
        ref self: ContractState, token: ContractAddress, from: ContractAddress, amount: u256
    ) {
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount);
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
        to: ContractAddress,
        amount: u256
    ) {
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount);
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
        to: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount);
        let mut redemption_data = self.redemption_details.read(redemption_data_hash);
        let dispatcher = ITokenDispatcher { contract_address: self.token_contract_address.read() };
        dispatcher.transfer(from, amount);
        redemption_data.status = super::RedemptionStatus::Canceled;
        self.redemption_details.write(redemption_data_hash, redemption_data);
    }
}
