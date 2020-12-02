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
    function onAddition(uint PHNX_ID, uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        phoenixIdentity.withdrawPhoenixIdentityBalanceFrom(PHNX_ID, owner(), signUpFee);

        statuses[PHNX_ID] = firstStatus;

        emit StatusSignUp(PHNX_ID);

        return true;
    }

    function onRemoval(uint, bytes memory) public senderIsPhoenixIdentity() returns (bool) {}

    function getStatus(uint PHNX_ID) public view returns (string memory) {
        return statuses[PHNX_ID];
    }

    function setStatus(string memory status) public {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        IdentityRegistryInterface identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());

        uint PHNX_ID = identityRegistry.getPHNX_ID(msg.sender);
        require(identityRegistry.isResolverFor(PHNX_ID, address(this)), "The PHNX_ID has not set this resolver.");

        statuses[PHNX_ID] = status;

        emit StatusUpdated(PHNX_ID, status);
    }

    function withdrawFees(address to) public onlyOwner() {
        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        PhoenixInterface phoenix = PhoenixInterface(phoenixIdentity.phoenixTokenAddress());
        withdrawPhoenixBalanceTo(to, phoenix.balanceOf(address(this)));
    }

    event StatusSignUp(uint PHNX_ID);
    event StatusUpdated(uint PHNX_ID, string status);
}
