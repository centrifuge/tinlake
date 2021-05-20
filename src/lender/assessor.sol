// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";
import "./definitions.sol";

interface NAVFeedLike {
    function calcUpdateNAV() external returns (uint);
    function approximatedNAV() external view returns (uint);
    function currentNAV() external view returns(uint);
}

interface TrancheLike {
    function tokenSupply() external view returns (uint);
}

interface ReserveLike {
    function totalBalance() external view returns(uint);
    function file(bytes32 what, uint currencyAmount) external;
    function currencyAvailable() external view returns(uint);
}

interface LendingAdapter {
    function remainingCredit() external view returns (uint);
    function juniorStake() external view returns (uint);
    function calcOvercollAmount(uint amount) external view returns (uint);
    function stabilityFee() external view returns(uint);
    function debt() external view returns(uint);
}

contract Assessor is Definitions, Auth, Interest {
    // senior ratio from the last epoch executed
    Fixed27        public seniorRatio;

    // the seniorAsset value is stored in two variables
    // seniorDebt is the interest bearing amount for senior
    uint           public seniorDebt_;
    // senior balance is the rest which is not used as interest
    // bearing amount
    uint           public seniorBalance_;

    // interest rate per second for senior tranche
    Fixed27         public seniorInterestRate;

    // last time the senior interest has been updated
    uint            public lastUpdateSeniorInterest;

    Fixed27         public maxSeniorRatio;
    Fixed27         public minSeniorRatio;

    uint            public maxReserve;

    uint            public creditBufferTime = 1 days;

    TrancheLike     public seniorTranche;
    TrancheLike     public juniorTranche;
    NAVFeedLike     public navFeed;
    ReserveLike     public reserve;
    LendingAdapter  public lending;

    constructor() public {
        wards[msg.sender] = 1;
        seniorInterestRate.value = ONE;
        lastUpdateSeniorInterest = block.timestamp;
        seniorRatio.value = 0;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "navFeed") {
            navFeed = NAVFeedLike(addr);
        } else if (contractName == "seniorTranche") {
            seniorTranche = TrancheLike(addr);
        } else if (contractName == "juniorTranche") {
            juniorTranche = TrancheLike(addr);
        } else if (contractName == "reserve") {
            reserve = ReserveLike(addr);
        } else if (contractName == "lending") {
            lending = LendingAdapter(addr);
        } else revert();
    }

    function file(bytes32 name, uint value) public auth {
        if (name == "seniorInterestRate") {
            dripSeniorDebt();
            seniorInterestRate = Fixed27(value);
        } else if (name == "maxReserve") {
            maxReserve = value;
        } else if (name == "maxSeniorRatio") {
            require(value > minSeniorRatio.value, "value-too-small");
            maxSeniorRatio = Fixed27(value);
        } else if (name == "minSeniorRatio") {
            require(value < maxSeniorRatio.value, "value-too-big");
            minSeniorRatio = Fixed27(value);
        } else if (name == "creditBufferTime") {
            creditBufferTime = value;
        } else {
            revert("unknown-variable");
        }
    }

    function reBalance(uint seniorAsset_, uint seniorRatio_) internal {
        // re-balancing according to new ratio
        // we use the approximated NAV here because during the submission period
        // new loans might have been repaid in the meanwhile which are not considered in the epochNAV
        if(seniorRatio_ > ONE) {
            seniorRatio_ = ONE;
        }

        seniorDebt_ = rmul(navFeed.approximatedNAV(), seniorRatio_);
        if(seniorDebt_ > seniorAsset_) {
            seniorDebt_ = seniorAsset_;
            seniorBalance_ = 0;
            return;
        }
        seniorBalance_ = safeSub(seniorAsset_, seniorDebt_);
    }

    function changeSeniorAsset(uint seniorSupply, uint seniorRedeem) external auth {
        uint nav_ = navFeed.approximatedNAV();
        uint reserve_ = reserve.totalBalance();

        uint seniorAsset_ = calcExpectedSeniorAsset(seniorRedeem, seniorSupply, seniorBalance_, dripSeniorDebt());

        uint seniorRatio_ = calcSeniorRatio(seniorAsset_, nav_, reserve_);
        reBalance(seniorAsset_, seniorRatio_);
        seniorRatio = Fixed27(seniorRatio_);
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (minSeniorRatio.value, maxSeniorRatio.value);
    }

    function calcUpdateNAV() external returns (uint) {
        return navFeed.calcUpdateNAV();
    }

    function calcSeniorTokenPrice() external view returns(uint) {
        return calcSeniorTokenPrice(navFeed.approximatedNAV(), reserve.totalBalance());
    }

    function calcSeniorTokenPrice(uint nav_, uint) public view returns(uint) {
        return _calcSeniorTokenPrice(nav_, reserve.totalBalance());
    }

    function calcJuniorTokenPrice() external view returns(uint) {
        return _calcJuniorTokenPrice(navFeed.currentNAV(), reserve.totalBalance());
    }

    function calcJuniorTokenPrice(uint nav_, uint) public view returns (uint) {
        return _calcJuniorTokenPrice(nav_, reserve.totalBalance());
    }

    function calcTokenPrices() external view returns (uint, uint) {
        uint epochNAV = navFeed.currentNAV();
        uint epochReserve = reserve.totalBalance();
        return calcTokenPrices(epochNAV, epochReserve);
    }

    function calcTokenPrices(uint epochNAV, uint epochReserve) public view returns (uint, uint) {
        return (_calcJuniorTokenPrice(epochNAV, epochReserve), _calcSeniorTokenPrice(epochNAV, epochReserve));
    }

    function _calcSeniorTokenPrice(uint nav_, uint reserve_) internal view returns(uint) {
        // the coordinator interface will pass the reserveAvailable

        if ((nav_ == 0 && reserve_ == 0) || seniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }

        // reserve includes creditline from maker
        uint totalAssets = safeAdd(nav_, reserve_);

        // includes creditline
        uint seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }
        return rdiv(seniorAssetValue, seniorTranche.tokenSupply());
    }

    function _calcJuniorTokenPrice(uint nav_, uint reserve_) internal view returns (uint) {
        if ((nav_ == 0 && reserve_ == 0) || juniorTranche.tokenSupply() == 0) {
            // initial token price at start 1.00
            return ONE;
        }
        // reserve includes creditline from maker
        uint totalAssets = safeAdd(nav_, reserve_);

        // includes creditline from mkr
        uint seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if(totalAssets < seniorAssetValue) {
            return 0;
        }

        // the junior tranche only needs to pay for the mkr over-collateralization if
        // the mkr vault is liquidated, if that is true juniorStake=0
        uint juniorStake = 0;
        if (address(lending) != address(0)) {
            juniorStake = lending.juniorStake();
        }

        return rdiv(safeAdd(safeSub(totalAssets, seniorAssetValue), juniorStake),
            juniorTranche.tokenSupply());
    }

    /// repayment update keeps track of senior bookkeeping for repaid loans
    /// the seniorDebt needs to be decreased
    function repaymentUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        uint decAmount = rmul(currencyAmount, seniorRatio.value);

        if (decAmount > seniorDebt_) {
            seniorBalance_ = calcExpectedSeniorAsset(seniorDebt_, seniorBalance_);
            seniorDebt_ = 0;
            return;
        }

        seniorBalance_ = safeAdd(seniorBalance_, decAmount);
        // seniorDebt needs to be decreased for loan repayments
        seniorDebt_ = safeSub(seniorDebt_, decAmount);
        lastUpdateSeniorInterest = block.timestamp;

    }
    /// borrow update keeps track of the senior bookkeeping for new borrowed loans
    /// the seniorDebt needs to be increased to accumulate interest
    function borrowUpdate(uint currencyAmount) public auth {
        dripSeniorDebt();

        // the current senior ratio defines
        // interest bearing amount (seniorDebt) increase
        uint incAmount = rmul(currencyAmount, seniorRatio.value);

        // this case should most likely never happen
        if (incAmount > seniorBalance_) {
            // all the currency of senior is used as interest bearing currencyAmount
            seniorDebt_ = calcExpectedSeniorAsset(seniorDebt_, seniorBalance_);
            seniorBalance_ = 0;
            return;
        }

        // seniorDebt needs to be increased for loan borrows
        seniorDebt_ = safeAdd(seniorDebt_, incAmount);
        seniorBalance_ = safeSub(seniorBalance_, incAmount);
        lastUpdateSeniorInterest = block.timestamp;
    }

    function dripSeniorDebt() public returns (uint) {
        uint newSeniorDebt = seniorDebt();

        if (newSeniorDebt > seniorDebt_) {
            seniorDebt_ = newSeniorDebt;
            lastUpdateSeniorInterest = block.timestamp;
        }

        return seniorDebt_;
    }

    function seniorDebt() public view returns (uint) {
        if (now >= lastUpdateSeniorInterest) {
            return chargeInterest(seniorDebt_, seniorInterestRate.value, lastUpdateSeniorInterest);
        }
        return seniorDebt_;
    }

    function seniorBalance() public view returns(uint) {
        return safeAdd(seniorBalance_, remainingOvercollCredit());
    }

    function effectiveSeniorBalance() public view returns(uint) {
        return seniorBalance_;
    }

    function effectiveTotalBalance() public view returns(uint) {
        return reserve.totalBalance();
    }

    function totalBalance() public view returns(uint) {
        return safeAdd(reserve.totalBalance(), remainingCredit());
    }

    // returns the current NAV
    function currentNAV() public view returns(uint) {
        return navFeed.currentNAV();
    }

    // returns the approximated NAV for gas-performance reasons
    function getNAV() public view returns(uint) {
        return navFeed.approximatedNAV();
    }

    // changes the total amount available for borrowing loans
    function changeBorrowAmountEpoch(uint currencyAmount) public auth {
        reserve.file("currencyAvailable", currencyAmount);
    }

    function borrowAmountEpoch() public view returns(uint) {
        return reserve.currencyAvailable();
    }

    // returns the current junior ratio protection in the Tinlake
    // juniorRatio is denominated in RAY (10^27)
    function calcJuniorRatio() public view returns(uint) {
        uint seniorAsset = safeAdd(seniorDebt(), seniorBalance_);
        uint assets = safeAdd(navFeed.approximatedNAV(), reserve.totalBalance());

        if(seniorAsset == 0 && assets == 0) {
            return 0;
        }

        if(seniorAsset == 0 && assets > 0) {
            return ONE;
        }

        if (seniorAsset > assets) {
            return 0;
        }

        return safeSub(ONE, rdiv(seniorAsset, assets));
    }

    // returns the remainingCredit plus a buffer for the interest increase
    function remainingCredit() public view returns(uint) {
        if (address(lending) == address(0)) {
            return 0;
        }

        // over the time the remainingCredit will decrease because of the accumulated debt interest
        // therefore a buffer is reduced from the  remainingCredit to prevent the usage of currency which is not available
        uint debt = lending.debt();
        uint stabilityBuffer = safeSub(rmul(rpow(lending.stabilityFee(),
            creditBufferTime, ONE), debt), debt);
        uint remainingCredit_ = lending.remainingCredit();
        if(remainingCredit_ > stabilityBuffer) {
            return safeSub(remainingCredit_, stabilityBuffer);
        }
        
        return 0;
    }

    function remainingOvercollCredit() public view returns(uint) {
        if (address(lending) == address(0)) {
            return 0;
        }

        return lending.calcOvercollAmount(remainingCredit());
    }
}
