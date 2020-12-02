pragma solidity ^0.5.0;

import "../PhoenixIdentityVia.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/PhoenixInterface.sol";
import "../interfaces/PhoenixIdentityInterface.sol";

contract Via is PhoenixIdentityVia {
    PhoenixIdentityInterface private phoenixIdentity;
    PhoenixInterface private phoenixToken;

    constructor (address _phoenixIdentityAddress) PhoenixIdentityVia(_phoenixIdentityAddress) public {
        setPhoenixIdentityAddress(_phoenixIdentityAddress);
    }

    function setPhoenixIdentityAddress(address _phoenixIdentityAddress) public onlyOwner() {
        super.setPhoenixIdentityAddress(_phoenixIdentityAddress);

        phoenixIdentity = PhoenixIdentityInterface(_phoenixIdentityAddress);
        phoenixToken = PhoenixInterface(phoenixIdentity.phoenixTokenAddress());
    }

    // this contract is responsible for funding itself with ETH, and must be entrusted to do so
    function fund() public payable {}

    // PHNX_ID -> ETH balances
    mapping (uint => uint) public balances;

    // a dummy exchange rate between phoenix and ETH s.t. 10 PHOENIX := 1 ETH for testing purposes
    uint exchangeRate = 10;
    function convertPhoenixToEth(uint amount) public view returns (uint) {
        return amount / exchangeRate; // POTENTIALLY UNSAFE - always use SafeMath when not testing
    }

    // end recipient is an PHNX_ID, credit their (ETH) balance
    function phoenixIdentityCall(address, uint, uint PHNX_IDTo, uint amount, bytes memory) public senderIsPhoenixIdentity() {
        creditPHNX_ID(PHNX_IDTo, amount);
    }

    function phoenixIdentityCall(address, uint PHNX_IDTo, uint amount, bytes memory) public senderIsPhoenixIdentity() {
        creditPHNX_ID(PHNX_IDTo, amount);
    }

    function creditPHNX_ID(uint PHNX_IDTo, uint amount) private {
        balances[PHNX_IDTo] += convertPhoenixToEth(amount);
    }

    // end recipient is an address, send them ETH
    function phoenixIdentityCall(address, uint, address payable to, uint amount, bytes memory) public senderIsPhoenixIdentity() {
        creditAddress(to, amount);
    }

    function phoenixIdentityCall(address, address payable to, uint amount, bytes memory) public senderIsPhoenixIdentity() {
        creditAddress(to, amount);
    }

    function creditAddress(address payable to, uint amount) private {
        to.transfer(convertPhoenixToEth(amount));
    }

    // allows phoenixIds with balances to withdraw their accumulated eth balance to an address
    function withdrawTo(address payable to) public {
        IdentityRegistryInterface identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());
        to.transfer(balances[identityRegistry.getPHNX_ID(msg.sender)]);
    }

    // allows the owner to withdraw the contract's accumulated phoenix balance to an address
    function withdrawPhoenixTo(address to) public onlyOwner() {
        require(phoenixToken.transfer(to, phoenixToken.balanceOf(address(this))), "Transfer was unsuccessful");
    }
}
