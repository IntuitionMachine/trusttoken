pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/token/MintableToken.sol';
import './InsuranceMarket.sol';

contract TrustToken is MintableToken {
    string public constant name = "TrustToken";
    string public constant symbol = "TRU";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 0;

    InsuranceMarket insuranceMarket; //TODO set this

    function TrustToken() public {
        totalSupply = INITIAL_SUPPLY;
    }

    // Transfer the tokens and also let the insurance
    // contract know so it can update your balance. Basically
    // a specialized transferAndCall a la ERC677
    function tranferToInsuranceStake(uint256 value) public {
        transfer(insuranceMarket, value);
        insuranceMarket.updateBalance(msg.sender, value);
    }
}
