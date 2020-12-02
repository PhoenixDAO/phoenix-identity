pragma solidity ^0.5.0;

interface PhoenixIdentityResolverInterface {
    function callOnAddition() external view returns (bool);
    function callOnRemoval() external view returns (bool);
    function onAddition(uint PHNX_ID, uint allowance, bytes calldata extraData) external returns (bool);
    function onRemoval(uint PHNX_ID, bytes calldata extraData) external returns (bool);
}
