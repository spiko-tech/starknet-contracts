use starknet::{ContractAddress};

#[starknet::interface]
pub trait IPermissionManager<TContractState> {
    fn has_role(ref self: TContractState, role: felt252, address: ContractAddress) -> bool;
    fn grant_role(ref self: TContractState, role: felt252, address: ContractAddress);
}

#[starknet::contract]
pub mod PermissionManager {
    use AccessControlComponent::InternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ClassHash, ContractAddress};
    use starknet_contracts::roles::{WHITELISTED_ROLE, WHITELISTER_ROLE};
    use openzeppelin::access::accesscontrol::interface::{IAccessControl, IAccessControlCamel};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.accesscontrol.set_role_admin(WHITELISTED_ROLE, WHITELISTER_ROLE);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl CustomAccessControlImpl of IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            self.accesscontrol.has_role(role, account)
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            self.accesscontrol.get_role_admin(role)
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            self.accesscontrol.grant_role(role, account)
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            self.accesscontrol.revoke_role(role, account)
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            assert!(role != WHITELISTED_ROLE, "Cannot renounce whitelisted role");
            self.accesscontrol.renounce_role(role, account)
        }
    }

    #[abi(embed_v0)]
    impl CustomAccessControlCamelImpl of IAccessControlCamel<ContractState> {
        fn hasRole(self: @ContractState, role: felt252, account: ContractAddress)-> bool {
            self.accesscontrol.hasRole(role, account)
        }

        fn getRoleAdmin(self: @ContractState, role: felt252) -> felt252  {
            self.accesscontrol.getRoleAdmin(role)
        }

        fn grantRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            self.accesscontrol.grantRole(role, account)
        }

        fn revokeRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            self.accesscontrol.revokeRole(role, account)
        }

        fn renounceRole(ref self: ContractState, role: felt252, account: ContractAddress) {
            assert!(role != WHITELISTED_ROLE, "Cannot renounce whitelisted role");
            self.accesscontrol.renounceRole(role, account)
        }
    }
}
