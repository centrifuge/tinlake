// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";
import "./definitions.sol";

interface NAVFeedLike {
    function calcUpdateNAV() external returns (uint256);
    function latestNAV() external view returns (uint256);
    function currentNAV() external view returns (uint256);
    function lastNAVUpdate() external view returns (uint256);
}

interface TrancheLike {
    function tokenSupply() external view returns (uint256);
}

interface ReserveLike {
    function totalBalance() external view returns (uint256);
    function file(bytes32 what, uint256 currencyAmount) external;
    function currencyAvailable() external view returns (uint256);
}

interface LendingAdapter {
    function remainingCredit() external view returns (uint256);
    function juniorStake() external view returns (uint256);
    function calcOvercollAmount(uint256 amount) external view returns (uint256);
    function stabilityFee() external view returns (uint256);
    function debt() external view returns (uint256);
}

/// @notice Assessor contract manages two tranches of a pool and calculates the token prices.
contract Assessor is Definitions, Auth, Interest {
    // senior ratio from the last epoch executed
    Fixed27 public seniorRatio;

    // the seniorAsset value is stored in two variables
    // seniorDebt is the interest bearing amount for senior
    uint256 public seniorDebt_;
    // senior balance is the rest which is not used as interest
    // bearing amount
    uint256 public seniorBalance_;

    // interest rate per second for senior tranche
    Fixed27 public seniorInterestRate;

    // last time the senior interest has been updated
    uint256 public lastUpdateSeniorInterest;

    Fixed27 public maxSeniorRatio;
    Fixed27 public minSeniorRatio;

    uint256 public maxReserve;

    uint256 public creditBufferTime = 1 days;
    uint256 public maxStaleNAV = 1 days;

    TrancheLike public seniorTranche;
    TrancheLike public juniorTranche;
    NAVFeedLike public navFeed;
    ReserveLike public reserve;
    LendingAdapter public lending;

    uint256 public constant supplyTolerance = 5;

    event Depend(bytes32 indexed contractName, address addr);
    event File(bytes32 indexed name, uint256 value);

    constructor() {
        seniorInterestRate.value = ONE;
        lastUpdateSeniorInterest = block.timestamp;
        seniorRatio.value = 0;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /// @notice manages dependencies to other pool contracts
    /// @param contractName name of the contract
    /// @param addr address of the contract
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
        } else {
            revert();
        }
        emit Depend(contractName, addr);
    }

    /// @notice allows wards to set parameters of the contract
    /// @param name name of the parameter
    /// @param value value of the parameter
    function file(bytes32 name, uint256 value) public auth {
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
        } else if (name == "maxStaleNAV") {
            maxStaleNAV = value;
        } else {
            revert("unknown-variable");
        }
        emit File(name, value);
    }

    /// @notice rebalance the debt and balance of the senior tranche according to
    /// the current ratio between senior and junior
    function reBalance() public {
        reBalance(calcExpectedSeniorAsset(seniorBalance_, dripSeniorDebt()));
    }

    /// @notice internal function for the rebalance of senior debt and balance
    /// @param seniorAsset_ the expected senior asset value (senior debt + senior balance)
    function reBalance(uint256 seniorAsset_) internal {
        // re-balancing according to new ratio
        // we use the approximated NAV here because because during the submission period
        // new loans might have been repaid in the meanwhile
        // which are not considered in the epochNAV
        uint256 nav_ = getNAV();
        uint256 reserve_ = reserve.totalBalance();

        uint256 seniorRatio_ = calcSeniorRatio(seniorAsset_, nav_, reserve_);

        // in that case the entire juniorAsset is lost
        // the senior would own everything that' left
        if (seniorRatio_ > ONE) {
            seniorRatio_ = ONE;
        }

        seniorDebt_ = rmul(nav_, seniorRatio_);
        if (seniorDebt_ > seniorAsset_) {
            seniorDebt_ = seniorAsset_;
            seniorBalance_ = 0;
        } else {
            seniorBalance_ = safeSub(seniorAsset_, seniorDebt_);
        }
        seniorRatio = Fixed27(seniorRatio_);
    }

    /// @notice changes the senior asset value based on new supply or redeems
    /// @param seniorSupply senior supply amount
    /// @param seniorRedeem senior redeem amount
    function changeSeniorAsset(uint256 seniorSupply, uint256 seniorRedeem) external auth {
        reBalance(calcExpectedSeniorAsset(seniorRedeem, seniorSupply, seniorBalance_, dripSeniorDebt()));
    }

    /// @notice returns the minimum and maximum senior ratio
    /// @return minSeniorRatio_ minimum senior ratio (in RAY 10^27)
    /// @return maxSeniorRatio_ maximum senior ratio (in RAY 10^27)
    function seniorRatioBounds() public view returns (uint256 minSeniorRatio_, uint256 maxSeniorRatio_) {
        return (minSeniorRatio.value, maxSeniorRatio.value);
    }

    /// @notice calls the NAV feed to update and store the current NAV
    /// @return nav_ the current NAV
    function calcUpdateNAV() external returns (uint256 nav_) {
        return navFeed.calcUpdateNAV();
    }

    /// @notice calculates the senior token price
    /// @return seniorTokenPrice_ the senior token price
    function calcSeniorTokenPrice() external view returns (uint256 seniorTokenPrice_) {
        return calcSeniorTokenPrice(getNAV(), reserve.totalBalance());
    }

    /// @notice calculates the senior token price for a given NAV
    /// interface doesn't use the provided total balance
    /// @param nav_ the NAV
    /// @return seniorTokenPrice_ the senior token price
    function calcSeniorTokenPrice(uint256 nav_, uint256) public view returns (uint256 seniorTokenPrice_) {
        return _calcSeniorTokenPrice(nav_, reserve.totalBalance());
    }

    /// @notice calculates the junior token price
    /// @return juniorTokenPrice_ the junior token price
    function calcJuniorTokenPrice() external view returns (uint256 juniorTokenPrice_) {
        return _calcJuniorTokenPrice(getNAV(), reserve.totalBalance());
    }

    /// @notice calculates the junior token price for a given NAV
    /// interface doesn't use the provided total balance
    /// @param nav_ the NAV
    /// @return juniorTokenPrice_ the junior token price
    function calcJuniorTokenPrice(uint256 nav_, uint256) public view returns (uint256 juniorTokenPrice_) {
        return _calcJuniorTokenPrice(nav_, reserve.totalBalance());
    }

    /// @notice calculates the senior and junior token price based on current NAV and reserve
    /// @return juniorTokenPrice_ the junior token price
    /// @return seniorTokenPrice_ the senior token price
    function calcTokenPrices() external view returns (uint256 juniorTokenPrice_, uint256 seniorTokenPrice_) {
        uint256 epochNAV = getNAV();
        uint256 epochReserve = reserve.totalBalance();
        return calcTokenPrices(epochNAV, epochReserve);
    }

    /// @notice calculates the senior and junior token price based on NAV and reserve as params
    /// @param epochNAV the NAV of an epoch
    /// @param epochReserve the reserve of an epoch
    /// @return juniorTokenPrice_ the junior token price
    /// @return seniorTokenPrice_ the senior token price
    function calcTokenPrices(uint256 epochNAV, uint256 epochReserve)
        public
        view
        returns (uint256 juniorTokenPrice_, uint256 seniorTokenPrice_)
    {
        return (_calcJuniorTokenPrice(epochNAV, epochReserve), _calcSeniorTokenPrice(epochNAV, epochReserve));
    }

    /// @notice internal function to calculate the senior token price
    /// @param nav_ the NAV
    /// @param reserve_ the reserve
    /// @return seniorTokenPrice_ the senior token price
    function _calcSeniorTokenPrice(uint256 nav_, uint256 reserve_) internal view returns (uint256 seniorTokenPrice_) {
        // the coordinator interface will pass the reserveAvailable

        if ((nav_ == 0 && reserve_ == 0) || seniorTranche.tokenSupply() <= supplyTolerance) {
            // we are using a tolerance of 2 here, as there can be minimal supply leftovers after all redemptions due to rounding
            // initial token price at start 1.00
            return ONE;
        }

        uint256 totalAssets = safeAdd(nav_, reserve_);
        uint256 seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if (totalAssets < seniorAssetValue) {
            seniorAssetValue = totalAssets;
        }
        return rdiv(seniorAssetValue, seniorTranche.tokenSupply());
    }

    /// @notice internal function to calculate the junior token price
    /// @param nav_ the NAV
    /// @param reserve_ the reserve
    /// @return juniorTokenPrice_ the junior token price
    function _calcJuniorTokenPrice(uint256 nav_, uint256 reserve_) internal view returns (uint256 juniorTokenPrice_) {
        if ((nav_ == 0 && reserve_ == 0) || juniorTranche.tokenSupply() <= supplyTolerance) {
            // we are using a tolerance of 2 here, as there can be minimal supply leftovers after all redemptions due to rounding
            // initial token price at start 1.00
            return ONE;
        }
        // reserve includes creditline from maker
        uint256 totalAssets = safeAdd(nav_, reserve_);

        // includes creditline from mkr
        uint256 seniorAssetValue = calcExpectedSeniorAsset(seniorDebt(), seniorBalance_);

        if (totalAssets < seniorAssetValue) {
            return 0;
        }

        // the junior tranche only needs to pay for the mkr over-collateralization if
        // the mkr vault is liquidated, if that is true juniorStake=0
        uint256 juniorStake = 0;
        if (address(lending) != address(0)) {
            juniorStake = lending.juniorStake();
        }

        return rdiv(safeAdd(safeSub(totalAssets, seniorAssetValue), juniorStake), juniorTranche.tokenSupply());
    }

    /// @notice accumulates the senior interest
    /// @return _seniorDebt the senior debt
    function dripSeniorDebt() public returns (uint256 _seniorDebt) {
        seniorDebt_ = seniorDebt();
        lastUpdateSeniorInterest = block.timestamp;
        return seniorDebt_;
    }

    /// @notice returns the senior debt with up to date interest
    /// @return _seniorDebt senior debt
    function seniorDebt() public view returns (uint256 _seniorDebt) {
        if (block.timestamp >= lastUpdateSeniorInterest) {
            return chargeInterest(seniorDebt_, seniorInterestRate.value, lastUpdateSeniorInterest);
        }
        return seniorDebt_;
    }

    /// @notice returns the senior balance including unused creditline from adapters
    /// @return _seniorBalance senior balance
    function seniorBalance() public view returns (uint256 _seniorBalance) {
        return safeAdd(seniorBalance_, remainingOvercollCredit());
    }

    /// @notice returns the effective senior balance without unused creditline from adapters
    /// @return _seniorBalance senior balance
    function effectiveSeniorBalance() public view returns (uint256 _seniorBalance) {
        return seniorBalance_;
    }

    /// @notice returns the effective total balance
    /// @return _effectiveTotalBalance total balance
    function effectiveTotalBalance() public view returns (uint256 _effectiveTotalBalance) {
        return reserve.totalBalance();
    }

    /// @notice returns the total balance including unused creditline from adapters
    /// which means the total balance if the creditline were fully used
    /// @return _totalBalance total balance
    function totalBalance() public view returns (uint256 _totalBalance) {
        return safeAdd(reserve.totalBalance(), remainingCredit());
    }

    /// @notice returns the latest stored NAV or forces an update if a stale period has passed
    /// @return _nav the NAV
    function getNAV() public view returns (uint256 _nav) {
        if (block.timestamp >= navFeed.lastNAVUpdate() + maxStaleNAV) {
            return navFeed.currentNAV();
        }

        return navFeed.latestNAV();
    }

    /// @notice ward call to communicate the amount of currency available for new loan originations
    /// in the next epoch
    /// @param currencyAmount the amount of currency available for new loan orginations in the next epoch
    function changeBorrowAmountEpoch(uint256 currencyAmount) public auth {
        reserve.file("currencyAvailable", currencyAmount);
    }

    /// @notice returns the amount left for new loan originations in the current epoch
    function borrowAmountEpoch() public view returns (uint256 currencyAvailable_) {
        return reserve.currencyAvailable();
    }

    /// @notice returns the current junior ratio protection in the Tinlake
    /// @return juniorRatio_ is denominated in RAY (10^27)
    function calcJuniorRatio() public view returns (uint256 juniorRatio_) {
        uint256 seniorAsset = safeAdd(seniorDebt(), seniorBalance_);
        uint256 assets = safeAdd(getNAV(), reserve.totalBalance());

        if (seniorAsset == 0 && assets == 0) {
            return 0;
        }

        if (seniorAsset == 0 && assets > 0) {
            return ONE;
        }

        if (seniorAsset > assets) {
            return 0;
        }

        return safeSub(ONE, rdiv(seniorAsset, assets));
    }

    /// @notice returns the remainingCredit plus a buffer for the interest increase
    /// @return _remainingCredit remaining credit
    function remainingCredit() public view returns (uint256 _remainingCredit) {
        if (address(lending) == address(0)) {
            return 0;
        }

        // over the time the remainingCredit will decrease because of the accumulated debt interest
        // therefore a buffer is reduced from the  remainingCredit to prevent the usage of currency which is not available
        uint256 debt = lending.debt();
        uint256 stabilityBuffer = safeSub(rmul(rpow(lending.stabilityFee(), creditBufferTime, ONE), debt), debt);
        uint256 remainingCredit_ = lending.remainingCredit();
        if (remainingCredit_ > stabilityBuffer) {
            return safeSub(remainingCredit_, stabilityBuffer);
        }

        return 0;
    }

    /// @notice returns the remainingCredit considering a potential required overcollataralization
    /// @return remainingOvercollCredit_ remaining credit
    function remainingOvercollCredit() public view returns (uint256 remainingOvercollCredit_) {
        if (address(lending) == address(0)) {
            return 0;
        }

        return lending.calcOvercollAmount(remainingCredit());
    }
}
