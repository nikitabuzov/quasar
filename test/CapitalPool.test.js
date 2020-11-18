let CapitalPool = artifacts.require('CapitalPool');
let catchRevert = require("./exceptionsHelpers.js").catchRevert

contract('CapitalPool', function(accounts) {

    // const owner = accounts[0]
    const user1 = accounts[1]
    const user2 = accounts[2]
    // const emptyAddress = '0x0000000000000000000000000000000000000000'

    const expectedPrice = 4

    let instance
    let owner

    beforeEach(async () => {
        instance = await CapitalPool.new()
        // owner = instance.owner()
    })

    it('The coverage price set by the owner should match the returned price', async () => {
        const returnedPrice = await instance.setCoveragePrice(expectedPrice, {from:'0x627306090abaB3A6e1400e9345bC60c78a8BEf57'})

        // assert.equal(instance.owner(),owner, 'the expected owner does not match the actual one')
        assert.equal(returnedPrice, expectedPrice, 'the expected coverage price does not match the returned price')
    })

    it('A coverage buyer should be able to buy coverage', async () => {
        const result = await instance.buyCoverage(31536000, 100, {from: user1, value:2}) 

        if (result.logs[0].event == "logCoverPurchase") {
            eventEmitted = true
        }

        assert.equal(result, true, 'buying coverage should return true')
        assert.equal(eventEmitted, true, 'buying coverage should emit a CoverPurchase event')
    })
})