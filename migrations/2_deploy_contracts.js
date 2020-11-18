var CapitalPool = artifacts.require("./CapitalPool.sol");

module.exports = function(deployer) {
  //deployer.deploy(SimpleBank);
  deployer.deploy(CapitalPool);
};