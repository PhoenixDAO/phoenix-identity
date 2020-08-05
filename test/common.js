const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const PhoenixToken = artifacts.require('./_testing/PhoenixToken.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
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

  instances.Snowflake = await Snowflake.new(
    instances.IdentityRegistry.address, instances.PhoenixToken.address, { from: owner }
  )

  instances.OldClientPhoenixAuthentication = await OldClientPhoenixAuthentication.new({ from: owner })

  instances.ClientPhoenixAuthentication = await ClientPhoenixAuthentication.new(
    instances.Snowflake.address, instances.OldClientPhoenixAuthentication.address, 0, 0, { from: owner }
  )
  await instances.Snowflake.setClientPhoenixAuthenticationAddress(instances.ClientPhoenixAuthentication.address, { from: owner })

  return instances
}

module.exports = {
  initialize: initialize
}
