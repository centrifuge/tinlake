// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

interface ShelfLike {
    function shelf(uint loan) external view returns (address registry, uint tokenId);
    function nftlookup(bytes32 nftID) external returns (uint loan);
    function loanCount() external view returns (uint);
}

interface PileLike {
    function setRate(uint loan, uint rate) external;
    function debt(uint loan) external view returns (uint);
    function pie(uint loan) external returns (uint);
    function rates(uint256 rate) external view returns (uint256, uint256, uint256, uint48, uint256);
    function changeRate(uint loan, uint newRate) external;
    function loanRates(uint loan) external view returns (uint);
    function file(bytes32, uint, uint) external;
    function rateDebt(uint rate) external view returns (uint);
}

contract NAVFeedPV is Auth, Math {
    PileLike    public pile;
    ShelfLike   public shelf;

    struct NFTDetails {
        uint128 nftValues;
        uint128 risk;
    }

    struct RiskGroup {
        // denominated in (10^27)
        uint128 ceilingRatio;
        // denominated in (10^27)
        uint128 thresholdRatio;
        // denominated in (10^27)
        uint128 recoveryRatePD;
    }

    // nft => details
    mapping (bytes32 => NFTDetails) public details;
    // risk => riskGroup
    mapping (uint => RiskGroup) public riskGroup;

    uint public latestNAV;
    uint public lastNAVUpdate;

    uint public constant WRITEOFF_RATE_GROUP = 1000;


    // events
    event Depend(bytes32 indexed name, address addr);
    event File(bytes32 indexed name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_);
    event Update(bytes32 indexed nftID, uint value);
    event Update(bytes32 indexed nftID, uint value, uint risk);

    // getter functions
    function risk(bytes32 nft_)             public view returns(uint){ return uint(details[nft_].risk);}
    function nftValues(bytes32 nft_)        public view returns(uint){ return uint(details[nft_].nftValues);}
    function ceilingRatio(uint riskID)      public view returns(uint){ return uint(riskGroup[riskID].ceilingRatio);}
    function thresholdRatio(uint riskID)    public view returns(uint){ return uint(riskGroup[riskID].thresholdRatio);}

    constructor () {
        wards[msg.sender] = 1;
        lastNAVUpdate = block.timestamp;
        emit Rely(msg.sender);
    }

    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }
    
    // returns the ceiling of a loan
    // the ceiling defines the maximum amount which can be borrowed
    // ceiling is calculated using the credit line method
    function ceiling(uint loan) public virtual view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        uint initialCeiling = rmul(nftValues(nftID_), ceilingRatio(risk(nftID_)));
        if (initialCeiling <= pile.debt(loan)) {
            return 0;
        } else {
            return safeSub(initialCeiling, pile.debt(loan));
        }    
    }

    // --- Administration ---
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "pile") {
            pile = PileLike(addr);
        }
        else if (contractName == "shelf") { shelf = ShelfLike(addr); }
        else revert();
        emit Depend(contractName, addr);
    }

    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_) public auth {
        if(name == "riskGroup") {
            require(ceilingRatio(risk_) == 0, "risk-group-in-usage");
            riskGroup[risk_].thresholdRatio = toUint128(thresholdRatio_);
            riskGroup[risk_].ceilingRatio = toUint128(ceilingRatio_);

            // set interestRate for risk group
            pile.file("rate", risk_, rate_);
            emit File(name, risk_, thresholdRatio_, ceilingRatio_, rate_);

        } else { revert ("unknown name");}
    }

    // --- Actions ---
    function borrow(uint loan, uint amount) external virtual auth returns(uint navIncrease) {
        require(ceiling(loan) >= amount, "borrow-amount-too-high");
        latestNAV = safeAdd(currentNAV(), amount);
        lastNAVUpdate = block.timestamp;
        return amount;
    }

    function repay(uint loan, uint amount) external virtual auth {
        latestNAV = safeSub(currentNAV(), amount);
        lastNAVUpdate = block.timestamp;
    }

    function borrowEvent(uint loan, uint) public virtual auth {
        uint risk_ = risk(nftID(loan));
        // when issued every loan has per default interest rate of risk group 0.
        // correct interest rate has to be set on first borrow event
        if (pile.loanRates(loan) != risk_) {
            // set loan interest rate to the one of the correct risk group
            pile.setRate(loan, risk_);
        }
    }

    function repayEvent(uint loan, uint amount) public virtual auth {}
    function lockEvent(uint loan) public virtual auth {}
    function unlockEvent(uint loan) public virtual auth {}

    function writeOff(uint loan) public auth {
        uint nav = currentNAV(); // retrieve latest nav
        uint outstandingDebt = pile.debt(loan);

       (,uint256 chi,,,) = pile.rates(WRITEOFF_RATE_GROUP);
       if (chi == 0) { // file writeoff group if not exists
            pile.file("rate", WRITEOFF_RATE_GROUP, ONE);
       }
       pile.changeRate(loan, WRITEOFF_RATE_GROUP);

       // calculate NAV change
       latestNAV = safeSub(nav, outstandingDebt);
       lastNAVUpdate = block.timestamp;
    }

    function isLoanWrittenOff(uint loan) public view returns(bool) {
        return pile.loanRates(loan) == WRITEOFF_RATE_GROUP;
    }

    // --- NAV calculation ---
    function currentNAV() public view returns(uint) {
        if (lastNAVUpdate == block.timestamp) {
            return latestNAV;
        }
        uint totalDebt;
        // calculate total debt
        for (uint loanId = 1; loanId < shelf.loanCount(); loanId++) {
            totalDebt = safeAdd(totalDebt, pile.debt(loanId));
        }
        // substract writtenoff loans -> all writtenOff loans are moved to writeOffRateGroup
        totalDebt = safeSub(totalDebt, pile.rateDebt(WRITEOFF_RATE_GROUP));
        return totalDebt;
    }

    function calcUpdateNAV() public returns(uint) {
        if (lastNAVUpdate == block.timestamp) {
            return latestNAV;
        }
        latestNAV = currentNAV();
        lastNAVUpdate = block.timestamp;
        return latestNAV;
    }

    function update(bytes32 nftID_, uint value) public auth {
        // switch of collateral risk group results in new: ceiling, threshold for existing loan
        details[nftID_].nftValues = toUint128(value);
        emit Update(nftID_, value);
    }

    function update(bytes32 nftID_, uint value, uint risk_) public auth {
        details[nftID_].nftValues  = toUint128(value);
        // no change in risk group
        if (risk_ == risk(nftID_)) {
            return;
        }

        // nfts can only be added to risk groups that are part of the score card
        require(thresholdRatio(risk_) != 0, "risk group not defined in contract");
        details[nftID_].risk = toUint128(risk_);

        // switch of collateral risk group results in new: ceiling, threshold and interest rate for existing loan
        // change to new rate interestRate immediately in pile if loan debt exists
        uint loan = shelf.nftlookup(nftID_);
        if (pile.pie(loan) != 0) {
            pile.changeRate(loan, risk_);
        }
        emit Update(nftID_, value, risk_);
    }

    // --- Utilities ---
    // returns the threshold of a loan
    // if the loan debt is above the loan threshold the NFT can be seized
    function threshold(uint loan) public view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        return rmul(nftValues(nftID_), thresholdRatio(risk(nftID_)));
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

    // returns true if the present value of a loan is zero
    // true if all debt is repaid or debt is 100% written-off
    function zeroPV(uint loan) public view returns (bool) {
        return ((pile.debt(loan) == 0) || (pile.loanRates(loan) == WRITEOFF_RATE_GROUP));
    }
}