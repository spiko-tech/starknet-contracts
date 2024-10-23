use starknet::{ContractAddress, ClassHash};
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

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
    fn set_permission_manager_contract_address(
        ref self: TContractState, contract_address: ContractAddress
    );
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[derive(Drop, Hash, Serde, starknet::Event)]
pub struct RedemptionData {
    pub token: ContractAddress,
    pub from: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct RedemptionInitiated {
    #[key]
    pub hash: felt252,
    pub data: RedemptionData
}

#[derive(Drop, starknet::Event)]
pub struct RedemptionExecuted {
    #[key]
    pub hash: felt252,
    pub data: RedemptionData
}

#[derive(Drop, starknet::Event)]
pub struct RedemptionCanceled {
    #[key]
    pub hash: felt252,
    pub data: RedemptionData
}

pub fn hash_redemption_data(
    token: ContractAddress, from: ContractAddress, amount: u256, salt: felt252
) -> felt252 {
    let redemption_data = RedemptionData { token, from, amount };
    PedersenTrait::new(salt).update_with(redemption_data).finalize()
}

#[starknet::contract]
pub mod Redemption {
    use OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use starknet_contracts::{ITokenDispatcher, ITokenDispatcherTrait};
    use starknet_contracts::permission_manager::{
        IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
    };
    use starknet_contracts::roles::{REDEMPTION_EXECUTOR_ROLE};
    use super::{
        RedemptionData, RedemptionInitiated, RedemptionCanceled, RedemptionExecuted,
        hash_redemption_data
    };
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry,
        StorageMapReadAccess
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
    enum RedemptionStatus {
        #[default]
        Null,
        Pending,
        Executed,
        Canceled
    }

    #[storage]
    struct Storage {
        token_contract_address: ContractAddress,
        permission_manager_contract_address: ContractAddress,
        redemption_statuses: Map::<felt252, RedemptionStatus>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RedemptionInitiated: RedemptionInitiated,
        RedemptionExecuted: RedemptionExecuted,
        RedemptionCanceled: RedemptionCanceled,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
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

    #[external(v0)]
    fn set_permission_manager_contract_address(
        ref self: ContractState, contract_address: ContractAddress
    ) {
        self.ownable.assert_only_owner();
        self.permission_manager_contract_address.write(contract_address);
    }

    #[external(v0)]
    fn on_redeem(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        assert!(
            get_caller_address() == self.token_contract_address.read(),
            "Caller should be token contract"
        );
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let redemption_statuses =  RedemptionStatus::Pending;
        let existing_redemption = self.redemption_statuses.read(redemption_data_hash);
        assert!(existing_redemption == RedemptionStatus::Null, "Redemption already exists");
        self.redemption_statuses.entry(redemption_data_hash).write(redemption_statuses);
        self
            .emit(
                RedemptionInitiated {
                    hash: redemption_data_hash, data: RedemptionData { token, from, amount }
                }
            );
    }

    fn check_address_has_role(ref self: ContractState, role: felt252, address: ContractAddress) {
        let permission_manager_dispatcher = IPermissionManagerDispatcher {
            contract_address: self.permission_manager_contract_address.read()
        };
        if !permission_manager_dispatcher.has_role(role, address) {
            panic!("Wrong role: role should be {}", role)
        };
    }

    #[external(v0)]
    fn execute_redemption(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        check_address_has_role(ref self, REDEMPTION_EXECUTOR_ROLE, get_caller_address());
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let mut redemption_status = self.redemption_statuses.entry(redemption_data_hash).read();
        assert!(redemption_status == RedemptionStatus::Pending, "Redemption is not pending");
        redemption_status = RedemptionStatus::Executed;
        self.redemption_statuses.entry(redemption_data_hash).write(redemption_status);
        let dispatcher = ITokenDispatcher { contract_address: self.token_contract_address.read() };
        dispatcher.burn(amount);
        self
            .emit(
                RedemptionExecuted {
                    hash: redemption_data_hash, data: RedemptionData { token, from, amount }
                }
            );
    }

    #[external(v0)]
    fn cancel_redemption(
        ref self: ContractState,
        token: ContractAddress,
        from: ContractAddress,
        amount: u256,
        salt: felt252
    ) {
        check_address_has_role(ref self, REDEMPTION_EXECUTOR_ROLE, get_caller_address());
        let redemption_data_hash: felt252 = hash_redemption_data(token, from, amount, salt);
        let mut redemption_status = self.redemption_statuses.entry(redemption_data_hash).read();
        assert!(redemption_status == RedemptionStatus::Pending, "Redemption is not pending");
        redemption_status = RedemptionStatus::Canceled;
        self.redemption_statuses.entry(redemption_data_hash).write(redemption_status);
        let dispatcher = ITokenDispatcher { contract_address: self.token_contract_address.read() };
        dispatcher.transfer(from, amount);
        self
            .emit(
                RedemptionCanceled {
                    hash: redemption_data_hash, data: RedemptionData { token, from, amount }
                }
            );
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
