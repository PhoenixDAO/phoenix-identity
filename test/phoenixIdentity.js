const common = require('./common.js')
const { sign, verifyIdentity } = require('./utilities')

let user
let instances
contract('Testing PhoenixIdentity', function (accounts) {
  const users = [
    {
      phoenixID: 'abc',
      address: accounts[1],
      recoveryAddress: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      phoenixID: 'xyz',
      address: accounts[2],
      recoveryAddress: accounts[2],
      private: '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    },
    {
      public: accounts[3]
    },
    {
      public: accounts[4]
    }
  ]

  it('common contracts deployed', async () => {
    instances = await common.initialize(accounts[0], [])
  })

  describe('Test PhoenixIdentity', async () => {
    it('Identity can be created', async function () {
      user = users[0]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.PhoenixIdentity.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.PhoenixIdentity.createIdentityDelegated(
        user.recoveryAddress, user.address, [], user.phoenixID, permission.v, permission.r, permission.s, timestamp
      )

      user.identity = web3.utils.toBN(1)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.recoveryAddress,
        associatedAddresses: [user.address],
        providers:           [instances.PhoenixIdentity.address],
        resolvers:           [instances.ClientPhoenixAuthentication.address]
      })
    })
  })

  describe('Testing Client PhoenixAuthentication', async () => {
    const newStake = web3.utils.toBN(1).mul(web3.utils.toBN(1e18))
    it('Stakes are settable', async function () {
      await instances.ClientPhoenixAuthentication.setStakes(newStake, newStake)
    })

    it('Insufficiently staked provider sign-ups are rejected', async function () {
      user = users[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.PhoenixIdentity.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.PhoenixIdentity.createIdentityDelegated(
        user.recoveryAddress, user.address, [], user.phoenixID, permission.v, permission.r, permission.s, timestamp,
        { from: user.address }
      )
        .then(() => assert.fail('unstaked PhoenixID was reserved', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'Insufficient staked Phoenix balance.', 'unexpected error'))
    })

    it('Could sign up as staked provider', async function () {
      user = users[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.PhoenixIdentity.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.PhoenixIdentity.createIdentityDelegated.call(
        user.recoveryAddress, user.address, [], user.phoenixID, permission.v, permission.r, permission.s, timestamp
      )
    })

    it('User 1 can sign up for an identity and add client PhoenixAuthentication', async function () {
      await instances.IdentityRegistry.createIdentity(
        user.recoveryAddress, [], [instances.ClientPhoenixAuthentication.address], { from: user.address }
      )
    })

    it('Insufficiently staked self signups are rejected', async function () {
      await instances.ClientPhoenixAuthentication.signUp(user.address, user.phoenixID, { from: user.address })
        .then(() => assert.fail('unstaked PhoenixID was reserved', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'Insufficient staked PHOENIX balance.', 'unexpected error'))

      await instances.PhoenixToken.transfer(user.address, newStake, { from: accounts[0] })
    })

    it('Bad PhoenixIDs are rejected', async function () {
      user = users[1]
      const badPhoenixIDs = ['Abc', 'aBc', 'abC', 'ABc', 'AbC', 'aBC', 'ABC', '1', '12', 'a'.repeat(33)]

      await Promise.all(badPhoenixIDs.map(badPhoenixID => {
        return instances.ClientPhoenixAuthentication.signUp(user.address, badPhoenixID, { from: user.address })
          .then(() => assert.fail('bad PhoenixID was reserved', 'transaction should fail'))
          .catch(error => assert.match(
            error.message, /.*PhoenixID is unavailable\.|PhoenixID has invalid length\..*/, 'unexpected error'
          ))
      }))
    })

    it('could sign up self once conditions are met', async function () {
      await instances.ClientPhoenixAuthentication.signUp.call(user.address, user.phoenixID, { from: user.address })
    })
  })
})
