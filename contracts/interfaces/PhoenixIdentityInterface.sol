pragma solidity ^0.5.0;

interface PhoenixIdentityInterface {
    function deposits(uint) external view returns (uint);
    function resolverAllowances(uint, address) external view returns (uint);

    function identityRegistryAddress() external returns (address);
    function phoenixTokenAddress() external returns (address);
    function clientPhoenixAuthenticationAddress() external returns (address);

    function setAddresses(address _identityRegistryAddress, address _phoenixTokenAddress) external;
    function setClientPhoenixAuthenticationAddress(address _clientPhoenixAuthenticationAddress) external;

    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, string calldata casedPhoenixId,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint PHNX_ID);
    function addProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function removeProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function upgradeProvidersFor(
        address approvingAddress, address[] calldata newProviders, address[] calldata oldProviders,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function addResolver(address resolver, bool isPhoenixIdentity, uint withdrawAllowance, bytes calldata extraData) external;
    function addResolverAsProvider(
        uint PHNX_ID, address resolver, bool isPhoenixIdentity, uint withdrawAllowance, bytes calldata extraData
    ) external;
    function addResolverFor(
        address approvingAddress, address resolver, bool isPhoenixIdentity, uint withdrawAllowance, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function changeResolverAllowances(address[] calldata resolvers, uint[] calldata withdrawAllowances) external;
    function changeResolverAllowancesDelegated(
        address approvingAddress, address[] calldata resolvers, uint[] calldata withdrawAllowances,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function removeResolver(address resolver, bool isPhoenixIdentity, bytes calldata extraData) external;
    function removeResolverFor(
        address approvingAddress, address resolver, bool isPhoenixIdentity, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;

    function triggerRecoveryAddressChangeFor(
        address approvingAddress, address newRecoveryAddress, uint8 v, bytes32 r, bytes32 s
    ) external;

    function transferPhoenixIdentityBalance(uint PHNX_IDTo, uint amount) external;
    function withdrawPhoenixIdentityBalance(address to, uint amount) external;
    function transferPhoenixIdentityBalanceFrom(uint PHNX_IDFrom, uint PHNX_IDTo, uint amount) external;
    function withdrawPhoenixIdentityBalanceFrom(uint PHNX_IDFrom, address to, uint amount) external;
    function transferPhoenixIdentityBalanceFromVia(uint PHNX_IDFrom, address via, uint PHNX_IDTo, uint amount, bytes calldata _bytes)
        external;
    function withdrawPhoenixIdentityBalanceFromVia(uint PHNX_IDFrom, address via, address to, uint amount, bytes calldata _bytes)
        external;
}
