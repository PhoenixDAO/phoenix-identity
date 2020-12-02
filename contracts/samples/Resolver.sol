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
    function onAddition(uint PHNX_ID, uint allowance, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        require(allowance >= 2000000000000000000, "Must set an allowance of >=2 PHOENIX.");
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(PHNX_ID, address(this), allowance / 2);
        return true;
    }

    // implement removal function
    function onRemoval(uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {}

    // example function to test allowAndCall
    function transferPhoenixIdentityBalanceFromAllowAndCall(uint PHNX_IDFrom, uint PHNX_IDTo, uint amount) public {
        require(identityRegistry.isProviderFor(PHNX_IDFrom, msg.sender));
        phoenixIdentity.transferPhoenixIdentityBalanceFrom(PHNX_IDFrom, PHNX_IDTo, amount);
    }

    // example functions to test *From token functions
    function transferPhoenixIdentityBalanceFrom(uint PHNX_IDTo, uint amount) public {
        phoenixIdentity.transferPhoenixIdentityBalanceFrom(identityRegistry.getPHNX_ID(msg.sender), PHNX_IDTo, amount);
    }

    function withdrawPhoenixIdentityBalanceFrom(address to, uint amount) public {
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(identityRegistry.getPHNX_ID(msg.sender), to, amount);
    }

    function transferPhoenixIdentityBalanceFromVia(address via, uint PHNX_IDTo, uint amount) public {
        phoenixIdentity.transferPhoenixIdentityBalanceFromVia(identityRegistry.getPHNX_ID(msg.sender), via, PHNX_IDTo, amount, hex"");
    }

    function withdrawPhoenixIdentityBalanceFromVia(address via, address to, uint amount) public {
        phoenixIdentity.withdrawPhoenixIdentityBalanceFromVia(identityRegistry.getPHNX_ID(msg.sender), via, to, amount, hex"");
    }

    // example functions to test *To token functions
    function _transferPhoenixBalanceTo(uint PHNX_IDTo, uint amount) public onlyOwner {
        transferPhoenixBalanceTo(PHNX_IDTo, amount);
    }

    function _withdrawPhoenixBalanceTo(address to, uint amount) public onlyOwner {
        withdrawPhoenixBalanceTo(to, amount);
    }

    function _transferPhoenixBalanceToVia(address via, uint PHNX_IDTo, uint amount) public onlyOwner {
        transferPhoenixBalanceToVia(via, PHNX_IDTo, amount, hex"");
    }

    function _withdrawPhoenixBalanceToVia(address via, address to, uint amount) public onlyOwner {
        withdrawPhoenixBalanceToVia(via, to, amount, hex"");
    }
}
