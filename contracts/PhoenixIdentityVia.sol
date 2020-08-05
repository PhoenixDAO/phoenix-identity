pragma solidity ^0.5.0;

import "./zeppelin/ownership/Ownable.sol";

import "./interfaces/PhoenixIdentityViaInterface.sol";

contract PhoenixIdentityVia is Ownable {
    address public phoenixIdentityAddress;

    constructor(address _phoenixIdentityAddress) public {
        setPhoenixIdentityAddress(_phoenixIdentityAddress);
    }

    modifier senderIsPhoenixIdentity() {
        require(msg.sender == phoenixIdentityAddress, "Did not originate from PhoenixIdentity.");
        _;
    }

    // this can be overriden to initialize other variables, such as e.g. an ERC20 object to wrap the phoenix token
    function setPhoenixIdentityAddress(address _phoenixIdentityAddress) public onlyOwner {
        phoenixIdentityAddress = _phoenixIdentityAddress;
    }

    // all phoenixIdentityCall functions **must** use the senderIsPhoenixIdentity modifier, because otherwise there is no guarantee
    // that phoenix tokens were actually sent to this smart contract prior to the phoenixIdentityCall. Further accounting checks
    // of course make this possible to check, but since this is tedious and a low value-add,
    // it's officially not recommended
    function phoenixIdentityCall(address resolver, uint einFrom, uint einTo, uint amount, bytes memory phoenixIdentityCallBytes)
        public;
    function phoenixIdentityCall(
        address resolver, uint einFrom, address payable to, uint amount, bytes memory phoenixIdentityCallBytes
    ) public;
    function phoenixIdentityCall(address resolver, uint einTo, uint amount, bytes memory phoenixIdentityCallBytes) public;
    function phoenixIdentityCall(address resolver, address payable to, uint amount, bytes memory phoenixIdentityCallBytes) public;
}
