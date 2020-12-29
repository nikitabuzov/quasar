# Design Patterns
this document describes various design patterns and practices used to write the smart contracts

### Libraries and Code Reuse
In order to streamline the development with audited and battle-tested code the following libraries and presets have been utilized for this project:
1. [SafeMath](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol): used for all integer operations in order to avoid arithmetic overflows and underflows.
2. [ERC20PresetMinterPauser](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/presets/ERC20PresetMinterPauser.sol): used to implement the Quasar ERC20 token.
3. [SafeERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol): used for ERC20 interface.
4. [ReentrancyGuard](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol): used to mitigate potential risk of reentrant function calls.
5. [Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol): used to inherit `onlyOwner` function modifier to restrict access of certain function calls to the owner of the contract.

### Truffle Tests
A thorough suite of tests have been developed to test every mutative function across both Pool and QuasarToken contracts.
**1. Pool.test.js**
- test if the owner can change the coverage price;
- buying coverage: test different scenarios when users provide invalid coverage period/amount or don't pay enough, as well as valid purchases;
- capital pool deposits/withdrawals: test valid deposits and withdrawals, make sure capital providers can't withdraw more than they have deposited or more than needed to cover all possible current and future claims (i.e. satisfy minimum capital requirement)
- coverage claims: check that holders of valid coverage plans can open claims, the owner can resolve claim, and valid claims receive payouts.
**2. QuasarToken.test.js**
Since the token is implemented using the OpenZeppelin preset, I have used their [test](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/presets/ERC20PresetMinterPauser.test.js).

**3. exceptionsHelpers.js**
This additional .js file has helpful try-catch function to handle different kinds of function call errors.

### Gas and Storage Optimization
1. The contracts don't use any loops to modify storage variables, hence decreased gas costs.
2. All integers are specifically `uint256` because EVM works with 256 bit words. Since every operation is based on these units, if your data is smaller (say `uint8`), then further operations are needed to "downscale" 256 bits to 8 bits, ultimately increasing the gas cost.

### Circuit Breaker
Pool.sol contract has the circuit breaker modifier applied to all functions that deal with all deposits/withdrawals of the ETH capital pool and QSR rewards. The toggle switch is only available to the owner of the contract.