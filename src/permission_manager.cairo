const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");

use starknet::ContractAddress;

#[starknet::interface]
pub trait IPermissionManager<TContractState> {
    fn has_role(ref self: TContractState, role: felt252, address: ContractAddress) -> bool;
    fn grant_role(ref self: TContractState, role: felt252, address: ContractAddress);
}

#[starknet::contract]
pub mod PermissionManager {
    use openzeppelin_access::accesscontrol::interface::IAccessControl;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component;

    use starknet::ContractAddress;

    use super::{MINTER_ROLE, PAUSER_ROLE};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}
