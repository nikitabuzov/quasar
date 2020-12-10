// const { assert } = require("console");
const assert = require('assert');

let BN = web3.utils.BN
let CapitalPool = artifacts.require('Pool');
let QSRToken = artifacts.require('QuasarToken');
let catchRevert = require("./exceptionsHelpers.js").catchRevert
let timeTravel = require("./timeTravelHelper.js")

contract('Pool', function(accounts) {

    const owner = accounts[0]
    const user1 = accounts[1]
    const user2 = accounts[2]
    const user3 = accounts[3]
    const user4 = accounts[4]
    const user5 = accounts[5]
    const user6 = accounts[6]

    let instance
    let token

    beforeEach(async () => {
        instance = await CapitalPool.new()
        token = await QSRToken.deployed()
    })

    it('should update the coverage price when set by the owner', async () => {
        const tx = await instance.setCoveragePrice(3, {from: owner})
        if (tx.logs[0].event == "CoverPriceUpdated") {
            eventEmitted = true
        }
        assert.ok(tx.receipt.status, 'coverage price update is successful')
        assert.strictEqual(eventEmitted, true, 'price update emits a CoverPriceUpdated event')
    })

    describe('buying coverage', function () {
        it('should allow buyers to purchase the coverage and update MCR', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            const tx = await instance.buyCoverage(31536000, 100, {from: user1, value:2})
            if (tx.logs[0].event == "CoverPurchased") {
                eventEmitted = true
            }
            assert.ok(tx.receipt.status, 'coverage purchase is successful')
            assert.strictEqual(eventEmitted, true, 'coverage purchase emits a CoverPurchased event')
 
            // check that mcr is updated
            var MCR = await instance.mcr.call()
            assert.strictEqual(MCR.toNumber(),100)
    
            // check ETH in the contract
            assert.strictEqual(await web3.eth.getBalance(instance.address),'102')
        });

        it('should not allow buyers who did not pay enough to purchase the coverage', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            await catchRevert(instance.buyCoverage(31536000, 100, {from: user2, value:1}))
        });

        it('should not allow buyers to purchase the coverage for invalid period', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            await catchRevert(instance.buyCoverage(33536000, 100, {from: user3, value:2}))
            await catchRevert(instance.buyCoverage(1009600, 100, {from: user4, value:2}))
        });
        
        it('should not allow buyers to purchase the coverage if the pool is too small', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            await catchRevert(instance.buyCoverage(31536000, 4500, {from: user5, value:90}))
        });
    });

    describe('capital pool deposits / withdrawals', function () {
        it('should allow coverage providers to deposit ETH', async () => {
            var poolBefore = await web3.eth.getBalance(instance.address)
            const tx = await instance.deposit({from: user2, value: 20})
            if (tx.logs[0].event == "Deposited") {
                eventEmitted = true
            }
            var poolAfter = await web3.eth.getBalance(instance.address)
            var totalSupply = await instance._totalSupply.call()
            assert.strictEqual(poolAfter-poolBefore,20, 'pool balance updated correctly')
            assert.strictEqual(poolAfter,totalSupply.toString(), "_totalSupply should strictEqual the actual ETH balance")
            assert.ok(tx.receipt.status, 'deposit is successful')
            assert.strictEqual(eventEmitted, true, 'deposit emits a Deposited event')
        });

        it('should allow coverage providers to withdraw ETH', async () => {
            await instance.deposit({from: user2, value: 20})
            const tx = await instance.withdraw(10, {from: user2})
            if (tx.logs[0].event == "Withdrawn") {
                eventEmitted = true
            }
            const totalSupply = await instance._totalSupply.call()
            assert.ok(tx.receipt.status, 'withdrawal is successful')
            assert.strictEqual(totalSupply.toNumber(),10, "_totalSupply should strictEqual the actual ETH balance")
            assert.strictEqual(eventEmitted, true, 'deposit emits a Withdrawn event')
        });

        it('should distribute reward tokens to providers', async () => {
            await instance.deposit({from: user2, value: 20})
            await timeTravel.advanceBlock(500)
            const tx = await instance.exit({from: user2})
            if (tx.logs[0].event == "RewardPaid") {
                eventEmitted = true
            }
            var userRewards = await token.balanceOf(user2)
            assert.ok(tx.receipt.status, 'exit is successful')
            assert.strictEqual(eventEmitted, true, 'exit emits a RewardPaid event')
            assert.notStrictEqual(userRewards,0, 'user should have earned some rewards')
        });
    });

    describe('coverage claims', function () {
        it('should let buyers to open claims', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            await instance.buyCoverage(31536000, 50, {from: user1, value:1})
            await timeTravel.advanceTimeAndBlock(2678400)
            const tx = await instance.openClaim('Yearn got hacked, I lost my money, please pay me back!', {from: user1})
            if (tx.logs[0].event == "ClaimOpened") {
                eventEmitted = true
            }
            assert.ok(tx.receipt.status, 'claim is successfully opened')
            assert.strictEqual(eventEmitted, true, 'openClaim emits a ClaimOpened event')
        });

        it('should let the owner to resolve claims and make payouts', async () => {
            await instance.deposit({from:user6,value:100}) // first must deposit liquidity
            await instance.buyCoverage(31536000, 50, {from: user1, value:1})
            await timeTravel.advanceTimeAndBlock(2678400)
            await instance.openClaim('Yearn got hacked, I lost my money, please pay me back!', {from: user1})
            var coverageID = 0
            var decision = true
            var userBalanceBefore = await web3.eth.getBalance(user1)
            const tx = await instance.resolveClaim(coverageID, decision, {from: owner})
            var userBalanceAfter = await web3.eth.getBalance(user1)
            if (tx.logs[0].event == "ClaimPayedOut") {
                event1Emitted = true
            }
            if (tx.logs[1].event == "ClaimResolved") {
                event2Emitted = true
            }
            assert.ok(tx.receipt.status, 'claim is successfully resolved')
            assert.strictEqual(Number(userBalanceAfter), Number(userBalanceBefore) + 50, 'the user received the correct payout')
            assert.strictEqual(event1Emitted, true, 'resolveClaim emits a ClaimPayedOut event')
            assert.strictEqual(event2Emitted, true, 'resolveClaim emits a ClaimResolved event')
        });
    });
})