// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";
import "./definitions.sol";

interface NAVFeedLike {
    function calcUpdateNAV() external returns (uint);
    function latestNAV() external view returns (uint);
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

    uint public constant supplyTolerance = 5;

    event Depend(bytes32 indexed contractName, address addr);
    event File(bytes32 indexed name, uint value);

    constructor() {
        seniorInterestRate.value = ONE;
        lastUpdateSeniorInterest = block.timestamp;
        seniorRatio.value = 0;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
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
        emit Depend(contractName, addr);
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
        emit File(name, value);
    }

    function reBalance() public {
        reBalance(calcExpectedSeniorAsset(seniorBalance_, dripSeniorDebt()));
    }

    function reBalance(uint seniorAsset_) internal {
        // re-balancing according to new ratio
        // we use the approximated NAV here because because during the submission period
        // new loans might have been repaid in the meanwhile which are not considered in the epochNAV
        uint nav_ = getNAV();
        uint reserve_ = reserve.totalBalance();

        uint seniorRatio_ = calcSeniorRatio(seniorAsset_, nav_, reserve_);

        // in that case the entire juniorAsset is lost
        // the senior would own everything that' left
        if(seniorRatio_ > ONE) {
            seniorRatio_ = ONE;
        }

        seniorDebt_ = rmul(nav_, seniorRatio_);
        if(seniorDebt_ > seniorAsset_) {
            seniorDebt_ = seniorAsset_;
            seniorBalance_ = 0;
        } else {
            seniorBalance_ = safeSub(seniorAsset_, seniorDebt_);
        }
        seniorRatio = Fixed27(seniorRatio_);
    }

    function changeSeniorAsset(uint seniorSupply, uint seniorRedeem) external auth {
        reBalance(calcExpectedSeniorAsset(seniorRedeem, seniorSupply, seniorBalance_, dripSeniorDebt()));
    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (minSeniorRatio.value, maxSeniorRatio.value);
    }

    function calcUpdateNAV() external returns (uint) {
        return navFeed.calcUpdateNAV();
    }

    function calcSeniorTokenPrice() external view returns(uint) {
        return calcSeniorTokenPrice(getNAV(), reserve.totalBalance());
    }

    function calcSeniorTokenPrice(uint nav_, uint) public view returns(uint) {
        return _calcSeniorTokenPrice(nav_, reserve.totalBalance());
    }

    function calcJuniorTokenPrice() external view returns(uint) {
        return _calcJuniorTokenPrice(getNAV(), reserve.totalBalance());
    }

    function calcJuniorTokenPrice(uint nav_, uint) public view returns (uint) {
        return _calcJuniorTokenPrice(nav_, reserve.totalBalance());
    }

    function calcTokenPrices() external view returns (uint, uint) {
        uint epochNAV = getNAV();
        uint epochReserve = reserve.totalBalance();
        return calcTokenPrices(epochNAV, epochReserve);
    }

    function calcTokenPrices(uint epochNAV, uint epochReserve) public view returns (uint, uint) {
        return (_calcJuniorTokenPrice(epochNAV, epochReserve), _calcSeniorTokenPrice(epochNAV, epochReserve));
    }

    function _calcSeniorTokenPrice(uint nav_, uint reserve_) internal view returns(uint) {
        // the coordinator interface will pass the reserveAvailable

        if ((nav_ == 0 && reserve_ == 0) || seniorTranche.tokenSupply() <= supplyTolerance) { // we are using a tolerance of 2 here, as there can be minimal supply leftovers after all redemptions due to rounding
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
        if ((nav_ == 0 && reserve_ == 0) || juniorTranche.tokenSupply() <= supplyTolerance) { // we are using a tolerance of 2 here, as there can be minimal supply leftovers after all redemptions due to rounding
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

    function dripSeniorDebt() public returns (uint) {
        seniorDebt_ = seniorDebt();
        lastUpdateSeniorInterest = block.timestamp;
        return seniorDebt_;
    }

    function seniorDebt() public view returns (uint) {
        if (block.timestamp >= lastUpdateSeniorInterest) {
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
    function getNAV() public view returns(uint) {
        return navFeed.latestNAV();
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
        uint assets = safeAdd(getNAV(), reserve.totalBalance());

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
