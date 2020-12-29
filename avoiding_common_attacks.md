# Security Measures
this document describes common relevant attack vectors and how I have addressed them

### 1. Re-entrancy Attacks (SWC-107)
In order to prevent reentrant calls to a function I have inherited `nonReentrant` modifier from `ReentrancyGuard` contract by OpenZeppelin.
This modifier can be applied to functions to make sure there are no nested (reentrant) calls to them.
Here's the link to the [contract](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol)

### 2. Integer Overflow and Underflow (SWC-101)
This arithmetic overflow/underflow threats were mitigated by using OpenZeppelin SafeMath library for all integer operations.
Here's the link to the [contract](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol)
