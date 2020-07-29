pragma solidity ^0.5.0;

import "../SnowflakeVia.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/PhoenixInterface.sol";
import "../interfaces/SnowflakeInterface.sol";

contract Via is SnowflakeVia {
    SnowflakeInterface private snowflake;
    PhoenixInterface private phoenixToken;

    constructor (address _snowflakeAddress) SnowflakeVia(_snowflakeAddress) public {
        setSnowflakeAddress(_snowflakeAddress);
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);

        snowflake = SnowflakeInterface(_snowflakeAddress);
        phoenixToken = PhoenixInterface(snowflake.phoenixTokenAddress());
    }

    // this contract is responsible for funding itself with ETH, and must be entrusted to do so
    function fund() public payable {}

    // EIN -> ETH balances
    mapping (uint => uint) public balances;

    // a dummy exchange rate between phoenix and ETH s.t. 10 PHOENIX := 1 ETH for testing purposes
    uint exchangeRate = 10;
    function convertPhoenixToEth(uint amount) public view returns (uint) {
        return amount / exchangeRate; // POTENTIALLY UNSAFE - always use SafeMath when not testing
    }

    // end recipient is an EIN, credit their (ETH) balance
    function snowflakeCall(address, uint, uint einTo, uint amount, bytes memory) public senderIsSnowflake() {
        creditEIN(einTo, amount);
    }

    function snowflakeCall(address, uint einTo, uint amount, bytes memory) public senderIsSnowflake() {
        creditEIN(einTo, amount);
    }

    function creditEIN(uint einTo, uint amount) private {
        balances[einTo] += convertPhoenixToEth(amount);
    }

    // end recipient is an address, send them ETH
    function snowflakeCall(address, uint, address payable to, uint amount, bytes memory) public senderIsSnowflake() {
        creditAddress(to, amount);
    }

    function snowflakeCall(address, address payable to, uint amount, bytes memory) public senderIsSnowflake() {
        creditAddress(to, amount);
    }

    function creditAddress(address payable to, uint amount) private {
        to.transfer(convertPhoenixToEth(amount));
    }

    // allows phoenixIds with balances to withdraw their accumulated eth balance to an address
    function withdrawTo(address payable to) public {
        IdentityRegistryInterface identityRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
        to.transfer(balances[identityRegistry.getEIN(msg.sender)]);
    }

    // allows the owner to withdraw the contract's accumulated phoenix balance to an address
    function withdrawPhoenixTo(address to) public onlyOwner() {
        require(phoenixToken.transfer(to, phoenixToken.balanceOf(address(this))), "Transfer was unsuccessful");
    }
}
