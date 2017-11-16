pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';

contract TrustToken is MintableToken {
  string public constant name = "Trust Token";
  string public constant symbol = "TRU";
  uint8 public constant decimals = 18;
  uint256 public constant INITIAL_SUPPLY = 0;

  function TrustToken() {
	  totalSupply = INITIAL_SUPPLY;
  }
}

