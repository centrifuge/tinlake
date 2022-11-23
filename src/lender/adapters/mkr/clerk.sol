// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import "tinlake-math/interest.sol";

interface ManagerLike {
    // put collateral into cdp
    function join(uint256 amountDROP) external;
    // draw DAi from cdp
    function draw(uint256 amountDAI) external;
    // repay cdp debt
    function wipe(uint256 amountDAI) external;
    // remove collateral from cdp
    function exit(uint256 amountDROP) external;
    // collateral ID
    function ilk() external view returns (bytes32);
    // indicates if soft-liquidation was activated
    function safe() external view returns (bool);
    // indicates if hard-liquidation was activated
    function glad() external view returns (bool);
    // indicates if global settlement was triggered
    function live() external view returns (bool);
    // auth functions
    function file(bytes32 what, address data) external;

    function urn() external view returns (address);
}

// MKR contract
interface VatLike {
    function urns(bytes32, address) external view returns (uint256, uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}
// MKR contract

interface SpotterLike {
    function ilks(bytes32) external view returns (address, uint256);
}
// MKR contract

interface JugLike {
    function ilks(bytes32) external view returns (uint256, uint256);
    function drip(bytes32 ilk) external returns (uint256 rate);
    function base() external view returns (uint256);
}

interface GemJoinLike {
    function ilk() external view returns (bytes32);
}

interface UrnLike {
    function gemJoin() external view returns (address);
}

interface AssessorLike {
    function calcSeniorTokenPrice() external view returns (uint256);
    function calcSeniorAssetValue(uint256 seniorDebt_, uint256 seniorBalance_) external view returns (uint256);
    function changeSeniorAsset(uint256 seniorSupply, uint256 seniorRedeem) external;
    function seniorDebt() external view returns (uint256);
    function seniorBalance() external view returns (uint256);
    function getNAV() external view returns (uint256);
    function totalBalance() external view returns (uint256);
    function calcExpectedSeniorAsset(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 seniorBalance_,
        uint256 seniorDebt_
    ) external view returns (uint256);
    function changeBorrowAmountEpoch(uint256 currencyAmount) external;
    function borrowAmountEpoch() external view returns (uint256);
}

interface CoordinatorLike {
    function validateRatioConstraints(uint256 assets, uint256 seniorAsset) external view returns (int256);
    function calcSeniorAssetValue(
        uint256 seniorRedeem,
        uint256 seniorSupply,
        uint256 currSeniorAsset,
        uint256 reserve_,
        uint256 nav_
    ) external returns (uint256);
    function calcSeniorRatio(uint256 seniorAsset, uint256 NAV, uint256 reserve_) external returns (uint256);
    function submissionPeriod() external view returns (bool);
}

interface ReserveLike {
    function totalBalance() external returns (uint256);
    function hardDeposit(uint256 daiAmount) external;
    function hardPayout(uint256 currencyAmount) external;
}

interface TrancheLike {
    function mint(address usr, uint256 amount) external;
    function token() external returns (address);
}

interface ERC20Like {
    function burn(address, uint256) external;
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function approve(address usr, uint256 amount) external;
}

/// @notice operator contract for MKR interactions
contract Clerk is Auth, Interest {
    // max amount of DAI that can be brawn from MKR
    uint256 public creditline;

    // tinlake contracts
    CoordinatorLike public coordinator;
    AssessorLike public assessor;
    ReserveLike public reserve;
    TrancheLike public tranche;

    // MKR contracts
    ManagerLike public mgr;
    VatLike public vat;
    SpotterLike public spotter;
    JugLike public jug;

    ERC20Like public immutable dai;
    ERC20Like public collateral;

    uint256 public constant WAD = 10 * 18;

    // buffer to add on top of mat to avoid cdp liquidation => default 1%
    uint256 public matBuffer = 0.01 * 10 ** 27;

    // collateral tolerance accepted because of potential rounding problems
    uint256 public collateralTolerance = 10;

    // maximum amount which can be used to heal as part of a draw operation
    // if the collateral deficit is higher a specific heal call is required
    uint256 public autoHealMax = 100 ether;

    // the debt is only repaid if amount is higher than the threshold
    // repaying a lower amount would cause more cost in gas fees than the debt reduction
    uint256 public wipeThreshold = 1 * WAD;

    // adapter functions can only be active if the tinlake pool is currently not in epoch closing/submissions/execution state
    modifier active() {
        require(activated(), "epoch-closing");
        _;
    }

    /// @notice returns true if the clerk is active
    /// @return active_ true if the clerk is active
    function activated() public view returns (bool active_) {
        return coordinator.submissionPeriod() == false && mkrActive();
    }

    /// @notice returns true if the MKR cdp is active
    /// @return active_ true if the MKR cdp is active
    function mkrActive() public view returns (bool active_) {
        return mgr.safe() && mgr.glad() && mgr.live();
    }

    event Depend(bytes32 indexed contractName, address addr);
    event File(bytes32 indexed what, uint256 value);

    constructor(address dai_, address collateral_) {
        dai = ERC20Like(dai_);
        collateral = ERC20Like(collateral_);
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /// @notice sets the dependency to another contract
    /// @param contractName name of the contract
    /// @param addr contract address
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "mgr") {
            mgr = ManagerLike(addr);
        } else if (contractName == "coordinator") {
            coordinator = CoordinatorLike(addr);
        } else if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "reserve") {
            reserve = ReserveLike(addr);
        } else if (contractName == "tranche") {
            tranche = TrancheLike(addr);
        } else if (contractName == "collateral") {
            collateral = ERC20Like(addr);
        } else if (contractName == "spotter") {
            spotter = SpotterLike(addr);
        } else if (contractName == "vat") {
            vat = VatLike(addr);
        } else if (contractName == "jug") {
            jug = JugLike(addr);
        } else {
            revert();
        }
        emit Depend(contractName, addr);
    }

    /// @notice changes the parameter of the clerk by wards
    /// @param what name of the parameter
    /// @param value new value of the parameter
    function file(bytes32 what, uint256 value) public auth {
        if (what == "buffer") {
            matBuffer = value;
        } else if (what == "tolerance") {
            collateralTolerance = value;
        } else if (what == "wipeThreshold") {
            wipeThreshold = value;
        } else if (what == "autoHealMax") {
            autoHealMax = value;
        } else {
            revert();
        }
        emit File(what, value);
    }

    /// @notice returns the remaining creditline from MKR
    /// @return creditline_ remaining creditline
    function remainingCredit() public view returns (uint256 creditline_) {
        uint256 debt_ = debt();
        if (creditline <= debt_ || mkrActive() == false) {
            return 0;
        }
        return safeSub(creditline, debt_);
    }

    /// @notice returns a collateral deficit if existing
    /// @return deficit collateral deficit
    function collatDeficit() public view returns (uint256 deficit) {
        uint256 lockedCollateralDAI = rmul(cdpink(), assessor.calcSeniorTokenPrice());
        uint256 requiredCollateralDAI = calcOvercollAmount(debt());

        if (requiredCollateralDAI > collateralTolerance) {
            requiredCollateralDAI = safeSub(requiredCollateralDAI, collateralTolerance);
        }

        if (requiredCollateralDAI > lockedCollateralDAI) {
            return safeSub(requiredCollateralDAI, lockedCollateralDAI);
        }
        return 0;
    }

    /// @notice returns the remaining creditline including a potential overcollateralization
    /// @return remaining_ remaining creditline
    function remainingOvercollCredit() public view returns (uint256 remaining_) {
        return calcOvercollAmount(remainingCredit());
    }

    /// @notice junior stake in the cdpink -> value of drop used for debt protection
    /// @return juniorStake_ of junior value at stake for overcollateralization
    function juniorStake() public view returns (uint256 juniorStake_) {
        // junior looses stake in case vault is in soft/hard liquidation mode
        uint256 collateralValue = rmul(cdpink(), assessor.calcSeniorTokenPrice());
        uint256 mkrDebt = debt();
        if (mkrActive() == false || collateralValue < mkrDebt) {
            return 0;
        }
        return safeSub(collateralValue, mkrDebt);
    }

    /// @notice increases MKR credit line
    /// @param amountDAI amount to increase creditline
    function raise(uint256 amountDAI) public auth active {
        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be increased
        uint256 overcollAmountDAI = calcOvercollAmount(amountDAI);
        // protection value for the creditline increase coming from the junior tranche => amount by that the juniorAssetValue should be decreased
        uint256 protectionDAI = safeSub(overcollAmountDAI, amountDAI);
        // check if the new creditline would break the pool constraints
        require((validate(0, protectionDAI, overcollAmountDAI, 0) == 0), "violates-constraints");
        // increase MKR crediline by amount
        creditline = safeAdd(creditline, amountDAI);
        // make increase in creditline available to new loans
        assessor.changeBorrowAmountEpoch(safeAdd(assessor.borrowAmountEpoch(), amountDAI));
    }

    /// @notice draw performs the following steps: mint DROP, join DROP into cdp, draw DAI and send to reserve
    /// @param amountDAI amount of DAI to draw
    function draw(uint256 amountDAI) public auth active {
        // make sure to heal CDP before drawing new DAI
        uint256 healAmountDAI = collatDeficit();

        require(healAmountDAI <= autoHealMax, "collateral-deficit-heal-needed");

        require(amountDAI <= remainingCredit(), "not-enough-credit-left");
        // collateral value that needs to be locked in vault to draw amountDAI
        uint256 collateralDAI = safeAdd(calcOvercollAmount(amountDAI), healAmountDAI);
        uint256 collateralDROP = rdiv(collateralDAI, assessor.calcSeniorTokenPrice());
        // mint required DROP
        tranche.mint(address(this), collateralDROP);
        // join collateral into the cdp
        collateral.approve(address(mgr), collateralDROP);
        mgr.join(collateralDROP);
        // draw dai from cdp
        mgr.draw(amountDAI);
        // move dai to reserve
        dai.approve(address(reserve), amountDAI);
        reserve.hardDeposit(amountDAI);
        // increase seniorAsset by collateralDAI
        updateSeniorAsset(0, collateralDAI);
    }

    /// @notice transfer DAI from reserve, wipe cdp debt, exit DROP from cdp, burn DROP, harvest junior profit
    /// @param amountDAI amount of DAI to wipe
    function wipe(uint256 amountDAI) public auth active {
        // if amountDAI is too low, required transaction fees of wipe would be higher
        // only continue with wipe if amountDAI is higher than wipeThreshold;
        if (amountDAI < wipeThreshold) {
            return;
        }

        uint256 debt_ = debt();
        require((debt_ > 0), "cdp-debt-already-repaid");

        // repayment amount should not exceed cdp debt
        if (amountDAI > debt_) {
            amountDAI = debt_;
        }

        uint256 dropPrice = assessor.calcSeniorTokenPrice();
        // get DAI from reserve
        reserve.hardPayout(amountDAI);
        // repay cdp debt
        dai.approve(address(mgr), amountDAI);
        mgr.wipe(amountDAI);
        // harvest junior interest & burn surplus drop
        _harvest(dropPrice);
    }

    /// @notice harvest the junior profit. Increased collateral value over time allows to reduce the needed amount of collateral
    function harvest() public active {
        _harvest(assessor.calcSeniorTokenPrice());
    }

    /// @notice internal helper function for harvest
    /// @param dropPrice price of DROP (seniorToken)
    function _harvest(uint256 dropPrice) internal {
        require((cdpink() > 0), "no-profit-to-harvest");

        uint256 lockedCollateralDAI = rmul(cdpink(), dropPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint256 requiredLocked = calcOvercollAmount(debt());

        if (lockedCollateralDAI < requiredLocked) {
            // nothing to harvest, currently under-collateralized;
            return;
        }
        uint256 profitDAI = safeSub(lockedCollateralDAI, requiredLocked);
        uint256 profitDROP = safeDiv(safeMul(profitDAI, ONE), dropPrice);
        // remove profitDROP from the vault & brun them
        mgr.exit(profitDROP);
        collateral.burn(address(this), profitDROP);
        // decrease the seniorAssetValue by profitDAI -> DROP price stays constant
        updateSeniorAsset(profitDAI, 0);
    }

    /// @notice decrease MKR creditline
    /// @param amountDAI amount of DAI to decrease creditline
    function sink(uint256 amountDAI) public auth active {
        require(remainingCredit() >= amountDAI, "decrease-amount-too-high");

        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be decreased
        uint256 overcollAmountDAI = calcOvercollAmount(amountDAI);
        // protection value for the creditline decrease going to the junior tranche => amount by that the juniorAssetValue should be increased
        uint256 protectionDAI = safeSub(overcollAmountDAI, amountDAI);
        // check if the new creditline would break the pool constraints
        require((validate(protectionDAI, 0, 0, overcollAmountDAI) == 0), "pool-constraints-violated");

        // increase MKR crediline by amount
        creditline = safeSub(creditline, amountDAI);
        // decrease in creditline impacts amount available for new loans

        uint256 borrowAmountEpoch = assessor.borrowAmountEpoch();

        if (borrowAmountEpoch <= amountDAI) {
            assessor.changeBorrowAmountEpoch(0);
            return;
        }

        assessor.changeBorrowAmountEpoch(safeSub(borrowAmountEpoch, amountDAI));
    }

    /// @notice increases the amount of collateral by minting new senior token (diluting other holders)
    /// @param amountDAI amount of DAI to increase collateral
    function heal(uint256 amountDAI) public auth active {
        uint256 collatDeficitDAI = collatDeficit();
        require(collatDeficitDAI > 0, "no-healing-required");

        // heal max up to the required missing collateral amount
        if (collatDeficitDAI < amountDAI) {
            amountDAI = collatDeficitDAI;
        }

        require((validate(0, amountDAI, 0, 0) == 0), "violates-constraints");
        // mint drop and move into vault
        uint256 priceDROP = assessor.calcSeniorTokenPrice();
        uint256 collateralDROP = rdiv(amountDAI, priceDROP);
        tranche.mint(address(this), collateralDROP);
        collateral.approve(address(mgr), collateralDROP);
        mgr.join(collateralDROP);
        // increase seniorAsset by amountDAI
        updateSeniorAsset(0, amountDAI);
    }

    /// @notice heal the cdp and put in more drop in case the collateral value has fallen below the bufferedmat ratio
    function heal() public auth active {
        uint256 collatDeficitDAI = collatDeficit();
        if (collatDeficitDAI > 0) {
            heal(collatDeficitDAI);
        }
    }

    /// @notice checks if the Maker credit line increase could violate the pool constraints // -> make function pure and call with current pool values approxNav
    /// @param juniorSupplyDAI  amount of new junior supply
    /// @param juniorRedeemDAI  amount of junior redeem
    /// @param seniorSupplyDAI  amount of new senior supply
    /// @param seniorRedeemDAI  amount of senior redeem
    /// @param err 0 if no error, otherwise error code
    function validate(
        uint256 juniorSupplyDAI,
        uint256 juniorRedeemDAI,
        uint256 seniorSupplyDAI,
        uint256 seniorRedeemDAI
    ) public view returns (int256 err) {
        uint256 newAssets = safeSub(
            safeSub(
                safeAdd(safeAdd(safeAdd(assessor.totalBalance(), assessor.getNAV()), seniorSupplyDAI), juniorSupplyDAI),
                juniorRedeemDAI
            ),
            seniorRedeemDAI
        );
        uint256 expectedSeniorAsset = assessor.calcExpectedSeniorAsset(
            seniorRedeemDAI, seniorSupplyDAI, assessor.seniorBalance(), assessor.seniorDebt()
        );
        return coordinator.validateRatioConstraints(newAssets, expectedSeniorAsset);
    }

    function updateSeniorAsset(uint256 decreaseDAI, uint256 increaseDAI) internal {
        assessor.changeSeniorAsset(increaseDAI, decreaseDAI);
    }

    /// @notice returns the collateral amount in the cdp
    /// @return ink_ amount in the cdp (in senior tokens)
    function cdpink() public view returns (uint256 ink_) {
        uint256 ink = collateral.balanceOf(address(mgr));
        return ink;
    }

    /// @notice returns the required security margin for the DROP tokens
    /// @return totalMat required security margin
    function mat() public view returns (uint256 totalMat) {
        (, uint256 mat_) = spotter.ilks(ilk());
        return safeAdd(mat_, matBuffer); //  e.g 150% denominated in RAY
    }

    /// @notice helper function that returns the overcollateralized DAI amount considering the current mat value
    /// @param amountDAI amount of DAI
    function calcOvercollAmount(uint256 amountDAI) public view returns (uint256) {
        return rmul(amountDAI, mat());
    }

    /// @notice in case contract received DAI as a leftover from the cdp liquidation return back to reserve
    function returnDAI() public auth {
        uint256 amountDAI = dai.balanceOf(address(this));
        dai.approve(address(reserve), amountDAI);
        reserve.hardDeposit(amountDAI);
    }

    /// @notice change the owner in the mgr contract
    /// @param usr new owner address
    function changeOwnerMgr(address usr) public auth {
        mgr.file("owner", usr);
    }

    /// @notice returns the current debt from the Maker vault
    /// @return debt_ current debt
    function debt() public view returns (uint256 debt_) {
        bytes32 ilk_ = ilk();
        // get debt index
        (, uint256 art) = vat.urns(ilk_, mgr.urn());

        // get accumulated interest rate index
        (, uint256 rateIdx,,,) = vat.ilks(ilk_);

        // get interest rate per second and last interest rate update timestamp
        (uint256 duty, uint256 rho) = jug.ilks(ilk_);

        // interest accumulation up to date
        if (block.timestamp == rho) {
            return rmul(art, rateIdx);
        }

        // calculate current debt (see jug.drip function in MakerDAO)
        return rmul(art, rmul(rpow(safeAdd(jug.base(), duty), safeSub(block.timestamp, rho), ONE), rateIdx));
    }

    /// @notice returns the stabliity fee index from Maker
    /// @return stabilityFeeIndex_ stability fee index
    function stabilityFeeIndex() public view returns (uint256 stabilityFeeIndex_) {
        (, uint256 rate,,,) = vat.ilks(ilk());
        return rate;
    }

    /// @notice returns the stability fee from Maker
    /// @return stabilityFee_ stability fee
    function stabilityFee() public view returns (uint256 stabilityFee_) {
        // mkr.duty is the stability fee in the mkr system
        (uint256 duty,) = jug.ilks(ilk());
        return safeAdd(jug.base(), duty);
    }

    /// @notice returns the ilk (collateral type/name) from Maker
    /// @return ilk_ ilk
    function ilk() public view returns (bytes32 ilk_) {
        return GemJoinLike(UrnLike(mgr.urn()).gemJoin()).ilk();
    }
}
