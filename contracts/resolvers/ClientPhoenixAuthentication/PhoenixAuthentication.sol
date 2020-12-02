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
    OldClientPhoenixAuthenticationInterface
        private oldClientPhoenixAuthentication;

    // staking requirements
    uint256 public phoenixStakeUser;
    uint256 public phoenixStakeDelegatedUser;

    // User account template
    struct User {
        uint256 PHNX_ID;
        address _address;
        string casedPhoenixID;
        bool initialized;
        bool destroyed;
    }

    // Mapping from uncased phoenixID hashes to users
    mapping(bytes32 => User) private userDirectory;
    // Mapping from PHNX_ID to uncased phoenixID hashes
    mapping(uint256 => bytes32) private PHNX_IDDirectory;
    // Mapping from address to uncased phoenixID hashes
    mapping(address => bytes32) private addressDirectory;

    constructor(
        address phoenixIdentityAddress,
        address oldClientPhoenixAuthenticationAddress,
        uint256 _phoenixStakeUser,
        uint256 _phoenixStakeDelegatedUser
    )
        public
        PhoenixIdentityResolver(
            "Client PhoenixAuthentication",
            "A registry that links PHNX_IDs to PhoenixIDs to power Client PhoenixAuthentication MFA.",
            phoenixIdentityAddress,
            true,
            true
        )
    {
        setPhoenixIdentityAddress(phoenixIdentityAddress);
        setOldClientPhoenixAuthenticationAddress(
            oldClientPhoenixAuthenticationAddress
        );
        setStakes(_phoenixStakeUser, _phoenixStakeDelegatedUser);
    }

    // Requires an address to have a minimum number of phoenix
    modifier requireStake(address _address, uint256 stake) {
        require(
            phoenixToken.balanceOf(_address) >= stake,
            "Insufficient staked Phoenix balance."
        );
        _;
    }

    // set the phoenixIdentity address, and phoenix token + identity registry contract wrappers
    function setPhoenixIdentityAddress(address phoenixIdentityAddress)
        public
        onlyOwner()
    {
        super.setPhoenixIdentityAddress(phoenixIdentityAddress);

        PhoenixIdentityInterface phoenixIdentity = PhoenixIdentityInterface(
            phoenixIdentityAddress
        );
        phoenixToken = PhoenixInterface(phoenixIdentity.phoenixTokenAddress());
        identityRegistry = IdentityRegistryInterface(
            phoenixIdentity.identityRegistryAddress()
        );
    }

    // set the old client PhoenixAuthentication address
    function setOldClientPhoenixAuthenticationAddress(
        address oldClientPhoenixAuthenticationAddress
    ) public onlyOwner() {
        oldClientPhoenixAuthentication = OldClientPhoenixAuthenticationInterface(
            oldClientPhoenixAuthenticationAddress
        );
    }

    // set minimum phoenix balances required for sign ups
    function setStakes(
        uint256 _phoenixStakeUser,
        uint256 _phoenixStakeDelegatedUser
    ) public onlyOwner() {
        // <= the airdrop amount
        require(_phoenixStakeUser <= 222222 * 10**18, "Stake is too high.");
        phoenixStakeUser = _phoenixStakeDelegatedUser;

        // <= 1% of total supply
        require(
            _phoenixStakeDelegatedUser <= phoenixToken.totalSupply() / 100,
            "Stake is too high."
        );
        phoenixStakeDelegatedUser = _phoenixStakeDelegatedUser;
    }

    // function for users calling signup for themselves
    function signUp(address _address, string memory casedPhoenixId)
        public
        requireStake(msg.sender, phoenixStakeUser)
    {
        _signUp(
            identityRegistry.getPHNX_ID(msg.sender),
            casedPhoenixId,
            _address
        );
    }

    // function for users signing up through the phoenixIdentity provider
    function onAddition(
        uint256 PHNX_ID,
        uint256,
        bytes memory extraData
    )
        public
        // solium-disable-next-line security/no-tx-origin
        senderIsPhoenixIdentity()
        requireStake(tx.origin, phoenixStakeDelegatedUser)
        returns (bool)
    {
        (address _address, string memory casedPhoenixID) = abi.decode(
            extraData,
            (address, string)
        );
        require(
            identityRegistry.isProviderFor(PHNX_ID, msg.sender),
            "PhoenixIdentity is not a Provider for the passed PHNX_ID."
        );
        _signUp(PHNX_ID, casedPhoenixID, _address);

        return true;
    }

    // Common internal logic for all user signups
    function _signUp(
        uint256 PHNX_ID,
        string memory casedPhoenixID,
        address _address
    ) internal {
        require(
            bytes(casedPhoenixID).length > 2 &&
                bytes(casedPhoenixID).length < 33,
            "PhoenixID has invalid length."
        );
        require(
            identityRegistry.isResolverFor(PHNX_ID, address(this)),
            "The passed PHNX_ID has not set this resolver."
        );
        require(
            identityRegistry.isAssociatedAddressFor(PHNX_ID, _address),
            "The passed address is not associated with the calling Identity."
        );
        checkForOldPhoenixID(casedPhoenixID, _address);

        bytes32 uncasedPhoenixIDHash = keccak256(
            abi.encodePacked(casedPhoenixID.toSlice().copy().toString().lower())
        );
        // check conditions specific to this resolver
        require(
            phoenixIDAvailable(uncasedPhoenixIDHash),
            "PhoenixID is unavailable."
        );
        require(
            PHNX_IDDirectory[PHNX_ID] == bytes32(0),
            "PHNX_ID is already mapped to a PhoenixID."
        );
        require(
            addressDirectory[_address] == bytes32(0),
            "Address is already mapped to a PhoenixID."
        );

        // update mappings
        userDirectory[uncasedPhoenixIDHash] = User(
            PHNX_ID,
            _address,
            casedPhoenixID,
            true,
            false
        );
        PHNX_IDDirectory[PHNX_ID] = uncasedPhoenixIDHash;
        addressDirectory[_address] = uncasedPhoenixIDHash;

        emit PhoenixIDClaimed(PHNX_ID, casedPhoenixID, _address);
    }

    function checkForOldPhoenixID(
        string memory casedPhoenixID,
        address _address
    ) public view {
        bool usernameTaken = oldClientPhoenixAuthentication.userNameTaken(
            casedPhoenixID
        );
        if (usernameTaken) {
            (, address takenAddress) = oldClientPhoenixAuthentication
                .getUserByName(casedPhoenixID);
            require(
                _address == takenAddress,
                "This Phoenix ID is already claimed by another address."
            );
        }
    }

    function onRemoval(uint256 PHNX_ID, bytes memory)
        public
        senderIsPhoenixIdentity()
        returns (bool)
    {
        bytes32 uncasedPhoenixIDHash = PHNX_IDDirectory[PHNX_ID];
        assert(uncasedPhoenixIDHashActive(uncasedPhoenixIDHash));

        emit PhoenixIDDestroyed(
            PHNX_ID,
            userDirectory[uncasedPhoenixIDHash].casedPhoenixID,
            userDirectory[uncasedPhoenixIDHash]._address
        );

        delete addressDirectory[userDirectory[uncasedPhoenixIDHash]._address];
        delete PHNX_IDDirectory[PHNX_ID];
        delete userDirectory[uncasedPhoenixIDHash].casedPhoenixID;
        delete userDirectory[uncasedPhoenixIDHash]._address;
        userDirectory[uncasedPhoenixIDHash].destroyed = true;

        return true;
    }

    // returns whether a given PhoenixID is available
    function phoenixIDAvailable(string memory uncasedPhoenixID)
        public
        view
        returns (bool available)
    {
        return
            phoenixIDAvailable(
                keccak256(abi.encodePacked(uncasedPhoenixID.lower()))
            );
    }

    // Returns a bool indicating whether a given uncasedPhoenixIDHash is available
    function phoenixIDAvailable(bytes32 uncasedPhoenixIDHash)
        private
        view
        returns (bool)
    {
        return !userDirectory[uncasedPhoenixIDHash].initialized;
    }

    // returns whether a given phoenixID is destroyed
    function phoenixIDDestroyed(string memory uncasedPhoenixID)
        public
        view
        returns (bool destroyed)
    {
        return
            phoenixIDDestroyed(
                keccak256(abi.encodePacked(uncasedPhoenixID.lower()))
            );
    }

    // Returns a bool indicating whether a given phoenixID is destroyed
    function phoenixIDDestroyed(bytes32 uncasedPhoenixIDHash)
        private
        view
        returns (bool)
    {
        return userDirectory[uncasedPhoenixIDHash].destroyed;
    }

    // returns whether a given phoenixID is active
    function phoenixIDActive(string memory uncasedPhoenixID)
        public
        view
        returns (bool active)
    {
        return
            uncasedPhoenixIDHashActive(
                keccak256(abi.encodePacked(uncasedPhoenixID.lower()))
            );
    }

    // Returns a bool indicating whether a given phoenixID is active
    function uncasedPhoenixIDHashActive(bytes32 uncasedPhoenixIDHash)
        private
        view
        returns (bool)
    {
        return
            !phoenixIDAvailable(uncasedPhoenixIDHash) &&
            !phoenixIDDestroyed(uncasedPhoenixIDHash);
    }

    // Returns details by uncased phoenixID
    function getDetails(string memory uncasedPhoenixID)
        public
        view
        returns (
            uint256 PHNX_ID,
            address _address,
            string memory casedPhoenixID
        )
    {
        User storage user = getDetails(
            keccak256(abi.encodePacked(uncasedPhoenixID.lower()))
        );
        return (user.PHNX_ID, user._address, user.casedPhoenixID);
    }

    // Returns details by PHNX_ID
    function getDetails(uint256 PHNX_ID)
        public
        view
        returns (address _address, string memory casedPhoenixID)
    {
        User storage user = getDetails(PHNX_IDDirectory[PHNX_ID]);
        return (user._address, user.casedPhoenixID);
    }

    // Returns details by address
    function getDetails(address _address)
        public
        view
        returns (uint256 PHNX_ID, string memory casedPhoenixID)
    {
        User storage user = getDetails(addressDirectory[_address]);
        return (user.PHNX_ID, user.casedPhoenixID);
    }

    // common logic for all getDetails
    function getDetails(bytes32 uncasedPhoenixIDHash)
        private
        view
        returns (User storage)
    {
        require(
            uncasedPhoenixIDHashActive(uncasedPhoenixIDHash),
            "PhoenixID is not active."
        );
        return userDirectory[uncasedPhoenixIDHash];
    }

    // Events for when a user signs up for PhoenixAuthentication Client and when their account is deleted
    event PhoenixIDClaimed(
        uint256 indexed PHNX_ID,
        string phoenixID,
        address userAddress
    );
    event PhoenixIDDestroyed(
        uint256 indexed PHNX_ID,
        string phoenixID,
        address userAddress
    );
}
