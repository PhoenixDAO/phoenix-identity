pragma solidity ^0.5.0;

import "../PhoenixIdentityResolver.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/PhoenixInterface.sol";
import "../interfaces/PhoenixIdentityInterface.sol";

contract Status is PhoenixIdentityResolver {
    mapping (uint => string) private statuses;

    uint signUpFee = 1000000000000000000;
    string firstStatus = "My first status 😎";

    constructor (address phoenixIdentityAddress)
        PhoenixIdentityResolver("Status", "Set your status.", phoenixIdentityAddress, true, false) public
    {}

    // implement signup function
    function onAddition(uint ein, uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(ein, owner(), signUpFee);

        statuses[ein] = firstStatus;

        emit StatusSignUp(ein);

        return true;
    }

    function onRemoval(uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {}

    function getStatus(uint ein) public view returns (string memory) {
        return statuses[ein];
    }

    function setStatus(string memory status) public {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        IdentityRegistryInterface identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());

        uint ein = identityRegistry.getEIN(msg.sender);
        require(identityRegistry.isResolverFor(ein, address(this)), "The EIN has not set this resolver.");

        statuses[ein] = status;

        emit StatusUpdated(ein, status);
    }

    function withdrawFees(address to) public onlyOwner() {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        PhoenixInterface phoenix = PhoenixInterface(phoenixIdentity.phoenixTokenAddress());
        withdrawPhoenixBalanceTo(to, phoenix.balanceOf(address(this)));
    }

    event StatusSignUp(uint ein);
    event StatusUpdated(uint ein, string status);
}
