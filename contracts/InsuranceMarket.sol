pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './TrustToken.sol';

contract InsuranceMarket is Ownable {
    using SafeMath for uint256;

    // Each insurer's total amount staked across all fiduciaries must be at most
    // this factor times their actual backingBucket.
    uint8 BACKING_FACTOR public constant = 10;

    // The contract governing TRU. It can reliably tell us when we've been paid
    TrustToken truContract;

    struct InsurerInfo {
        //The total amount of TRU the insurer is tying up on the blockchain
        uint256 backingBucket;
        //The maximum amount the insurer has staked on any single fiduciary.
        //This must be at most backingBucket. TODO currently this is never reevaluated downward
        uint256 maxStake;
        //The total sum the insurer has staked on all fiduciaries.
        uint256 totalStake;
        //How much the insurer is staking on each fiduciary and at what price
        mapping (address => Listing) listings;
    }

    struct Listing {
        uint256 price; // the cost to be insured for 1 TRU (NOT 1 TWei, or whatever we want to call our smallest unit) for 1 block
        uint256 cap; // the maximum this insurer will insure you to
        uint256 inUse; // the amount of the cap currently purchased by trusts
        mapping (address => Subscription) subscriptions;
    }

    struct Subscription {
        uint256 amountInsured;
        uint256 expirationBlock; // the purchased insurance is valid until this block number
    }

    mapping (address => InsurerInfo) public infos;

    function InsuranceMarket(address _truContract) public {
        truContract = TrustToken(_truContract);
    }

    // to be called only by the TRU contract; indicates an insurer has added value to their bucket
    function updateBalance(address insurer, uint256 value) public {
        require(msg.sender == address(truContract));
        infos[insurer].backingBucket = infos[insurer].backingBucket.add(value);
    }

    // called by an insurer to withdraw value from their bucket. Only allowed if this would leave their current listings sufficiently backed
    function withdraw(uint256 value) public {
        infos[msg.sender].backingBucket = infos[msg.sender].backingBucket.sub(value);
        sanityCheck(msg.sender);
        truContract.approve(msg.sender, value); //TODO should *add to* approval, not replace it
    }

    //TODO use more SafeMath
    // returns the ceiling of dividend/divisor
    function divRoundUp(uint256 dividend, uint256 divisor) public pure returns (uint256) {
        require(dividend + divisor > dividend); // avoid overflows
        return (dividend + divisor - 1) / divisor;
    }

    // add or change a listing. TODO currently can't change the price of a listing if anyone
    // has subscribed even to a fraction of it; this is overly restrictive.
    function updateListing(address fiduciary, uint256 price, uint256 cap) {
        Listing memory currentListing = infos[msg.sender].listings[fiduciary];
        if (currentListing.inUse > 0 && (currentListing.price != price || cap < currentListing.inUse)) {
            revert();
        }
        infos[msg.sender].totalStake = infos[msg.sender].totalStake.sub(currentListing.cap).add(cap);
        if (cap > infos[msg.sender].maxStake) {
            infos[msg.sender].maxStake = cap;
        }
        sanityCheck(msg.sender);
        infos[msg.sender].listings[fiduciary] = Listing(price, cap, currentListing.inUse);
    }

    // Make sure that insurer has sufficient TRU in their bucket to cover their stakes,
    // under the rules that the bucket must be at least as big as the stake on each individual
    // fiduciary, and must also be at least BACKING_FACTOR times bigger than the sum of all their
    // stakes.
    function sanityCheck(address insurer) view private {
        require(infos[insurer].backingBucket >= infos[insurer].maxStake);
        require(infos[insurer].backingBucket >= divRoundUp(infos[insurer].totalStake, BACKING_FACTOR));
    }

    // A trust must first 'approve' this contract to transfer the TRU payment
    // Then it can call subscribe to pay for an insurance limit of insuranceCap
    // for the trust managed by fiduciary. The length of time the insurance is
    // valid for will be computed from these values and the price. If the trust
    // had already bought insurance from this insurer that had not yet expired,
    // that insurance will be converted back into additional payment and used to
    // automatically extend how long this one lasts.
    function subscribe(address insurer, address fiduciary, uint256 insuranceCap, uint256 payment) {
        if (payment == 0) return;
        if (!truContract.transferFrom(msg.sender, this, payment)) revert();
        Listing storage listing = infos[insurer].listings[fiduciary]; //TODO make sure this is how storage pointers work
        uint256 oldCredit;
        if (listing.subscriptions[msg.sender].expirationBlock < block.number) {
            oldCredit = 0;
        } else {
            uint256 subscriptionTimeRemaining = listing.subscriptions[msg.sender].expirationBlock.sub(block.now)
            oldCredit = listing.subscriptions[msg.sender].amountInsured.mul(subscriptionTimeRemaining).mul(listing.price).div(10**truContract.decimals)
        }
        uint256 newCredit = oldCredit + payment;
        uint256 newTimeRemaining = newCredit.mul(10**truContract.decimals).div(insuranceCap).div(listing.price);
        listing.subscriptions[msg.sender] = Subscription(insuranceCap, block.number.add(newTimeRemaining));
    }
}
