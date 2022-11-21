// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import {Discounting} from "./discounting.sol";

interface ShelfLike {
    function shelf(uint256 loan) external view returns (address registry, uint256 tokenId);
    function nftlookup(bytes32 nftID) external returns (uint256 loan);
    function loanCount() external view returns (uint256);
}

interface PileLike {
    function setRate(uint256 loan, uint256 rate) external;
    function debt(uint256 loan) external view returns (uint256);
    function pie(uint256 loan) external returns (uint256);
    function changeRate(uint256 loan, uint256 newRate) external;
    function loanRates(uint256 loan) external view returns (uint256);
    function file(bytes32, uint256, uint256) external;
    function rates(uint256 rate) external view returns (uint256, uint256, uint256, uint48, uint256);
    function total() external view returns (uint256);
    function rateDebt(uint256 rate) external view returns (uint256);
}

/// @notice NAVFeed contract calculates the Net Asset Value of a Tinlake pool.
/// NAV is computed as the sum of all discounted future values (fv) of ongoing loans (debt > 0) in the pool.
/// The applied discountRate is dependant on the maturity data of the underlying collateral.
/// The discount decreases with the maturity date approaching.
/// To optimize the NAV calculation, the NAV is calculated as the change in discounted future values
/// since the calculation. When loans are overdue, they are locked at their fv on the maturity date.
/// They can then be written off, using the public writeoff method based on
/// the default writeoff schedule, or using the override writeoff method.
contract NAVFeed is Auth, Discounting {
    PileLike public pile;
    ShelfLike public shelf;

    /// @notice details of the underlying collateral
    struct NFTDetails {
        uint128 nftValues;
        uint128 futureValue;
        uint128 maturityDate;
        uint128 risk;
    }

    /// @notice risk group details
    struct RiskGroup {
        // denominated in (10^27)
        uint128 ceilingRatio;
        // denominated in (10^27)
        uint128 thresholdRatio;
        // denominated in (10^27)
        uint128 recoveryRatePD;
    }

    /// @notice details of the loan
    struct LoanDetails {
        uint128 borrowed;
        // only auth calls can move loan into different writeOff group
        bool authWriteOff;
    }

    /// @notice details of the write off group
    struct WriteOffGroup {
        // denominated in (10^27)
        uint128 percentage;
        // amount of days after the maturity days that the writeoff group can be applied by default
        uint128 overdueDays;
    }

    // nft => details
    mapping(bytes32 => NFTDetails) public details;
    // risk => riskGroup
    mapping(uint256 => RiskGroup) public riskGroup;
    // loan => details
    mapping(uint256 => LoanDetails) public loanDetails;
    // timestamp => bucket
    mapping(uint256 => uint256) public buckets;

    WriteOffGroup[] public writeOffGroups;

    // Write-off groups will be added as rate groups to the pile with their index
    // in the writeOffGroups array + this number
    uint256 public constant WRITEOFF_RATE_GROUP_START = 1000;

    // Discount rate applied on every asset's fv depending on its maturityDate.
    // The discount decreases with the maturityDate approaching.
    // denominated in (10^27)
    uint256 public discountRate;

    // latestNAV is calculated in case of borrows & repayments between epoch executions.
    // It decreases/increases the NAV by the repaid/borrowed amount without running the NAV calculation routine.
    // This is required for more accurate Senior & JuniorAssetValue estimations between epochs
    uint256 public latestNAV;
    uint256 public latestDiscount;
    uint256 public lastNAVUpdate;

    // overdue loans are loans which passed the maturity date but are not written-off
    uint256 public overdueLoans;

    // events
    event Depend(bytes32 indexed name, address addr);
    event File(bytes32 indexed name, uint256 risk_, uint256 thresholdRatio_, uint256 ceilingRatio_, uint256 rate_);
    event Update(bytes32 indexed nftID, uint256 value);
    event Update(bytes32 indexed nftID, uint256 value, uint256 risk);
    event File(
        bytes32 indexed name,
        uint256 risk_,
        uint256 thresholdRatio_,
        uint256 ceilingRatio_,
        uint256 rate_,
        uint256 recoveryRatePD_
    );
    event File(bytes32 indexed name, bytes32 nftID_, uint256 maturityDate_);
    event File(bytes32 indexed name, uint256 value);
    event File(bytes32 indexed name, uint256 rate_, uint256 writeOffPercentage_, uint256 overdueDays_);
    event WriteOff(uint256 indexed loan, uint256 indexed writeOffGroupsIndex, bool override_);

    /// @notice getter function for the maturityDate
    /// @param nft_ the id of the nft based on the hash of registry and tokenId
    /// @return maturityDate_ the maturityDate of the nft
    function maturityDate(bytes32 nft_) public view returns (uint256 maturityDate_) {
        return uint256(details[nft_].maturityDate);
    }
    /// @notice getter function for the risk group
    /// @param nft_ the id of the nft based on the hash of registry and tokenId
    /// @return risk_ the risk group of the nft

    function risk(bytes32 nft_) public view returns (uint256 risk_) {
        return uint256(details[nft_].risk);
    }
    /// @notice getter function for the nft value
    /// @param nft_ the id of the nft based on the hash of registry and tokenId
    /// @return nftValue_ the value of the nft

    function nftValues(bytes32 nft_) public view returns (uint256 nftValue_) {
        return uint256(details[nft_].nftValues);
    }

    /// @notice getter function for the future value
    /// @param nft_ the id of the nft based on the hash of registry and tokenId
    /// @return fv_ future value of the loan
    function futureValue(bytes32 nft_) public view returns (uint256 fv_) {
        return uint256(details[nft_].futureValue);
    }
    /// @notice getter function for the ceiling Ratio
    /// @param riskID id of a risk group
    /// @return ceilingRatio_ the ceiling ratio of the risk group

    function ceilingRatio(uint256 riskID) public view returns (uint256 ceilingRatio_) {
        return uint256(riskGroup[riskID].ceilingRatio);
    }

    /// @notice getter function for the threshold Ratio
    /// @param riskID id of a risk group
    /// @return thresholdRatio_ threshold ratio of the risk group
    function thresholdRatio(uint256 riskID) public view returns (uint256 thresholdRatio_) {
        return uint256(riskGroup[riskID].thresholdRatio);
    }

    /// @notice getter function for the recovery rate PD
    /// @param riskID id of a risk group
    /// @return recoveryRatePD_ recovery rate PD of the risk group
    function recoveryRatePD(uint256 riskID) public view returns (uint256 recoveryRatePD_) {
        return uint256(riskGroup[riskID].recoveryRatePD);
    }

    /// @notice getter function for the borrowed amount
    /// @param loan id of a loan
    /// @return borrowed_ borrowed amount of the loan
    function borrowed(uint256 loan) public view returns (uint256 borrowed_) {
        return uint256(loanDetails[loan].borrowed);
    }

    constructor() {
        wards[msg.sender] = 1;
        lastNAVUpdate = uniqueDayTimestamp(block.timestamp);
        emit Rely(msg.sender);
    }

    /// @notice converts a uint256 to uint128
    /// @param value the value to be converted
    /// @return converted value to uint128
    function toUint128(uint256 value) internal pure returns (uint128 converted) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /// @notice returns the ceiling of a loan
    /// the ceiling defines the maximum amount which can be borrowed
    /// @param loan the id of the loan
    /// @return ceiling_ the ceiling of the loan
    function ceiling(uint256 loan) public view virtual returns (uint256 ceiling_) {
        bytes32 nftID_ = nftID(loan);
        uint256 initialCeiling = rmul(nftValues(nftID_), ceilingRatio(risk(nftID_)));

        if (borrowed(loan) > initialCeiling) {
            return 0;
        }

        return safeSub(initialCeiling, borrowed(loan));
    }

    /// @notice depend wires contract dependencies together
    /// @param contractName id of a contract dependency
    /// @param addr address of the contract dependency
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "pile") pile = PileLike(addr);
        else if (contractName == "shelf") shelf = ShelfLike(addr);
        else revert();
        emit Depend(contractName, addr);
    }

    /// @notice file allows governance to change parameters of the contract
    /// @param name name of the parameter group
    /// @param risk_ id of new risk group
    /// @param thresholdRatio_ new threshold ratio
    /// @param ceilingRatio_ new ceiling ratio
    /// @param interestRate_ new interest rate of the risk group
    /// @param recoveryRatePD_ new recovery rate PD of the risk group
    function file(
        bytes32 name,
        uint256 risk_,
        uint256 thresholdRatio_,
        uint256 ceilingRatio_,
        uint256 interestRate_,
        uint256 recoveryRatePD_
    ) public auth {
        if (name == "riskGroup") {
            file("riskGroupNFT", risk_, thresholdRatio_, ceilingRatio_, interestRate_);
            riskGroup[risk_].recoveryRatePD = toUint128(recoveryRatePD_);
            emit File(name, risk_, thresholdRatio_, ceilingRatio_, interestRate_, recoveryRatePD_);
        } else {
            revert("unknown name");
        }
    }

    /// @notice file allows governance to change parameters of the contract
    /// @param name name of the parameter group
    /// @param nftID_ the nft id of the nft
    /// @param maturityDate_ the maturity date of the nft
    function file(bytes32 name, bytes32 nftID_, uint256 maturityDate_) public auth {
        // maturity date only can be changed when there is no debt on the collateral -> futureValue == 0
        if (name == "maturityDate") {
            require((futureValue(nftID_) == 0), "can-not-change-maturityDate-outstanding-debt");
            details[nftID_].maturityDate = toUint128(uniqueDayTimestamp(maturityDate_));
            emit File(name, nftID_, maturityDate_);
        } else {
            revert("unknown config parameter");
        }
    }

    /// @notice file allows governance to change parameters of the contract
    /// @param name name of the parameter
    /// @param value new value of the parameter
    function file(bytes32 name, uint256 value) public auth {
        if (name == "discountRate") {
            uint256 oldDiscountRate = discountRate;
            discountRate = value;
            // the nav needs to be re-calculated based on the new discount rate
            // no need to recalculate it if initialized the first time
            if (oldDiscountRate != 0) {
                reCalcNAV();
            }
            emit File(name, value);
        } else {
            revert("unknown config parameter");
        }
    }

    /// @notice file allows governance to change parameters of the contract
    /// @param name name of the parameter group
    /// @param risk_ id of new risk group
    /// @param thresholdRatio_ new threshold ratio
    /// @param ceilingRatio_ new ceiling ratio
    /// @param interestRate_ new interest rate of the risk group
    function file(bytes32 name, uint256 risk_, uint256 thresholdRatio_, uint256 ceilingRatio_, uint256 interestRate_)
        public
        auth
    {
        if (name == "riskGroupNFT") {
            require(ceilingRatio(risk_) == 0, "risk-group-in-usage");
            riskGroup[risk_].thresholdRatio = toUint128(thresholdRatio_);
            riskGroup[risk_].ceilingRatio = toUint128(ceilingRatio_);

            // set interestRate for risk group
            pile.file("rate", risk_, interestRate_);
            emit File(name, risk_, thresholdRatio_, ceilingRatio_, interestRate_);
        } else {
            revert("unknown name");
        }
    }

    /// @notice file allows governance to change parameters of the contract
    /// @param name name of the parameter group
    /// @param writeOffPercentage_ the write off rate in percent
    /// @param overdueDays_ the number of days after which a loan is considered overdue
    function file(bytes32 name, uint256 rate_, uint256 writeOffPercentage_, uint256 overdueDays_) public auth {
        if (name == "writeOffGroup") {
            uint256 index = writeOffGroups.length;
            writeOffGroups.push(WriteOffGroup(toUint128(writeOffPercentage_), toUint128(overdueDays_)));
            pile.file("rate", safeAdd(WRITEOFF_RATE_GROUP_START, index), rate_);
            emit File(name, rate_, writeOffPercentage_, overdueDays_);
        } else {
            revert("unknown name");
        }
    }

    /// @notice borrow updates the NAV for a new borrowed loan
    /// @param loan the id of the loan
    /// @param amount the amount borrowed
    /// @return navIncrease the increase of the NAV impacted by the new borrow
    function borrow(uint256 loan, uint256 amount) external virtual auth returns (uint256 navIncrease) {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        bytes32 nftID_ = nftID(loan);
        uint256 maturityDate_ = maturityDate(nftID_);

        require(ceiling(loan) >= amount, "borrow-amount-too-high");
        require(maturityDate_ > nnow, "maturity-date-is-not-in-the-future");

        if (nnow > lastNAVUpdate) {
            calcUpdateNAV();
        }

        // calculate amount including fixed fee if applicatable
        (,, uint256 loanInterestRate,, uint256 fixedRate) = pile.rates(pile.loanRates(loan));
        uint256 amountIncludingFixed = safeAdd(amount, rmul(amount, fixedRate));

        // calculate future value FV
        uint256 fv =
            calcFutureValue(loanInterestRate, amountIncludingFixed, maturityDate_, recoveryRatePD(risk(nftID_)));
        details[nftID_].futureValue = toUint128(safeAdd(futureValue(nftID_), fv));

        // add future value to the bucket of assets with the same maturity date
        buckets[maturityDate_] = safeAdd(buckets[maturityDate_], fv);

        // increase borrowed amount for future ceiling computations
        loanDetails[loan].borrowed = toUint128(safeAdd(borrowed(loan), amount));

        // return increase NAV amount
        navIncrease = calcDiscount(discountRate, fv, nnow, maturityDate_);

        latestDiscount = safeAdd(latestDiscount, navIncrease);
        latestNAV = safeAdd(latestNAV, navIncrease);
        return navIncrease;
    }

    /// @notice repay updates the NAV for a new repaid loan
    /// @param loan the id of the loan
    /// @param amount the amount repaid
    function repay(uint256 loan, uint256 amount) external virtual auth {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        if (nnow > lastNAVUpdate) {
            calcUpdateNAV();
        }

        // In case of successful repayment the latestNAV is decreased by the repaid amount
        bytes32 nftID_ = nftID(loan);
        uint256 maturityDate_ = maturityDate(nftID_);

        // case 1: repayment of a written-off loan
        if (isLoanWrittenOff(loan)) {
            // update nav with write-off decrease
            latestNAV = secureSub(
                latestNAV,
                rmul(amount, toUint128(writeOffGroups[pile.loanRates(loan) - WRITEOFF_RATE_GROUP_START].percentage))
            );
            return;
        }

        uint256 debt = safeSub(pile.debt(loan), amount);
        uint256 preFV = futureValue(nftID_);
        // in case of partial repayment, compute the fv of the remaining debt and add to the according fv bucket
        uint256 fv = 0;
        uint256 fvDecrease = preFV;
        if (debt != 0) {
            (,, uint256 loanInterestRate,,) = pile.rates(pile.loanRates(loan));
            fv = calcFutureValue(loanInterestRate, debt, maturityDate_, recoveryRatePD(risk(nftID_)));
            if (preFV >= fv) {
                fvDecrease = safeSub(preFV, fv);
            } else {
                fvDecrease = 0;
            }
        }

        details[nftID_].futureValue = toUint128(fv);
        // case 2: repayment of a loan before or on maturity date
        if (maturityDate_ >= nnow) {
            // remove future value decrease from bucket
            buckets[maturityDate_] = safeSub(buckets[maturityDate_], fvDecrease);
            uint256 discountDecrease = calcDiscount(discountRate, fvDecrease, nnow, maturityDate_);
            latestDiscount = secureSub(latestDiscount, discountDecrease);
            latestNAV = secureSub(latestNAV, discountDecrease);
        } else {
            // case 3: repayment of an overdue loan
            overdueLoans = safeSub(overdueLoans, fvDecrease);
            latestNAV = secureSub(latestNAV, fvDecrease);
        }
    }

    /// @notice borrowEvent triggers a borrow event for a loan
    /// @param loan the id of the loan
    function borrowEvent(uint256 loan, uint256) public virtual auth {
        uint256 risk_ = risk(nftID(loan));

        // when issued every loan has per default interest rate of risk group 0.
        // correct interest rate has to be set on first borrow event
        if (pile.loanRates(loan) != risk_) {
            // set loan interest rate to the one of the correct risk group
            pile.setRate(loan, risk_);
        }
    }

    function repayEvent(uint256 loan, uint256 amount) public virtual auth {}
    function lockEvent(uint256 loan) public virtual auth {}
    function unlockEvent(uint256 loan) public virtual auth {}

    /// @notice writeOff writes off a loan if it is overdue
    /// @param loan the id of the loan
    function writeOff(uint256 loan) public {
        require(!loanDetails[loan].authWriteOff, "only-auth-write-off");

        bytes32 nftID_ = nftID(loan);
        uint256 maturityDate_ = maturityDate(nftID_);
        require(maturityDate_ > 0 && loan < shelf.loanCount(), "loan-does-not-exist");

        // can not write-off healthy loans
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        require(maturityDate_ < nnow, "maturity-date-in-the-future");
        // check the writeoff group based on the amount of days overdue
        uint256 writeOffGroupIndex_ = currentValidWriteOffGroup(loan);

        if (
            writeOffGroupIndex_ < type(uint128).max
                && pile.loanRates(loan) != WRITEOFF_RATE_GROUP_START + writeOffGroupIndex_
        ) {
            _writeOff(loan, writeOffGroupIndex_, nftID_, maturityDate_);
            emit WriteOff(loan, writeOffGroupIndex_, false);
        }
    }

    /// @notice authorized call to write of a loan in a specific writeoff group
    /// @param loan the id of the loan
    /// @param writeOffGroupIndex_ the index of the writeoff group
    function overrideWriteOff(uint256 loan, uint256 writeOffGroupIndex_) public auth {
        // can not write-off healthy loans
        bytes32 nftID_ = nftID(loan);
        uint256 maturityDate_ = maturityDate(nftID_);
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        require(maturityDate_ < nnow, "maturity-date-in-the-future");

        if (loanDetails[loan].authWriteOff == false) {
            loanDetails[loan].authWriteOff = true;
        }
        _writeOff(loan, writeOffGroupIndex_, nftID_, maturityDate_);
        emit WriteOff(loan, writeOffGroupIndex_, true);
    }

    /// @notice internal function for the write off
    /// @param loan the id of the loan
    /// @param writeOffGroupIndex_ the index of the writeoff group
    /// @param nftID_ the nftID of the loan
    /// @param maturityDate_ the maturity date of the loan
    function _writeOff(uint256 loan, uint256 writeOffGroupIndex_, bytes32 nftID_, uint256 maturityDate_) internal {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        // Ensure we have an up to date NAV
        if (nnow > lastNAVUpdate) {
            calcUpdateNAV();
        }

        uint256 latestNAV_ = latestNAV;

        // first time written-off
        if (isLoanWrittenOff(loan) == false) {
            uint256 fv = futureValue(nftID_);
            if (uniqueDayTimestamp(lastNAVUpdate) > maturityDate_) {
                // write off after the maturity date
                overdueLoans = secureSub(overdueLoans, fv);
                latestNAV_ = secureSub(latestNAV_, fv);
            } else {
                // write off before or on the maturity date
                buckets[maturityDate_] = safeSub(buckets[maturityDate_], fv);
                uint256 pv = rmul(fv, rpow(discountRate, safeSub(uniqueDayTimestamp(maturityDate_), nnow), ONE));
                latestDiscount = secureSub(latestDiscount, pv);
                latestNAV_ = secureSub(latestNAV_, pv);
            }
        }

        pile.changeRate(loan, WRITEOFF_RATE_GROUP_START + writeOffGroupIndex_);
        latestNAV = safeAdd(latestNAV_, rmul(pile.debt(loan), writeOffGroups[writeOffGroupIndex_].percentage));
    }

    /// @notice returns if a loan is written off
    /// @param loan the id of the loan
    function isLoanWrittenOff(uint256 loan) public view returns (bool) {
        return pile.loanRates(loan) >= WRITEOFF_RATE_GROUP_START;
    }

    /// @notice calculates and returns the current NAV
    /// @return nav_ current NAV
    function currentNAV() public view returns (uint256 nav_) {
        (uint256 totalDiscount, uint256 overdue, uint256 writeOffs) = currentPVs();
        return safeAdd(totalDiscount, safeAdd(overdue, writeOffs));
    }

    /// @notice calculates the present value of the loans together with overdue and written off loans
    /// @return totalDiscount the present value of the loans
    /// @return overdue the present value of the overdue loans
    /// @return writeOffs the present value of the written off loans
    function currentPVs() public view returns (uint256 totalDiscount, uint256 overdue, uint256 writeOffs) {
        if (latestDiscount == 0) {
            // all loans are overdue or writtenOff
            return (0, overdueLoans, currentWriteOffs());
        }

        uint256 errPV = 0;
        uint256 nnow = uniqueDayTimestamp(block.timestamp);

        // find all new overdue loans since the last update
        // calculate the discount of the overdue loans which is needed
        // for the total discount calculation
        for (uint256 i = lastNAVUpdate; i < nnow; i = i + 1 days) {
            uint256 b = buckets[i];
            if (b != 0) {
                errPV = safeAdd(errPV, rmul(b, rpow(discountRate, safeSub(nnow, i), ONE)));
                overdue = safeAdd(overdue, b);
            }
        }

        return (
            // calculate current totalDiscount based on the previous totalDiscount (optimized calculation)
            // the overdue loans are incorrectly in this new result with their current PV and need to be removed
            secureSub(rmul(latestDiscount, rpow(discountRate, safeSub(nnow, lastNAVUpdate), ONE)), errPV),
            // current overdue loans not written off
            safeAdd(overdueLoans, overdue),
            // current write-offs loans
            currentWriteOffs()
        );
    }

    /// @notice returns the sum of all write off loans
    /// @return sum of all write off loans
    function currentWriteOffs() public view returns (uint256 sum) {
        for (uint256 i = 0; i < writeOffGroups.length; i++) {
            // multiply writeOffGroupDebt with the writeOff rate
            sum =
                safeAdd(sum, rmul(pile.rateDebt(WRITEOFF_RATE_GROUP_START + i), uint256(writeOffGroups[i].percentage)));
        }
        return sum;
    }

    /// @notice calculates and returns the current NAV and updates the state
    /// @return nav_ current NAV
    function calcUpdateNAV() public returns (uint256 nav_) {
        (uint256 totalDiscount, uint256 overdue, uint256 writeOffs) = currentPVs();

        overdueLoans = overdue;
        latestDiscount = totalDiscount;

        latestNAV = safeAdd(safeAdd(totalDiscount, overdue), writeOffs);
        lastNAVUpdate = uniqueDayTimestamp(block.timestamp);
        return latestNAV;
    }

    /// @notice re-calculates the nav in a non-optimized way
    ///  the method is not updating the NAV to latest block.timestamp
    /// @return nav_ current NAV
    function reCalcNAV() public returns (uint256 nav_) {
        uint256 latestDiscount_ = reCalcTotalDiscount();

        latestNAV = safeAdd(latestDiscount_, safeSub(latestNAV, latestDiscount));
        latestDiscount = latestDiscount_;
        return latestNAV;
    }

    /// @notice re-calculates the totalDiscount in a non-optimized way based on lastNAVUpdate
    /// @return latestDiscount_ returns the total discount of the active loans
    function reCalcTotalDiscount() public view returns (uint256 latestDiscount_) {
        latestDiscount_ = 0;

        for (uint256 loanID = 1; loanID < shelf.loanCount(); loanID++) {
            bytes32 nftID_ = nftID(loanID);
            uint256 maturityDate_ = maturityDate(nftID_);

            if (maturityDate_ < lastNAVUpdate) {
                continue;
            }

            latestDiscount_ =
                safeAdd(latestDiscount_, calcDiscount(discountRate, futureValue(nftID_), lastNAVUpdate, maturityDate_));
        }
        return latestDiscount_;
    }

    /// @notice update the value (apprasial) of the collateral NFT
    function update(bytes32 nftID_, uint256 value) public auth {
        // switch of collateral risk group results in new: ceiling, threshold for existing loan
        details[nftID_].nftValues = toUint128(value);
        emit Update(nftID_, value);
    }

    /// @notice updates the risk group of active loans (borrowed and unborrowed loans)
    /// @param nftID_ the nftID of the loan
    /// @param risk_ the new value appraisal of the collateral NFT
    /// @param risk_ the new risk group
    function update(bytes32 nftID_, uint256 value, uint256 risk_) public auth {
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        details[nftID_].nftValues = toUint128(value);

        // no change in risk group
        if (risk_ == risk(nftID_)) {
            return;
        }

        // nfts can only be added to risk groups that are part of the score card
        require(thresholdRatio(risk_) != 0, "risk group not defined in contract");
        details[nftID_].risk = toUint128(risk_);

        // update nav -> latestNAVUpdate = now
        if (nnow > lastNAVUpdate) {
            calcUpdateNAV();
        }

        // switch of collateral risk group results in new: ceiling, threshold and interest rate for existing loan
        // change to new rate interestRate immediately in pile if loan debt exists
        uint256 loan = shelf.nftlookup(nftID_);
        if (pile.pie(loan) != 0) {
            pile.changeRate(loan, risk_);
        }

        // no currencyAmount borrowed yet
        if (futureValue(nftID_) == 0) {
            return;
        }

        uint256 maturityDate_ = maturityDate(nftID_);

        // Changing the risk group of an nft, might lead to a new interest rate for the dependant loan.
        // New interest rate leads to a future value.
        // recalculation required
        uint256 fvDecrease = futureValue(nftID_);
        uint256 navDecrease = calcDiscount(discountRate, fvDecrease, nnow, maturityDate_);
        buckets[maturityDate_] = safeSub(buckets[maturityDate_], fvDecrease);
        latestDiscount = safeSub(latestDiscount, navDecrease);
        latestNAV = safeSub(latestNAV, navDecrease);

        // update latest NAV
        // update latest Discount
        (,, uint256 loanInterestRate,,) = pile.rates(pile.loanRates(loan));
        details[nftID_].futureValue = toUint128(
            calcFutureValue(loanInterestRate, pile.debt(loan), maturityDate(nftID_), recoveryRatePD(risk(nftID_)))
        );

        uint256 fvIncrease = futureValue(nftID_);
        uint256 navIncrease = calcDiscount(discountRate, fvIncrease, nnow, maturityDate_);
        buckets[maturityDate_] = safeAdd(buckets[maturityDate_], fvIncrease);
        latestDiscount = safeAdd(latestDiscount, navIncrease);
        latestNAV = safeAdd(latestNAV, navIncrease);
        emit Update(nftID_, value, risk_);
    }

    // --- Utilities ---
    /// @notice returns the threshold of a loan
    /// if the loan debt is above the loan threshold the NFT can be seized
    /// @param loan the id of the loan
    /// @return threshold_ the threshold of the loan
    function threshold(uint256 loan) public view returns (uint256 threshold_) {
        bytes32 nftID_ = nftID(loan);
        return rmul(nftValues(nftID_), thresholdRatio(risk(nftID_)));
    }

    /// @notice returns a unique id based on the nft registry and tokenId
    /// the nftID is used to set the risk group and value for nfts
    /// @param registry the address of the nft registry
    /// @param tokenId the tokenId of the nft
    /// @return nftID_ the nftID of the nft
    function nftID(address registry, uint256 tokenId) public pure returns (bytes32 nftID_) {
        return keccak256(abi.encodePacked(registry, tokenId));
    }

    /// @notice returns the nftID for the underlying collateral nft
    /// @param loan the loan id
    /// @return nftID_ the nftID of the loan
    function nftID(uint256 loan) public view returns (bytes32 nftID_) {
        (address registry, uint256 tokenId) = shelf.shelf(loan);
        return nftID(registry, tokenId);
    }

    /// @notice returns true if the present value of a loan is zero
    /// true if all debt is repaid or debt is 100% written-off
    /// @param loan the loan id
    /// @return isZeroPV true if the present value of a loan is zero
    function zeroPV(uint256 loan) public view returns (bool isZeroPV) {
        if (pile.debt(loan) == 0) {
            return true;
        }

        uint256 rate = pile.loanRates(loan);

        if (rate < WRITEOFF_RATE_GROUP_START) {
            return false;
        }

        return writeOffGroups[safeSub(rate, WRITEOFF_RATE_GROUP_START)].percentage == 0;
    }

    /// @notice returns the current valid write off group of a loan
    /// @param loan the loan id
    /// @return writeOffGroup_ the current valid write off group of a loan
    function currentValidWriteOffGroup(uint256 loan) public view returns (uint256 writeOffGroup_) {
        bytes32 nftID_ = nftID(loan);
        uint256 maturityDate_ = maturityDate(nftID_);
        uint256 nnow = uniqueDayTimestamp(block.timestamp);

        uint128 lastValidWriteOff = type(uint128).max;
        uint128 highestOverdueDays = 0;
        // it is not guaranteed that writeOff groups are sorted by overdue days
        for (uint128 i = 0; i < writeOffGroups.length; i++) {
            uint128 overdueDays = writeOffGroups[i].overdueDays;
            if (overdueDays >= highestOverdueDays && nnow >= maturityDate_ + overdueDays * 1 days) {
                lastValidWriteOff = i;
                highestOverdueDays = overdueDays;
            }
        }

        // returns type(uint128).max if no write-off group is valid for this loan
        return lastValidWriteOff;
    }
}
