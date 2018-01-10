pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TrustToken.sol';

contract InsuranceMarket is Ownable {
    using SafeMath for uint256;
    TrustToken truContract;

    struct InsurerInfo {
        uint256 backingBucket;
        uint256 maxStake; //TODO currently this is never reevaluated downward
        uint256 totalStake;
        mapping (address => Listing) listings;
    }

    struct Listing {
        uint256 price; // the cost per month to be insured for *1 full TRU*
        uint256 cap; // the maximum this insurer will insure you to
        uint256 inUse; // the amount of the cap currently purchased by trusts
    }

    mapping (address => InsurerInfo) public infos;

    function InsuranceMarket(address _truContract) public {
        truContract = TrustToken(_truContract);
    }

    function updateBalance(address insurer, uint256 value) public {
        require(msg.sender == address(truContract));
        infos[insurer].backingBucket = infos[insurer].backingBucket.add(value);
    }

    function withdraw(uint256 value) public {
        infos[msg.sender].backingBucket = infos[msg.sender].backingBucket.sub(value);
        sanityCheck(msg.sender);
        truContract.approve(msg.sender, value); //TODO should *add to* approval, not replace it
    }

    //TODO use more SafeMath
    function divRoundUp(uint256 dividend, uint256 divisor) public pure returns (uint256) {
        require(dividend + divisor > dividend); // avoid overflows
        return (dividend + divisor - 1) / divisor;
    }

    function updateListing(address fiduciary, uint256 price, uint256 cap) {
        Listing memory currentListing = infos[msg.sender].listings[fiduciary];
        if (currentListing.inUse > 0 && (currentListing.price < price || cap < currentListing.inUse)) {
            revert();
        }
        infos[msg.sender].totalStake = infos[msg.sender].totalStake.sub(currentListing.cap).add(cap);
        if (cap > infos[msg.sender].maxStake) {
            infos[msg.sender].maxStake = cap;
        }
        sanityCheck(msg.sender);
        infos[msg.sender].listings[fiduciary] = Listing(price, cap, currentListing.inUse);
    }

    function sanityCheck(address insurer) view private {
        require(infos[insurer].backingBucket >= infos[insurer].maxStake);
        require(infos[insurer].backingBucket >= divRoundUp(infos[insurer].totalStake, 10));
    }
}
