pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TrustToken.sol';

contract InsuranceMarket is Ownable {
    using SafeMath for uint256;
    TrustToken truContract;

    mapping (address => uint256) public stakeBuckets;

    function InsuranceMarket(address _truContract) public {
        truContract = TrustToken(_truContract);
    }

    function updateBalance(address insurer, uint256 value) public {
        require(msg.sender == address(truContract));
        stakeBuckets[insurer] = stakeBuckets[insurer].add(value);
    }
}
