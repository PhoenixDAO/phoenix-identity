const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const PhoenixToken = artifacts.require('./_testing/PhoenixToken.sol')
const PhoenixIdentity = artifacts.require('./PhoenixIdentity.sol')
const ClientPhoenixAuthentication = artifacts.require('./resolvers/ClientPhoenixAuthentication/ClientPhoenixAuthentication.sol')
const OldClientPhoenixAuthentication = artifacts.require('./_testing/OldClientPhoenixAuthentication.sol')

async function initialize (owner, users) {
  const instances = {}

  instances.PhoenixToken = await PhoenixToken.new({ from: owner })
  for (let i = 0; i < users.length; i++) {
    await instances.PhoenixToken.transfer(
      users[i].address,
      web3.utils.toBN(1000).mul(web3.utils.toBN(1e18)),
      { from: owner }
    )
  }

  instances.IdentityRegistry = await IdentityRegistry.new({ from: owner })

  instances.PhoenixIdentity = await PhoenixIdentity.new(
    instances.IdentityRegistry.address, instances.PhoenixToken.address, { from: owner }
  )

  instances.OldClientPhoenixAuthentication = await OldClientPhoenixAuthentication.new({ from: owner })

  instances.ClientPhoenixAuthentication = await ClientPhoenixAuthentication.new(
    instances.PhoenixIdentity.address, instances.OldClientPhoenixAuthentication.address, 0, 0, { from: owner }
  )
  await instances.PhoenixIdentity.setClientPhoenixAuthenticationAddress(instances.ClientPhoenixAuthentication.address, { from: owner })

  return instances
}

module.exports = {
  initialize: initialize
}
