var CapitalPool = artifacts.require("./CapitalPool.sol");
var QuasarToken = artifacts.require("./QuasarToken.sol");

module.exports = function(deployer) {
  //deployer.deploy(SimpleBank);
  deployer.deploy(CapitalPool);
  deployer.deploy(QuasarToken);
};