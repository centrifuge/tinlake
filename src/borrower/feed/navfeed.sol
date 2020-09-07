// Copyright (C) 2020 Centrifuge
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.5.15 <0.6.0;
pragma experimental ABIEncoderV2;

import "ds-note/note.sol";
import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";
import "./nftfeed.sol";
import "./buckets.sol";
import "../../fixed_point.sol";

contract NAVFeed is BaseNFTFeed, Interest, Buckets, FixedPoint {
    // nftID => maturityDate
    mapping (bytes32 => uint) public maturityDate;

    // risk => recoveryRatePD
    mapping (uint => Fixed27) public recoveryRatePD;

    // nftID => futureValue
    mapping (bytes32 => uint) public futureValue;

    WriteOff [2] public writeOffs;

    struct WriteOff {
        uint rateGroup;
        // denominated in (10^27)
        Fixed27 percentage;
    }

    Fixed27 public discountRate;

    // approximated NAV
    uint public approximatedNAV;

    constructor () public {
        wards[msg.sender] = 1;
    }

    function init() public {
        super.init();
        // gas optimized initialization of writeOffs
        // write off are hardcoded in the contract instead of init function params

        // risk group recoveryRatePD
        recoveryRatePD[0] = Fixed27(ONE);
        recoveryRatePD[1] = Fixed27(90 * 10**25);

        // todo change to != 0, breaks currently some system tests
        recoveryRatePD[2] = Fixed27(0);
        recoveryRatePD[3] = Fixed27(ONE);
        recoveryRatePD[4] = Fixed27(ONE);


        // 60% -> 40% write off
        // 91 is a random sample for a rateGroup in pile for overdue loans
        writeOffs[0] = WriteOff(91, Fixed27(6 * 10**26));
        // 80% -> 20% write off
        // 90 is a random sample for a rateGroup in pile for overdue loans
        writeOffs[1] = WriteOff(90, Fixed27(8 * 10**26));

    }

    function uniqueDayTimestamp(uint timestamp) public pure returns (uint) {
        return (1 days) * (timestamp/(1 days));
    }

    /// maturityDate is a unix timestamp
    function file(bytes32 what, bytes32 nftID_, uint maturityDate_) public auth {
        if (what == "maturityDate") {
            maturityDate[nftID_] = uniqueDayTimestamp(maturityDate_);
        } else { revert("unknown config parameter");}
    }

    function file(bytes32 name, uint value) public auth {
        if (name == "discountRate") {
            discountRate = Fixed27(value);
        } else { revert("unknown config parameter");}
    }

    /// Ceiling Implementation
    function borrow(uint loan, uint amount) external auth returns(uint navIncrease) {
        uint navIncrease = _borrow(loan, amount);
        approximatedNAV = safeAdd(approximatedNAV, navIncrease);
        return navIncrease;
    }

    function _borrow(uint loan, uint amount) internal returns(uint navIncrease) {
        // ceiling check uses existing loan debt
        require(ceiling(loan) >= safeAdd(borrowed[loan], amount), "borrow-amount-too-high");

        bytes32 nftID_ = nftID(loan);
        uint maturityDate_ = maturityDate[nftID_];
        require(maturityDate_ > block.timestamp, "maturity-date-is-not-in-the-future");

        // calculate future value FV
        uint fv = calcFutureValue(loan, amount, maturityDate_, recoveryRatePD[risk[nftID_]].value);
        futureValue[nftID_] = safeAdd(futureValue[nftID_], fv);

        if (buckets[maturityDate_].value == 0) {
            addBucket(maturityDate_, fv);
        } else {
            buckets[maturityDate_].value = safeAdd(buckets[maturityDate_].value, fv);
        }

        borrowed[loan] = safeAdd(borrowed[loan], amount);

        // return increase NAV amount
        return calcDiscount(fv, uniqueDayTimestamp(block.timestamp), maturityDate_);
    }

    function calcFutureValue(uint loan, uint amount, uint maturityDate_, uint recoveryRatePD_) public returns(uint) {
        (, ,uint loanInterestRate, ,) = pile.rates(pile.loanRates(loan));
        return rmul(rmul(rpow(loanInterestRate,  safeSub(maturityDate_, uniqueDayTimestamp(now)), ONE), amount), recoveryRatePD_);
    }

    /// update the nft value and change the risk group
    function update(bytes32 nftID_, uint value, uint risk_) public auth {
        nftValues[nftID_] = value;

        // no change in risk group
        if (risk_ == risk[nftID_]) {
            return;
        }

        require(thresholdRatio[risk_] != 0, "risk group not defined in contract");
        risk[nftID_] = risk_;

        // no currencyAmount borrowed yet
        if (futureValue[nftID_] == 0) {
            return;
        }

        uint loan = shelf.nftlookup(nftID_);
        uint maturityDate_ = maturityDate[nftID_];

        // calculate future value FV
        buckets[maturityDate_].value = safeSub(buckets[maturityDate_].value, futureValue[nftID_]);

        futureValue[nftID_] = calcFutureValue(loan, pile.debt(loan), maturityDate[nftID_], recoveryRatePD[risk[nftID_]].value);
        buckets[maturityDate_].value = safeAdd(buckets[maturityDate_].value, futureValue[nftID_]);
    }

    function repay(uint loan, uint amount) external auth returns (uint navDecrease) {
        uint navDecrease = _repay(loan, amount);
        if (navDecrease > approximatedNAV) {
            approximatedNAV = 0;
        }

        if(navDecrease < approximatedNAV) {
            approximatedNAV = safeSub(approximatedNAV, navDecrease);
            return navDecrease;
        }
        approximatedNAV = 0;
        return navDecrease;
    }

    function _repay(uint loan, uint amount) internal returns (uint navDecrease) {
        bytes32 nftID_ = nftID(loan);
        uint maturityDate_ = maturityDate[nftID_];

        // remove future value for loan from bucket
        buckets[maturityDate_].value = safeSub(buckets[maturityDate_].value, futureValue[nftID_]);

        uint debt = pile.debt(loan);

        debt = safeSub(debt, amount);

        uint fv = 0;
        uint preFutureValue = futureValue[nftID_];

        if (debt != 0) {
            // calculate new future value for loan if debt is still existing
            fv = calcFutureValue(loan, debt, maturityDate_, recoveryRatePD[risk[nftID_]].value);
            buckets[maturityDate_].value = safeAdd(buckets[maturityDate_].value, fv);
            futureValue[nftID_] = fv;
        }

        if (buckets[maturityDate_].value == 0 && firstBucket != 0) {
            removeBucket(maturityDate_);
        }

        // return decrease NAV amount
        if (block.timestamp < maturityDate_) {
            return calcDiscount(safeSub(preFutureValue, fv), uniqueDayTimestamp(block.timestamp), maturityDate_);
        }

        // if a loan is overdue the portfolio value is equal to the existing debt multiplied with a write off factor
        // todo multiply amount with write-off factor
        return amount;
    }

    function calcDiscount(uint amount, uint normalizedBlockTimestamp, uint maturityDate) public view returns (uint result) {
        return rdiv(amount, rpow(discountRate.value, safeSub(maturityDate, normalizedBlockTimestamp), ONE));
    }

    function calcTotalDiscount() public view returns(uint) {
        uint normalizedBlockTimestamp = uniqueDayTimestamp(block.timestamp);
        uint sum = 0;

        uint currDate = normalizedBlockTimestamp;

        if (currDate > lastBucket) {
            return 0;
        }

        while(buckets[currDate].next == 0) { currDate = currDate + 1 days; }

        while(currDate != NullDate)
        {
            sum = safeAdd(sum, calcDiscount(buckets[currDate].value, normalizedBlockTimestamp, currDate));
            currDate = buckets[currDate].next;
        }
        return sum;
    }

    /// returns the NAV (net asset value) of the pool
    function currentNAV() public view returns(uint) {
        uint nav_ = calcTotalDiscount();

        // add write offs to NAV
        for (uint i = 0; i < writeOffs.length; i++) {
            (uint pie, uint chi, , ,) = pile.rates(writeOffs[i].rateGroup);
            nav_ = safeAdd(nav_, rmul(rmul(pie, chi), writeOffs[i].percentage.value));
        }
        return nav_;
    }

    function calcUpdateNAV() public returns(uint) {
        // approximated NAV is updated and at this point in time 100% correct
        approximatedNAV = currentNAV();
        return approximatedNAV;
    }

    /// workaround for transition phase between V2 & V3
    function totalValue() public view returns(uint) {
        return currentNAV();
    }

    function dateBucket(uint timestamp) public view returns (uint) {
        return buckets[timestamp].value;
    }
}
