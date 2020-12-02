pragma solidity ^0.5.0;

import "../PhoenixIdentityResolver.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/PhoenixIdentityInterface.sol";

contract PhoenixKYC is PhoenixIdentityResolver {
    IdentityRegistryInterface identityRegistry;

    constructor (address phoenixIdentityAddress)
        PhoenixIdentityResolver("Phoenix KYC", "Perform KYC through Phoenix.", phoenixIdentityAddress, true, true) public
    {
        setPhoenixIdentityAddress(phoenixIdentityAddress);
    }

    // set the phoenixIdentity address and identity registry contract wrappers
    function setPhoenixIdentityAddress(address phoenixIdentityAddress) public onlyOwner() {
        super.setPhoenixIdentityAddress(phoenixIdentityAddress);

        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());
    }

    // allows identity nodes to declare themselves
    function newIdentityNode (string memory identityNodePlaintext, bytes memory extraData) public {
        bytes32 identityNode = keccak256(abi.encodePacked(msg.sender, identityNodePlaintext));
        emit PhoenixKYCNewIdentityNode(identityNode, msg.sender, identityNodePlaintext, extraData);
    }

    // allows identity nodes to update their extraData
    function updateIdentityNode (string memory identityNodePlaintext, bytes memory extraData) public {
        bytes32 identityNode = keccak256(abi.encodePacked(msg.sender, identityNodePlaintext));
        emit PhoenixKYCUpdateIdentityNode(identityNode, extraData);
    }

    // implement addition function
    function onAddition(uint PHNX_ID, uint, bytes memory extraData) public senderIsPhoenixIdentity() returns (bool) {
        emit PhoenixKYCSignUp(PHNX_ID);
        (bytes32 identityNode) = abi.decode(extraData, (bytes32));
        addIdentityNode(PHNX_ID, identityNode);
        return true;
    }

    // declares an identity node for the sender's PHNX_ID
    function addIdentityNode(bytes32 identityNode) public {
        _addIdentityNode(identityRegistry.getPHNX_ID(msg.sender), identityNode);
    }

    // allows providers to declare an identity node for the sender's PHNX_ID
    function addIdentityNode(uint PHNX_ID, bytes32 identityNode) public {
        require(identityRegistry.isProviderFor(PHNX_ID, msg.sender), "PhoenixIdentity is not a Provider for the passed PHNX_ID.");
        _addIdentityNode(PHNX_ID, identityNode);
    }

    function _addIdentityNode (uint PHNX_ID, bytes32 identityNode) private {
        require(identityRegistry.isResolverFor(PHNX_ID, address(this)), "The PHNX_ID has not set this resolver.");
        emit PhoenixKYCIdentityNodeAdded(PHNX_ID, identityNode);
    }

    // revokes an identity node for the sender's PHNX_ID
    function revokeIdentityNode(bytes32 identityNode) public {
        _revokeIdentityNode(identityRegistry.getPHNX_ID(msg.sender), identityNode);
    }

    // allows providers to revoke an identity node for the sender's PHNX_ID
    function revokeIdentityNode(uint PHNX_ID, bytes32 identityNode) public {
        require(identityRegistry.isProviderFor(PHNX_ID, msg.sender), "PhoenixIdentity is not a Provider for the passed PHNX_ID.");
        _revokeIdentityNode(PHNX_ID, identityNode);
    }

    function _revokeIdentityNode (uint PHNX_ID, bytes32 identityNode) private {
        require(identityRegistry.isResolverFor(PHNX_ID, address(this)), "The PHNX_ID has not set this resolver.");
        emit PhoenixKYCIdentityNodeRevoked(PHNX_ID, identityNode);
    }

    // implement removal function
    function onRemoval(uint PHNX_ID, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        emit PhoenixKYCRemoval(PHNX_ID);
        return true;
    }

    event PhoenixKYCNewIdentityNode(
        bytes32 indexed identityNode, address identityNodeAddress, string identityNodePlaintext, bytes extraData
    );
    event PhoenixKYCUpdateIdentityNode(bytes32 indexed identityNode, bytes extraData);

    event PhoenixKYCSignUp(uint PHNX_ID);
    event PhoenixKYCIdentityNodeAdded(uint indexed PHNX_ID, bytes32 indexed identityNode);
    event PhoenixKYCIdentityNodeRevoked(uint indexed PHNX_ID, bytes32 indexed identityNode);
    event PhoenixKYCRemoval(uint PHNX_ID);
}
