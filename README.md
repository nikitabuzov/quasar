# Quasar
**Risk sharing platform to cover for potential bugs in smart contracts.**
***

## What is Quasar?
***
Quasar is a mutual-like risk sharing platform with an objective to provide affordable coverage against smart contract bugs and failures. Users can purchase coverage for the risk they're exposed through using DeFi platforms like Maker, Aave, Compound, etc. On the other hand, coverage (i.e. liquidity) providers can deposit capital to earn fees and rewards in Quasar (QSR) native token. If one the covered smart contracts have been broken, coverage holders can open a claim and the contract owner will resolve it. In case the claim is valid, a payout in the covered amount will be made by the contract from the capital pool.

## How to use Quasar? (local setup)
***
This app can be used and tested either by running a local Ganache ethereum blockchain or by interacting with the contract deployed to Rinkeby Testnet.
Rinkeby addresses for the Pool and QuasarToken contracts are located in deployed_addresses.txt document.
*Prerequisites*: please install Metamask browser extension, Truffle, Ganache, and Node.js
### Local Ganache Network
Deploy contracts:
1. clone this repository (quasar-core) onto your local computer;
2. clone [quasar-client](https://github.com/nikitabuzov/quasar-client) into your local quasar-core directory;
3. from inside the quasar-core directory, run `truffle compile` command;
4. start the local ganache network and update, if needed, truffle-config.js file with the correct network variables;
5. if you'd like to run tests on the smart contracts, run `truffle test` command;
6. then run `truffle migrate` to deploy the contracts to the local network.

Setup the client:
1. copy and paste the new deployed contract addresses into quasar-client/src/App.js;
2. from inside the quasar-client directory run `npm install` to install the required dependencies;
2. from inside the quasar-client directory run `yarn start` to start the local server for web interface;
3. now you can access the interface at http://localhost:3000/ and interact with the contracts through the UI and Metamask extension;
4. setup Metamask by switching to your local Ganache network and importing the seed phrase.


### Rinkeby Network
Follow the directions above with just a few differences:
- don't have to deploy the contracts yourself by running `truffle migrate` since the contracts have been deployed;
- copy and paste the deployed contract addresses into quasar-client/src/App.js from deployed_addresses.txt;
- switch Metamask to Rinkeby Network and fund your account with Rinkeby ether from the [faucet](https://faucet.rinkeby.io/).


