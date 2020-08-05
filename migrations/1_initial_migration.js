const AddressSet = artifacts.require('./_testing/AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')

const PhoenixToken = artifacts.require('./_testing/PhoenixToken.sol')

const SafeMath = artifacts.require('./zeppelin/math/SafeMath.sol')
const PhoenixIdentity = artifacts.require('./PhoenixIdentity.sol')
// const Status = artifacts.require('./resolvers/Status.sol')

const StringUtils = artifacts.require('./resolvers/ClientPhoenixAuthentication/StringUtils.sol')
const ClientPhoenixAuthentication = artifacts.require('./resolvers/ClientPhoenixAuthentication/ClientPhoenixAuthentication.sol')
const OldClientPhoenixAuthentication = artifacts.require('./_testing/OldClientPhoenixAuthentication.sol')

module.exports = async function (deployer) {
  await deployer.deploy(AddressSet)
  deployer.link(AddressSet, IdentityRegistry)

  await deployer.deploy(SafeMath)
  deployer.link(SafeMath, PhoenixToken)
  deployer.link(SafeMath, PhoenixIdentity)

  await deployer.deploy(StringUtils)
  deployer.link(StringUtils, ClientPhoenixAuthentication)
  deployer.link(StringUtils, OldClientPhoenixAuthentication)

  // const identityRegistry = await deployer.deploy(IdentityRegistry)
  // const phoenixToken = await deployer.deploy(PhoenixToken)
  // const phoenixIdentity = await deployer.deploy(PhoenixIdentity, identityRegistry.address, phoenixToken.address)
  // const oldClientPhoenixAuthentication = await deployer.deploy(OldClientPhoenixAuthentication)
  // await deployer.deploy(ClientPhoenixAuthentication, phoenixIdentity.address, oldClientPhoenixAuthentication.address, 0, 0)
  // await deployer.deploy(Status, phoenixIdentity.address)
}
