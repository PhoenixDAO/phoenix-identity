pragma solidity ^0.5.0;

interface OldClientPhoenixAuthenticationInterface {
    function userNameTaken(string calldata userName) external view returns (bool);
    function getUserByName(string calldata userName) external view returns (string memory, address);
}