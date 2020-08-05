const common = require('./common.js')
const { verifyIdentity } = require('./utilities')

const ViaSample = artifacts.require('./samples/Via.sol')
const ResolverSample = artifacts.require('./samples/Resolver.sol')

async function verifyPhoenixIdentityBalances (amounts) {
  let phoenixIdentityBalance
  for (let i = 0; i < 2; i++) {
    phoenixIdentityBalance = await instances.PhoenixIdentity.deposits(users[i].identity)
    assert.isTrue(phoenixIdentityBalance.eq(amounts[i]), `Incorrect balance for identity ${users[i].identity}`)
  }
}

async function verifyPhoenixBalances (accounts, amounts) {
  let phoenixBalance
  for (let i = 0; i < accounts.length; i++) {
    phoenixBalance = await instances.PhoenixToken.balanceOf.call(accounts[i])
    assert.isTrue(phoenixBalance.eq(amounts[i]), `Incorrect balance for address ${accounts[i]}`)
  }
}

let instances
let users
let user
contract('Testing PhoenixIdentity Token Functionality', function (accounts) {
  users = [
    {
      address: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      address: accounts[2],
      private: '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    },
    {
      address: accounts[3]
    },
    {
      address: accounts[4]
    }
  ]

  it('common contracts deployed', async () => {
    instances = await common.initialize(accounts[0], [])
  })

  describe('Set up PhoenixIdentitys', () => {
    it('Identities can be created', async function () {
      for (let i = 0; i < 2; i++) {
        const user = users[i]
        await instances.IdentityRegistry.createIdentity(
          user.address, [instances.PhoenixIdentity.address], [], { from: user.address }
        )
        user.identity = web3.utils.toBN(i + 1)

        await verifyIdentity(user.identity, instances.IdentityRegistry, {
          recoveryAddress:     user.address,
          associatedAddresses: [user.address],
          providers:           [instances.PhoenixIdentity.address],
          resolvers:           []
        })
      }
    })
  })

  describe('Deposit Logic', async () => {
    user = users[0]
    const depositAmount = web3.utils.toBN(50).mul(web3.utils.toBN(1e18))
    it('cannot deposit PHOENIX without an EIN', async () => {
      await instances.PhoenixToken.approveAndCall(
        instances.PhoenixIdentity.address, depositAmount, '0x00', { from: accounts[0] }
      )
        .then(() => assert.fail('able to deposit', 'transaction should fail'))
        .catch(error => {
          assert.include(
            error.message, 'The passed address does not have an identity but should.', 'wrong rejection reason'
          )
        })

      await instances.PhoenixToken.transfer(user.address, depositAmount, { from: accounts[0] })
    })

    it('owner can deposit 50 PHOENIX to an EIN', async () => {
      await instances.PhoenixToken.approveAndCall(
        instances.PhoenixIdentity.address, depositAmount, web3.eth.abi.encodeParameter('uint256', user.identity.toString()),
        { from: accounts[0] }
      )
      await verifyPhoenixIdentityBalances([depositAmount, web3.utils.toBN(0)])
    })

    it('can deposit 50 PHOENIX to own EIN', async () => {
      await instances.PhoenixToken.approveAndCall(
        instances.PhoenixIdentity.address, depositAmount, '0x00', { from: user.address }
      )
      await verifyPhoenixIdentityBalances([depositAmount.mul(web3.utils.toBN(2)), web3.utils.toBN(0)])
    })
  })

  describe('Testing self initiated methods', async () => {
    const startingAmount = web3.utils.toBN(100).mul(web3.utils.toBN(1e18))
    const transferAmount = web3.utils.toBN(1e18)
    it('can transfer PHOENIX from 1 phoenixIdentity to another', async () => {
      await instances.PhoenixIdentity.transferPhoenixIdentityBalance(users[1].identity, transferAmount, { from: users[0].address })
      await verifyPhoenixIdentityBalances([startingAmount.sub(transferAmount), transferAmount])
    })

    const withdrawAmount = web3.utils.toBN(1e18)
    it('can withdraw PHOENIX from from a phoenixIdentity', async () => {
      await instances.PhoenixIdentity.withdrawPhoenixIdentityBalance(users[1].address, transferAmount, { from: users[1].address })
      await verifyPhoenixIdentityBalances([startingAmount.sub(transferAmount), web3.utils.toBN(0)])
      await verifyPhoenixBalances([users[1].address], [withdrawAmount])
    })

    it('reset', async () => {
      await instances.PhoenixToken.approveAndCall(
        instances.PhoenixIdentity.address, withdrawAmount, web3.eth.abi.encodeParameter('uint', users[0].identity.toString()),
        { from: users[1].address }
      )
      await verifyPhoenixIdentityBalances([startingAmount, web3.utils.toBN(0)])
    })
  })

  describe('Testing resolver initiated methods', async () => {
    it('deploy sample resolver', async () => {
      instances.ResolverSample = await ResolverSample.new(instances.PhoenixIdentity.address, { from: accounts[0] })
    })

    user = users[0]
    const startingAmount = web3.utils.toBN(100).mul(web3.utils.toBN(1e18))
    const escrowAmount = startingAmount.div(web3.utils.toBN(2))
    it('add it to the identity', async () => {
      await instances.PhoenixIdentity.addResolver(
        instances.ResolverSample.address, true, startingAmount, '0x00', { from: user.address }
      )

      await verifyPhoenixIdentityBalances([startingAmount.sub(escrowAmount), web3.utils.toBN(0)])
      await verifyPhoenixBalances([instances.ResolverSample.address], [escrowAmount])
    })

    const allowAndCallTransferAmount = web3.utils.toBN(1e18)
    it('resolver could use allowAndCall', async () => {
      const methodID = web3.utils
        .soliditySha3('transferPhoenixIdentityBalanceFromAllowAndCall(uint256,uint256,uint256)')
        .substring(0, 10)

      const encodedArgs = [
        users[0].identity.toString(16, 64),
        users[1].identity.toString(16, 64),
        allowAndCallTransferAmount.toString(16, 64)
      ]
      const data = `${methodID}${encodedArgs.join('')}`

      await instances.PhoenixIdentity.allowAndCall.call(
        instances.ResolverSample.address, transferAmount, data, { from: users[0].address }
      )
    })

    const transferAmount = web3.utils.toBN(1e18)
    it('resolver can transfer balances from', async () => {
      await instances.ResolverSample.transferPhoenixIdentityBalanceFrom(
        users[1].identity, transferAmount, { from: users[0].address }
      )
      const allowance = await instances.PhoenixIdentity.resolverAllowances.call(
        user.identity, instances.ResolverSample.address
      )
      assert.isTrue(allowance.eq(escrowAmount.sub(transferAmount)), 'Allowance not updated.')
      await verifyPhoenixIdentityBalances([startingAmount.sub(escrowAmount).sub(transferAmount), transferAmount])
    })

    it('reset', async () => {
      await instances.PhoenixIdentity.transferPhoenixIdentityBalance(user.identity, transferAmount, { from: users[1].address })
      await verifyPhoenixIdentityBalances([startingAmount.sub(escrowAmount), web3.utils.toBN(0)])
    })

    const withdrawAmount = web3.utils.toBN(1e18)
    it('resolver can withdraw balances from', async () => {
      await instances.ResolverSample.withdrawPhoenixIdentityBalanceFrom(user.address, withdrawAmount, { from: user.address })
      const allowance = await instances.PhoenixIdentity.resolverAllowances.call(
        user.identity, instances.ResolverSample.address
      )
      assert.isTrue(allowance.eq(escrowAmount.sub(transferAmount).sub(withdrawAmount)), 'Allowance not updated.')
      await verifyPhoenixIdentityBalances([startingAmount.sub(escrowAmount).sub(withdrawAmount), web3.utils.toBN(0)])
      await verifyPhoenixBalances([user.address], [withdrawAmount])
    })

    it('reset', async () => {
      await instances.PhoenixToken.approveAndCall(
        instances.PhoenixIdentity.address, withdrawAmount, web3.eth.abi.encodeParameter('uint', user.identity.toString()),
        { from: user.address }
      )
      await verifyPhoenixIdentityBalances([startingAmount.sub(escrowAmount), web3.utils.toBN(0)])
    })
  })

  describe('Testing resolver initiated methods -- via', async () => {
    it('deploy sample via and fund it', async () => {
      instances.ViaSample = await ViaSample.new(instances.PhoenixIdentity.address, { from: accounts[0] })
      await instances.ViaSample.fund({ from: accounts[0], value: web3.utils.toWei('4', 'ether') })
    })

    const startingAmount = web3.utils.toBN(50).mul(web3.utils.toBN(1e18))
    const startingAllowance = web3.utils.toBN(48).mul(web3.utils.toBN(1e18))
    const transferAmount = web3.utils.toBN(10).mul(web3.utils.toBN(1e18))
    it('resolver can transfer balances from via', async () => {
      await instances.ResolverSample.transferPhoenixIdentityBalanceFromVia(
        instances.ViaSample.address, user.identity, transferAmount, { from: user.address }
      )
      const allowance = await instances.PhoenixIdentity.resolverAllowances.call(
        user.identity, instances.ResolverSample.address
      )
      assert.isTrue(allowance.eq(startingAllowance.sub(transferAmount)), 'Allowance not updated.')
      await verifyPhoenixIdentityBalances([startingAmount.sub(transferAmount), web3.utils.toBN(0)])

      // 1 because we sent 10 phoenix := 1 eth as defined in the via contract
      const balance = await instances.ViaSample.balances(user.identity)
      assert.isTrue(balance.eq(transferAmount.div(web3.utils.toBN(10))), 'Incorrect via.')
    })

    const withdrawAmount = web3.utils.toBN(10).mul(web3.utils.toBN(1e18))
    it('resolver can withdraw balances from via', async () => {
      await instances.ResolverSample.withdrawPhoenixIdentityBalanceFromVia(
        instances.ViaSample.address, user.address, withdrawAmount, { from: user.address }
      )
      const allowance = await instances.PhoenixIdentity.resolverAllowances.call(
        user.identity, instances.ResolverSample.address
      )
      assert.isTrue(allowance.eq(startingAllowance.sub(transferAmount).sub(withdrawAmount)), 'Allowance not updated.')
      await verifyPhoenixIdentityBalances([startingAmount.sub(transferAmount).sub(withdrawAmount), web3.utils.toBN(0)])
    })
  })

  describe('Testing escrow initiated methods', async () => {
    const transferAmount = web3.utils.toBN(5e18)
    const startingAmount = web3.utils.toBN(30).mul(web3.utils.toBN(1e18))
    it('resolver can transfer escrowed balances to', async () => {
      await instances.ResolverSample._transferPhoenixBalanceTo(user.identity, transferAmount)
      await verifyPhoenixIdentityBalances([startingAmount.add(transferAmount), web3.utils.toBN(0)])
    })

    const withdrawAmount = web3.utils.toBN(5e18)
    it('resolver can withdraw escrowed balances to', async () => {
      await instances.ResolverSample._withdrawPhoenixBalanceTo(user.address, withdrawAmount)
      await verifyPhoenixIdentityBalances([startingAmount.add(transferAmount), web3.utils.toBN(0)])
      await verifyPhoenixBalances([user.address], [withdrawAmount])
    })
  })

  describe('Testing escrow initiated methods -- via', async () => {
    const transferAmount = web3.utils.toBN(10e18)
    it('resolver can transfer escrow balances from via', async () => {
      await instances.ResolverSample._transferPhoenixBalanceToVia(
        instances.ViaSample.address, users[1].identity, transferAmount, { from: accounts[0] }
      )

      // 1 because we sent 10 phoenix := 1 eth as defined in the via contract
      const balance = await instances.ViaSample.balances(users[1].identity)
      assert.isTrue(balance.eq(transferAmount.div(web3.utils.toBN(10))), 'Incorrect via.')
    })

    const withdrawAmount = web3.utils.toBN(10e18)
    it('resolver can withdraw escrow balances from via', async () => {
      await instances.ResolverSample._withdrawPhoenixBalanceToVia(
        instances.ViaSample.address, users[1].address, withdrawAmount
      )
    })
  })
})
