pragma solidity ^0.5.0;

import "../PhoenixIdentityResolver.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/PhoenixIdentityInterface.sol";


contract Resolver is PhoenixIdentityResolver {
    PhoenixIdentityInterface private phoenixIdentity;
    IdentityRegistryInterface private identityRegistry;

    constructor (address phoenixIdentityAddress)
        PhoenixIdentityResolver("Sample Resolver", "This is a sample PhoenixIdentity resolver.", phoenixIdentityAddress, true, true)
        public
    {
        setPhoenixIdentityAddress(phoenixIdentityAddress);
    }

    // set the phoenixIdentity address, and phoenix token + identity registry contract wrappers
    function setPhoenixIdentityAddress(address phoenixIdentityAddress) public onlyOwner() {
        super.setPhoenixIdentityAddress(phoenixIdentityAddress);
        phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());
    }

    // implement signup function
    function onAddition(uint ein, uint allowance, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        require(allowance >= 2000000000000000000, "Must set an allowance of >=2 PHOENIX.");
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(ein, address(this), allowance / 2);
        return true;
    }

    // implement removal function
    function onRemoval(uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {}

    // example function to test allowAndCall
    function transferPhoenixIdentityBalanceFromAllowAndCall(uint einFrom, uint einTo, uint amount) public {
        require(identityRegistry.isProviderFor(einFrom, msg.sender));
        phoenixIdentity.transferPhoenixIdentityBalanceFrom(einFrom, einTo, amount);
    }

    // example functions to test *From token functions
    function transferPhoenixIdentityBalanceFrom(uint einTo, uint amount) public {
        phoenixIdentity.transferPhoenixIdentityBalanceFrom(identityRegistry.getEIN(msg.sender), einTo, amount);
    }

    function withdrawPhoenixIdentityBalanceFrom(address to, uint amount) public {
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(identityRegistry.getEIN(msg.sender), to, amount);
    }

    function transferPhoenixIdentityBalanceFromVia(address via, uint einTo, uint amount) public {
        phoenixIdentity.transferPhoenixIdentityBalanceFromVia(identityRegistry.getEIN(msg.sender), via, einTo, amount, hex"");
    }

    function withdrawPhoenixIdentityBalanceFromVia(address via, address to, uint amount) public {
        phoenixIdentity.withdrawPhoenixIdentityBalanceFromVia(identityRegistry.getEIN(msg.sender), via, to, amount, hex"");
    }

    // example functions to test *To token functions
    function _transferPhoenixBalanceTo(uint einTo, uint amount) public onlyOwner {
        transferPhoenixBalanceTo(einTo, amount);
    }

    function _withdrawPhoenixBalanceTo(address to, uint amount) public onlyOwner {
        withdrawPhoenixBalanceTo(to, amount);
    }

    function _transferPhoenixBalanceToVia(address via, uint einTo, uint amount) public onlyOwner {
        transferPhoenixBalanceToVia(via, einTo, amount, hex"");
    }

    function _withdrawPhoenixBalanceToVia(address via, address to, uint amount) public onlyOwner {
        withdrawPhoenixBalanceToVia(via, to, amount, hex"");
    }
}
