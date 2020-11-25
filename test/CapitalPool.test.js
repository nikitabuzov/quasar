let BN = web3.utils.BN
let CapitalPool = artifacts.require('CapitalPool');
let catchRevert = require("./exceptionsHelpers.js").catchRevert

contract('CapitalPool', function(accounts) {

    const owner = accounts[0]
    const user1 = accounts[1]
    const user2 = accounts[2]
    const user3 = accounts[3]
    const user4 = accounts[4]
    const user5 = accounts[5]
    const user6 = accounts[6]

    let instance

    beforeEach(async () => {
        instance = await CapitalPool.new()
    })

    it('should update the coverage price when set by the owner', async () => {
        const tx = await instance.setCoveragePrice(3, {from: owner})

        assert.ok(tx.receipt.status, 'coverage price update is successful')
    })

    it('should allow coverage buyers to purchase the coverage', async () => {
        await instance.depositCapital({from:user6,value:100}) // first must deposit liquidity

        // check valid 1 year tx + event emitted
        const tx = await instance.buyCoverage(31536000, 100, {from: user1, value:2})
        if (tx.logs[0].event == "logCoverPurchase") {
            eventEmitted = true
        }
        assert.ok(tx.receipt.status, 'coverage purchase is successful')
        assert.equal(eventEmitted, true, 'coverage purchase emits a CoverPurchase event')

        // check invalid pay amount (not enough)
        await catchRevert(instance.buyCoverage(31536000, 100, {from: user2, value:1}))

        // check invalid period (over a year / less than 14 days)
        await catchRevert(instance.buyCoverage(33536000, 100, {from: user3, value:2}))
        await catchRevert(instance.buyCoverage(1009600, 100, {from: user4, value:2}))

        // check invalid cover amount (over the available amount)
        await catchRevert(instance.buyCoverage(31536000, 4500, {from: user5, value:90}))

        // check that mcr is updated
        assert.equal(await instance.mcr.call(),100)

        // check ETH in the contract
        assert.equal(await web3.eth.getBalance(instance.address),102)
    })

    it('should allow coverage providers to deposit ETH', async () => {
        // var poolBefore = await instance.capitalPool.call()
        var poolBefore = await web3.eth.getBalance(instance.address)
        const tx = await instance.depositCapital({from: user2, value: 20})
        if (tx.logs[0].event == "logCapitalDeposited") {
            eventEmitted = true
        }
        // var poolAfter = await instance.capitalPool.call()
        var poolAfter = await web3.eth.getBalance(instance.address)

        assert.equal(poolAfter-poolBefore,20, 'pool balance updated correctly')
        assert.ok(tx.receipt.status, 'deposit is successful')
        assert.equal(eventEmitted, true, 'deposit emits a CapitalDeposited event')
        
    })
})