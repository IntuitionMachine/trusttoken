var TrustToken = artifacts.require("./TrustToken.sol");

module.exports = function(deployer) {
  deployer.deploy(TrustToken);
};
