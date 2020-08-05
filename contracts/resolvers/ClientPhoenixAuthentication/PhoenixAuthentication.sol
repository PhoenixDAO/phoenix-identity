pragma solidity ^0.5.0;

import "./StringUtils.sol";
import "./OldClientPhoenixAuthenticationInterface.sol";
import "../../PhoenixIdentityResolver.sol";
import "../../interfaces/IdentityRegistryInterface.sol";
import "../../interfaces/PhoenixInterface.sol";
import "../../interfaces/PhoenixIdentityInterface.sol";

contract ClientPhoenixAuthentication is PhoenixIdentityResolver {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;

    // other SCs
    PhoenixInterface private phoenixToken;
    IdentityRegistryInterface private identityRegistry;
    OldClientPhoenixAuthenticationInterface private oldClientPhoenixAuthentication;

    // staking requirements
    uint public phoenixStakeUser;
    uint public phoenixStakeDelegatedUser;

    // User account template
    struct User {
        uint ein;
        address _address;
        string casedPhoenixID;
        bool initialized;
        bool destroyed;
    }

    // Mapping from uncased phoenixID hashes to users
    mapping (bytes32 => User) private userDirectory;
    // Mapping from EIN to uncased phoenixID hashes
    mapping (uint => bytes32) private einDirectory;
    // Mapping from address to uncased phoenixID hashes
    mapping (address => bytes32) private addressDirectory;

    constructor(
        address phoenixIdentityAddress, address oldClientPhoenixAuthenticationAddress, uint _phoenixStakeUser, uint _phoenixStakeDelegatedUser
    )
        PhoenixIdentityResolver(
            "Client PhoenixAuthentication", "A registry that links EINs to PhoenixIDs to power Client PhoenixAuthentication MFA.",
            phoenixIdentityAddress,
            true, true
        )
        public
    {
        setPhoenixIdentityAddress(phoenixIdentityAddress);
        setOldClientPhoenixAuthenticationAddress(oldClientPhoenixAuthenticationAddress);
        setStakes(_phoenixStakeUser, _phoenixStakeDelegatedUser);
    }

    // Requires an address to have a minimum number of phoenix
    modifier requireStake(address _address, uint stake) {
        require(phoenixToken.balanceOf(_address) >= stake, "Insufficient staked Phoenix balance.");
        _;
    }

    // set the phoenixIdentity address, and phoenix token + identity registry contract wrappers
    function setPhoenixIdentityAddress(address phoenixIdentityAddress) public onlyOwner() {
        super.setPhoenixIdentityAddress(phoenixIdentityAddress);

        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(phoenixIdentityAddress);
        phoenixToken = PhoenixInterface(phoenixIdentity.phoenixTokenAddress());
        identityRegistry = IdentityRegistryInterface(phoenixIdentity.identityRegistryAddress());
    }

    // set the old client PhoenixAuthentication address
    function setOldClientPhoenixAuthenticationAddress(address oldClientPhoenixAuthenticationAddress) public onlyOwner() {
        oldClientPhoenixAuthentication = OldClientPhoenixAuthenticationInterface(oldClientPhoenixAuthenticationAddress);
    }

    // set minimum phoenix balances required for sign ups
    function setStakes(uint _phoenixStakeUser, uint _phoenixStakeDelegatedUser) public onlyOwner() {
        // <= the airdrop amount
        require(_phoenixStakeUser <= 222222 * 10**18, "Stake is too high.");
        phoenixStakeUser = _phoenixStakeDelegatedUser;

        // <= 1% of total supply
        require(_phoenixStakeDelegatedUser <= phoenixToken.totalSupply() / 100, "Stake is too high.");
        phoenixStakeDelegatedUser = _phoenixStakeDelegatedUser;
    }

    // function for users calling signup for themselves
    function signUp(address _address, string memory casedPhoenixId) public requireStake(msg.sender, phoenixStakeUser) {
        _signUp(identityRegistry.getEIN(msg.sender), casedPhoenixId, _address);
    }

    // function for users signing up through the phoenixIdentity provider
    function onAddition(uint ein, uint, bytes memory extraData)
        // solium-disable-next-line security/no-tx-origin
        public senderIsPhoenixIdentity() requireStake(tx.origin, phoenixStakeDelegatedUser) returns (bool)
    {
        (address _address, string memory casedPhoenixID) = abi.decode(extraData, (address, string));
        require(identityRegistry.isProviderFor(ein, msg.sender), "PhoenixIdentity is not a Provider for the passed EIN.");
        _signUp(ein, casedPhoenixID, _address);
     
        return true;
    }

    // Common internal logic for all user signups
    function _signUp(uint ein, string memory casedPhoenixID, address _address) internal {
        require(bytes(casedPhoenixID).length > 2 && bytes(casedPhoenixID).length < 33, "PhoenixID has invalid length.");
        require(identityRegistry.isResolverFor(ein, address(this)), "The passed EIN has not set this resolver.");
        require(
            identityRegistry.isAssociatedAddressFor(ein, _address),
            "The passed address is not associated with the calling Identity."
        );
        checkForOldPhoenixID(casedPhoenixID, _address);

        bytes32 uncasedPhoenixIDHash = keccak256(abi.encodePacked(casedPhoenixID.toSlice().copy().toString().lower()));
        // check conditions specific to this resolver
        require(phoenixIDAvailable(uncasedPhoenixIDHash), "PhoenixID is unavailable.");
        require(einDirectory[ein] == bytes32(0), "EIN is already mapped to a PhoenixID.");
        require(addressDirectory[_address] == bytes32(0), "Address is already mapped to a PhoenixID.");

        // update mappings
        userDirectory[uncasedPhoenixIDHash] = User(ein, _address, casedPhoenixID, true, false);
        einDirectory[ein] = uncasedPhoenixIDHash;
        addressDirectory[_address] = uncasedPhoenixIDHash;

        emit PhoenixIDClaimed(ein, casedPhoenixID, _address);
    }

    function checkForOldPhoenixID(string memory casedPhoenixID, address _address) public view {
        bool usernameTaken = oldClientPhoenixAuthentication.userNameTaken(casedPhoenixID);
        if (usernameTaken) {
            (, address takenAddress) = oldClientPhoenixAuthentication.getUserByName(casedPhoenixID);
            require(_address == takenAddress, "This Phoenix ID is already claimed by another address.");
        }
    }

    function onRemoval(uint ein, bytes memory) public senderIsPhoenixIdentity() returns (bool) {
        bytes32 uncasedPhoenixIDHash = einDirectory[ein];
        assert(uncasedPhoenixIDHashActive(uncasedPhoenixIDHash));

        emit PhoenixIDDestroyed(
            ein, userDirectory[uncasedPhoenixIDHash].casedPhoenixID, userDirectory[uncasedPhoenixIDHash]._address
        );

        delete addressDirectory[userDirectory[uncasedPhoenixIDHash]._address];
        delete einDirectory[ein];
        delete userDirectory[uncasedPhoenixIDHash].casedPhoenixID;
        delete userDirectory[uncasedPhoenixIDHash]._address;
        userDirectory[uncasedPhoenixIDHash].destroyed = true;

        return true;
    }


    // returns whether a given PhoenixID is available
    function phoenixIDAvailable(string memory uncasedPhoenixID) public view returns (bool available) {
        return phoenixIDAvailable(keccak256(abi.encodePacked(uncasedPhoenixID.lower())));
    }

    // Returns a bool indicating whether a given uncasedPhoenixIDHash is available
    function phoenixIDAvailable(bytes32 uncasedPhoenixIDHash) private view returns (bool) {
        return !userDirectory[uncasedPhoenixIDHash].initialized;
    }

    // returns whether a given phoenixID is destroyed
    function phoenixIDDestroyed(string memory uncasedPhoenixID) public view returns (bool destroyed) {
        return phoenixIDDestroyed(keccak256(abi.encodePacked(uncasedPhoenixID.lower())));
    }

    // Returns a bool indicating whether a given phoenixID is destroyed
    function phoenixIDDestroyed(bytes32 uncasedPhoenixIDHash) private view returns (bool) {
        return userDirectory[uncasedPhoenixIDHash].destroyed;
    }

    // returns whether a given phoenixID is active
    function phoenixIDActive(string memory uncasedPhoenixID) public view returns (bool active) {
        return uncasedPhoenixIDHashActive(keccak256(abi.encodePacked(uncasedPhoenixID.lower())));
    }

    // Returns a bool indicating whether a given phoenixID is active
    function uncasedPhoenixIDHashActive(bytes32 uncasedPhoenixIDHash) private view returns (bool) {
        return !phoenixIDAvailable(uncasedPhoenixIDHash) && !phoenixIDDestroyed(uncasedPhoenixIDHash);
    }


    // Returns details by uncased phoenixID
    function getDetails(string memory uncasedPhoenixID) public view
        returns (uint ein, address _address, string memory casedPhoenixID)
    {
        User storage user = getDetails(keccak256(abi.encodePacked(uncasedPhoenixID.lower())));
        return (user.ein, user._address, user.casedPhoenixID);
    }

    // Returns details by EIN
    function getDetails(uint ein) public view returns (address _address, string memory casedPhoenixID) {
        User storage user = getDetails(einDirectory[ein]);
        return (user._address, user.casedPhoenixID);
    }

    // Returns details by address
    function getDetails(address _address) public view returns (uint ein, string memory casedPhoenixID) {
        User storage user = getDetails(addressDirectory[_address]);
        return (user.ein, user.casedPhoenixID);
    }

    // common logic for all getDetails
    function getDetails(bytes32 uncasedPhoenixIDHash) private view returns (User storage) {
        require(uncasedPhoenixIDHashActive(uncasedPhoenixIDHash), "PhoenixID is not active.");
        return userDirectory[uncasedPhoenixIDHash];
    }

    // Events for when a user signs up for PhoenixAuthentication Client and when their account is deleted
    event PhoenixIDClaimed(uint indexed ein, string phoenixID, address userAddress);
    event PhoenixIDDestroyed(uint indexed ein, string phoenixID, address userAddress);
}
