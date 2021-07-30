// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import { Discounting } from "./discounting.sol";

interface ShelfLike {
    function shelf(uint loan) external view returns (address registry, uint tokenId);
    function nftlookup(bytes32 nftID) external returns (uint loan);
}

interface PileLike {
    function setRate(uint loan, uint rate) external;
    function debt(uint loan) external view returns (uint);
    function pie(uint loan) external returns (uint);
    function changeRate(uint loan, uint newRate) external;
    function loanRates(uint loan) external returns (uint);
    function file(bytes32, uint, uint) external;
    function rates(uint rate) external view returns (uint, uint, uint ,uint48, uint);
    function total() external view returns (uint);
    function rateDebt(uint rate) external view returns (uint);
}

// The NAV Feed contract extends the functionality of the NFT Feed by the Net Asset Value (NAV) computation of a Tinlake pool.
// NAV is computed as the sum of all discounted future values (fv) of ongoing loans (debt > 0) in the pool.
// The applied discountRate is dependant on the maturity data of the underlying collateral. The discount decreases with the maturity date approaching.
// To optimize the NAV calculation the discounting of future values happens bucketwise. FVs from assets with the same maturity date are added to one bucket.
// This safes iterations & gas, as the same discountRates can be applied per bucket.
abstract contract NAVFeed is Auth, Discounting {

    PileLike    public pile;
    ShelfLike   public shelf;

    mapping (uint => uint)      public ceilingRatio;    // risk => ceilingRatio
    mapping (bytes32 => uint)   public maturityDate;    // nftID => maturityDate
    mapping (uint => uint)      public thresholdRatio;  // risk => thresholdRatio
    mapping (uint => Fixed27)   public recoveryRatePD;  // risk => recoveryRatePD
    mapping (bytes32 => uint)   public risk;            // nftID => risk
    mapping (bytes32 => uint)   public nftValues;       // nftID => nftValues
    mapping (bytes32 => uint)   public futureValue;     // nftID => futureValue
    mapping (uint => uint)      public borrowed;        // loan => borrowed
    mapping (uint => bool)      public writeOffOverride;// loan => writeOffOverride
    mapping (uint => uint)      public buckets;         // timestamp => bucket

    // last time the NAV was updated
    uint public lastNAVUpdate;

    struct WriteOffGroup {
        // denominated in (10^27)
        Fixed27 percentage;
        // amount of days after the maturity days that the writeoff group can be applied by default
        uint overdueDays;
    }

    uint public constant WRITEOFF_RATE_GROUP_START = 1000;

    WriteOffGroup[] public writeOffGroups;

    // discount rate applied on every asset's fv depending on its maturityDate. The discount decreases with the maturityDate approaching.
    Fixed27 public discountRate;

    // latestNAV is calculated in case of borrows & repayments between epoch executions.
    // It decreases/increases the NAV by the repaid/borrowed amount without running the NAV calculation routine.
    // This is required for more accurate Senior & JuniorAssetValue estimations between epochs
    uint public latestNAV;
    uint public latestDiscount;

    event Depend(bytes32 indexed name, address addr);
    event File(bytes32 indexed name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_);
    event Update(bytes32 indexed nftID, uint value);
    event Update(bytes32 indexed nftID, uint value, uint risk);
    event File(bytes32 indexed name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_);
    event File(bytes32 indexed name, bytes32 nftID_, uint maturityDate_);
    event File(bytes32 indexed name, uint value);

    constructor () {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function init() public virtual;
    function ceiling(uint loan) public virtual view returns (uint);

    // --- Actions ---
    function borrow(uint loan, uint amount) external auth returns(uint navIncrease) {
        calcUpdateNAV();

        // In case of successful borrow the latestNAV is increased by the borrowed amount
        navIncrease = _borrow(loan, amount);
        latestDiscount = safeAdd(latestDiscount, navIncrease);
        latestNAV = safeAdd(latestNAV, navIncrease);
        return navIncrease;
    }

    function _borrow(uint loan, uint amount) internal returns(uint navIncrease) {
        require(ceiling(loan) >= amount, "borrow-amount-too-high");

        bytes32 nftID_ = nftID(loan);
        uint maturityDate_ = maturityDate[nftID_];
        require(maturityDate_ > block.timestamp, "maturity-date-is-not-in-the-future");

        // calculate amount including fixed fee if applicatable
        (, , , , uint fixedRate) = pile.rates(pile.loanRates(loan));
        uint amountIncludingFixed =  safeAdd(amount, rmul(amount, fixedRate));

        // calculate future value FV
        (, ,uint loanInterestRate, ,) = pile.rates(pile.loanRates(loan));
        uint fv = calcFutureValue(loanInterestRate, amountIncludingFixed, maturityDate_, recoveryRatePD[risk[nftID_]].value);
        futureValue[nftID_] = safeAdd(futureValue[nftID_], fv);

        // add future value to the bucket of assets with the same maturity date
        buckets[maturityDate_] = safeAdd(buckets[maturityDate_], fv);

        // increase borrowed amount for future ceiling computations
        borrowed[loan] = safeAdd(borrowed[loan], amount);

        // return increase NAV amount
        return calcDiscount(discountRate.value, fv, uniqueDayTimestamp(block.timestamp), maturityDate_);
    }

    function repay(uint loan, uint amount) external auth returns (uint navDecrease) {
        calcUpdateNAV();

        // In case of successful repayment the latestNAV is decreased by the repaid amount
        navDecrease = _repay(loan, amount);

        // assuming latestNAV is always >= latestDiscount
        if(navDecrease < latestDiscount) {
            latestDiscount = safeSub(latestDiscount, navDecrease);
            latestNAV = safeSub(latestNAV, navDecrease);

            return navDecrease;
        }
        latestNAV = 0;
        latestDiscount = 0;
        return navDecrease;
    }

    function _repay(uint loan, uint amount) internal returns (uint navDecrease) {
        bytes32 nftID_ = nftID(loan);
        uint maturityDate_ = maturityDate[nftID_];
        uint nnow = uniqueDayTimestamp(block.timestamp);

        // no fv decrease calculation needed if maturity date is in the past
        // repayment on maturity date is fine
        // unique day timestamp is always 00:00 am
        if (maturityDate_ < nnow) {
            return 0;
        }

        // remove future value for loan from bucket
        buckets[maturityDate_] = safeSub(buckets[maturityDate_], futureValue[nftID_]);

        uint debt = pile.debt(loan);
        debt = safeSub(debt, amount);

        uint fv = 0;
        uint preFutureValue = futureValue[nftID_];

        // in case of partial repayment, compute the fv of the remaining debt and add to the according fv bucket
        if (debt != 0) {
            (, ,uint loanInterestRate, ,) = pile.rates(pile.loanRates(loan));
            fv = calcFutureValue(loanInterestRate, debt, maturityDate_, recoveryRatePD[risk[nftID_]].value);
            buckets[maturityDate_] = safeAdd(buckets[maturityDate_], fv);
        }

        futureValue[nftID_] = fv;

        // return decrease NAV amount
        return calcDiscount(discountRate.value, safeSub(preFutureValue, fv), uniqueDayTimestamp(block.timestamp), maturityDate_);
    }

    function borrowEvent(uint loan) public auth {
        uint risk_ = risk[nftID(loan)];

        // when issued every loan has per default interest rate of risk group 0.
        // correct interest rate has to be set on first borrow event
        if (pile.loanRates(loan) != risk_) {
            // set loan interest rate to the one of the correct risk group
            pile.setRate(loan, risk_);
        }
    }

    function unlockEvent(uint loan) public auth {}

    function writeOff(uint loan, uint writeOffGroupIndex_) public {
        require(!writeOffOverride[loan], "already-overridden");

        bytes32 nftID_ = nftID(loan);
        WriteOffGroup memory writeOffGroup_ = writeOffGroups[writeOffGroupIndex_];
        require(block.timestamp >= maturityDate[nftID_] + writeOffGroup_.overdueDays, "too-early");

        uint currentRate = pile.loanRates(loan);
        require(writeOffGroup_.percentage.value > writeOffGroups[currentRate].percentage.value, "cannot-decrease-writeoff");

        pile.changeRate(loan, WRITEOFF_RATE_GROUP_START + writeOffGroupIndex_);
    }

    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) public auth {
        writeOffOverride[loan] = true;
        pile.changeRate(loan, WRITEOFF_RATE_GROUP_START + writeOffGroupIndex_);
    }

    // --- NAV calculation ---
    function currentNAV() public view returns(uint) {
        return safeAdd(currentDiscount(), currentWriteOffs());
    }

    function currentDiscount() public view returns(uint) {
        if (latestDiscount == 0) {
            return 0;
        }

        uint nnow = uniqueDayTimestamp(block.timestamp);
        uint nLastUpdate = uniqueDayTimestamp(lastNAVUpdate);

        uint totalDiscount = rmul(latestDiscount, rpow(discountRate.value, safeSub(nnow, nLastUpdate), ONE));

        // Loop over the loans which matured in between the last NAV update and now.
        // Then remove their discounted future value from the total discount as they are overdue.
        uint diff = 0;
        for(uint i = nLastUpdate; i < nnow; i = i + 1 days) {
            diff = safeAdd(diff, rmul(buckets[i], rpow(discountRate.value, safeSub(nnow, i), ONE)));
        }

        totalDiscount = secureSub(totalDiscount, diff);
        // TODO: fix rounding errors that this if statement is not required anymore
        if(totalDiscount == 1) {
            return 0;
        }
        return totalDiscount;
    }

    function currentWriteOffs() public view returns(uint) {
        // include ovedue assets to the current NAV calculation
        uint sum = 0;
        for (uint i = 0; i < writeOffGroups.length; i++) {
            // multiply writeOffGroupDebt with the writeOff rate
            sum = safeAdd(sum, rmul(pile.rateDebt(WRITEOFF_RATE_GROUP_START + i), writeOffGroups[i].percentage.value));
        }
        return sum;
    }

    function calcUpdateNAV() public returns(uint) {
        latestDiscount = currentDiscount();
        latestNAV = safeAdd(latestDiscount, currentWriteOffs());
        lastNAVUpdate = block.timestamp;
        return latestNAV;
    }

    // --- Administration ---
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "pile") {pile = PileLike(addr);}
        else if (contractName == "shelf") { shelf = ShelfLike(addr); }
        else revert();
        emit Depend(contractName, addr);
    }

    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_) public auth  {
        if(name == "riskGroup") {
            file("riskGroupNFT", risk_, thresholdRatio_, ceilingRatio_, rate_);
            recoveryRatePD[risk_] = Fixed27(recoveryRatePD_);
            emit File(name, risk_, thresholdRatio_, ceilingRatio_, rate_, recoveryRatePD_);

        } else { revert ("unknown name");}
    }

    function file(bytes32 name, bytes32 nftID_, uint maturityDate_) public auth {
        // maturity date only can be changed when there is no debt on the collateral -> futureValue == 0
        if (name == "maturityDate") {
            require((futureValue[nftID_] == 0), "can-not-change-maturityDate-outstanding-debt");
            maturityDate[nftID_] = uniqueDayTimestamp(maturityDate_);
            emit File(name, nftID_, maturityDate_);

        } else { revert("unknown config parameter");}
    }

    function file(bytes32 name, uint value) public auth {
        if (name == "discountRate") {
            discountRate = Fixed27(value);
            // TODO: recalculateDiscount()
            emit File(name, value);

        } else { revert("unknown config parameter");}
    }

    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_) public auth {
        if(name == "riskGroupNFT") {
            require(ceilingRatio[risk_] == 0, "risk-group-in-usage");
            thresholdRatio[risk_] = thresholdRatio_;
            ceilingRatio[risk_] = ceilingRatio_;

            // set interestRate for risk group
            pile.file("rate", risk_, rate_);
            emit File(name, risk_, thresholdRatio_, ceilingRatio_, rate_);

        } else { revert ("unknown name");}
    }

    function file(bytes32 name, uint rate_, uint writeOffPercentage_, uint overdueDays_) public auth {
        if(name == "writeOffGroup") {
            uint index = writeOffGroups.length;
            writeOffGroups.push(WriteOffGroup(Fixed27(writeOffPercentage_), overdueDays_));
            pile.file("rate", WRITEOFF_RATE_GROUP_START + index, rate_);

        } else { revert ("unknown name");}
    }

    function update(bytes32 nftID_,  uint value) public auth {
        // switch of collateral risk group results in new: ceiling, threshold for existing loan
        nftValues[nftID_] = value;
        emit Update(nftID_, value);
    }

    function update(bytes32 nftID_, uint value, uint risk_) public auth {
        nftValues[nftID_] = value;

        // no change in risk group
        if (risk_ == risk[nftID_]) {
            return;
        }

        // nfts can only be added to risk groups that are part of the score card
        require(thresholdRatio[risk_] != 0, "risk group not defined in contract");
        risk[nftID_] = risk_;

        // no currencyAmount borrowed yet
        if (futureValue[nftID_] == 0) {
            return;
        }

        uint loan = shelf.nftlookup(nftID_);
        uint maturityDate_ = maturityDate[nftID_];

        // Changing the risk group of an nft, might lead to a new interest rate for the dependant loan.
        // New interest rate leads to a future value.
        // recalculation required
        buckets[maturityDate_] = safeSub(buckets[maturityDate_], futureValue[nftID_]);

        (, ,uint loanInterestRate, ,) = pile.rates(pile.loanRates(loan));
        futureValue[nftID_] = calcFutureValue(loanInterestRate, pile.debt(loan), maturityDate[nftID_], recoveryRatePD[risk[nftID_]].value);
        buckets[maturityDate_] = safeAdd(buckets[maturityDate_], futureValue[nftID_]);

        emit Update(nftID_, value, risk_);
    }

    // --- Utilities ---
    // returns the threshold of a loan
    // if the loan debt is above the loan threshold the NFT can be seized
    function threshold(uint loan) public view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        return rmul(nftValues[nftID_], thresholdRatio[risk[nftID_]]);
    }

    // returns a unique id based on the nft registry and tokenId
    // the nftID is used to set the risk group and value for nfts
    function nftID(address registry, uint tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(registry, tokenId));
    }

    // returns the nftID for the underlying collateral nft
    function nftID(uint loan) public view returns (bytes32) {
        (address registry, uint tokenId) = shelf.shelf(loan);
        return nftID(registry, tokenId);
    }

}