var Pool = artifacts.require("./Pool.sol");
var QuasarToken = artifacts.require("./QuasarToken.sol");

module.exports = function(deployer) {
  //deployer.deploy(SimpleBank);
  deployer.deploy(Pool);
  deployer.deploy(QuasarToken);
};