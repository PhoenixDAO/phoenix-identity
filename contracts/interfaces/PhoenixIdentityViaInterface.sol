pragma solidity ^0.5.0;

interface PhoenixIdentityViaInterface {
    function phoenixIdentityCall(address resolver, uint PHNX_ID_From, uint PHNX_ID_To, uint amount, bytes calldata phoenixIdentityCallBytes)
        external;
    function phoenixIdentityCall(
        address resolver, uint PHNX_ID_From, address payable to, uint amount, bytes calldata phoenixIdentityCallBytes
    ) external;
    function phoenixIdentityCall(address resolver, uint PHNX_ID_To, uint amount, bytes calldata phoenixIdentityCallBytes) external;
    function phoenixIdentityCall(address resolver, address payable to, uint amount, bytes calldata phoenixIdentityCallBytes)
        external;
}
