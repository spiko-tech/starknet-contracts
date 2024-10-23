pub mod permission_manager;
pub mod redemption;
pub mod roles;

use starknet::ContractAddress;

#[starknet::interface]
pub trait IToken<TContractState> {
    fn set_permission_manager_contract_address(
        ref self: TContractState, contract_address: ContractAddress
    );
    fn set_redemption_contract_address(ref self: TContractState, contract_address: ContractAddress);
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, amount: u256);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn redeem(ref self: TContractState, amount: u256, salt: felt252);
}

#[starknet::contract]
mod Token {
    use OwnableComponent::InternalTrait;
    use openzeppelin::token::erc20::{ERC20Component};
    use openzeppelin::token::erc20::interface::IERC20Metadata;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::PausableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use starknet_contracts::permission_manager::{
        IPermissionManagerDispatcher, IPermissionManagerDispatcherTrait
    };
    use starknet_contracts::redemption::{IRedemptionDispatcher, IRedemptionDispatcherTrait};
    use starknet_contracts::roles::{MINTER_ROLE, WHITELISTED_ROLE, BURNER_ROLE, PAUSER_ROLE};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        permission_manager_contract_address: ContractAddress,
        redemption_contract_address: ContractAddress,
        decimals: u8,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8
    ) {
        _set_decimals(ref self, decimals);
        self.erc20.initializer(name, symbol);
        self.ownable.initializer(owner);
    }

    #[external(v0)]
    fn set_permission_manager_contract_address(
        ref self: ContractState, contract_address: ContractAddress
    ) {
        self.ownable.assert_only_owner();
        self.permission_manager_contract_address.write(contract_address);
    }

    #[external(v0)]
    fn set_redemption_contract_address(ref self: ContractState, contract_address: ContractAddress) {
        self.ownable.assert_only_owner();
        self.redemption_contract_address.write(contract_address);
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
    fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
        check_address_has_role(ref self, MINTER_ROLE, get_caller_address());
        self.erc20.mint(recipient, amount);
    }

    #[external(v0)]
    fn burn(ref self: ContractState, amount: u256) {
        check_address_has_role(ref self, BURNER_ROLE, get_caller_address());
        self.erc20.burn(get_caller_address(), amount);
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

    #[external(v0)]
    fn redeem(ref self: ContractState, amount: u256, salt: felt252) {
        self.pausable.assert_not_paused();
        let redemption_contract_address = self.redemption_contract_address.read();
        let redemption_dispatcher = IRedemptionDispatcher {
            contract_address: redemption_contract_address
        };
        self.erc20.transfer(redemption_contract_address, amount);
        redemption_dispatcher.on_redeem(get_contract_address(), get_caller_address(), amount, salt);
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = ERC20Component::HasComponent::get_contract_mut(ref self);
            contract_state.pausable.assert_not_paused();
            if from.into() == 0 { // mint
                check_address_has_role(ref contract_state, WHITELISTED_ROLE, recipient);
            } else if recipient.into() == 0 { // burn
                check_address_has_role(ref contract_state, BURNER_ROLE, from);
            } else {
                check_address_has_role(ref contract_state, WHITELISTED_ROLE, from);
                check_address_has_role(ref contract_state, WHITELISTED_ROLE, recipient);
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    fn _set_decimals(ref self: ContractState, decimals: u8) {
        self.decimals.write(decimals);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
