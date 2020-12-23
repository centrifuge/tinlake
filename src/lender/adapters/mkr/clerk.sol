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

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";

interface ManagerLike {
    // collateral debt
    function cdptab() external returns(uint);
    // put collateral into cdp
    function join(uint amountDROP) external;
    // draw DAi from cdp
    function draw(uint amountDAI, address usr) external;
    // repay cdp debt
    function wipe(uint amountDAI) external;
    // remove collateral from cdp
    function exit(address usr, uint amountDROP) external;
    // collateral ID
    function ilk() external returns(bytes32);
    // indicates if soft-liquidation was activated
    function safe() external returns(bool);
    // indicates if hard-liquidation was activated
    function glad() external returns(bool);
    // indicates if global settlement was triggered
    function live() external returns(bool);
    // auth functions
    function setOwner(address newOwner) external;
}

interface VatLike {
    function urns(bytes32, address) external returns (uint,uint);
}

interface SpotterLike {
    function ilks(bytes32) external returns(address, uint256);
}

interface AssessorLike {
    function calcSeniorTokenPrice() external returns(uint);
    function calcSeniorAssetValue(uint seniorDebt, uint seniorBalance) external returns(uint);
    function changeSeniorAsset(uint seniorSupply, uint seniorRedeem) external;
    function seniorDebt() external returns(uint);
    function seniorBalance() external returns(uint);
    function currentNAV() external view returns(uint);
    function totalBalance() external returns(uint);
    function calcExpectedSeniorAsset(uint seniorRedeem, uint seniorSupply, uint seniorBalance_, uint seniorDebt_) external view returns(uint);
    }

interface CoordinatorLike {
    function validate(uint reserve, uint nav, uint seniorAsset, uint seniorRedeem, uint juniorRedeem, uint seniorSupply, uint juniorSupply) external returns(int);
    function validatePoolConstraints(uint reserve_, uint seniorAsset, uint nav_) external returns(int);
    function calcSeniorAssetValue(uint seniorRedeem, uint seniorSupply, uint currSeniorAsset, uint reserve_, uint nav_) external returns(uint);
    function calcSeniorRatio(uint seniorAsset, uint NAV, uint reserve_) external returns(uint);
    function submissionPeriod() external returns(bool);
}

interface ReserveLike {
    function totalBalance() external returns(uint);
    function deposit(uint daiAmount) external;
    function payout(uint currencyAmount) external;
}

interface TrancheLike {
    function mint(address usr, uint amount) external;
    function token() external returns(address);
}

interface ERC20Like {
    function burn(address, uint) external;
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function approve(address usr, uint amount) external;
}

contract Clerk is Auth, Math {

    // max amount of DAI that can be brawn from MKR
    uint public creditline;

    // tinlake contracts
    CoordinatorLike coordinator;
    AssessorLike assessor;
    ReserveLike reserve;
    TrancheLike tranche;

    // MKR contracts
    ManagerLike mgr;
    VatLike vat;
    SpotterLike spotter;

    ERC20Like dai;
    ERC20Like collateral;

    // buffer to add on top of mat to avoid cdp liquidation => default 1%
    uint matBuffer = 0.01 * 10**27;

    // adapter functions can only be active if the tinlake pool is currently not in epoch closing/submissions/execution state
    modifier active() { require((coordinator.submissionPeriod() == false), "epoch-closing"); _; }

    constructor(address dai_, address collateral_) public {
        wards[msg.sender] = 1;
        dai =  ERC20Like(dai_);
        collateral =  ERC20Like(collateral_);
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "mgr") {
            mgr =  ManagerLike(addr);
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
        } else revert();
    }

    function file(bytes32 what, uint value) public auth {
        if (what == "buffer") {
            matBuffer = value;
        }
    }

    function remainingCredit() public returns (uint) {
        if (creditline <= (mgr.cdptab())) {
            return 0;
        }
        return safeSub(creditline, mgr.cdptab());
    }

    function collatDeficit() public returns (uint) {
        uint lockedCollateralDAI = rmul(cdpink(), assessor.calcSeniorTokenPrice());
        uint requiredCollateralDAI = calcOvercollAmount(mgr.cdptab());
        if (requiredCollateralDAI > lockedCollateralDAI) {
            return safeSub(requiredCollateralDAI, lockedCollateralDAI);
        }
        return 0;
    }

    function remainingOvercollCredit() public returns (uint) {
        return calcOvercollAmount(remainingCredit());
    }


   // junior stake in the cdpink -> value of drop used for cdptab protection
    function juniorStake() public returns (uint) {
        // junior looses stake in case cdp is in soft liquidation mode
        if (!(mgr.safe() && mgr.glad() && mgr.live())) {
            return 0;
        }
        return safeSub(rmul(cdpink(), assessor.calcSeniorTokenPrice()), mgr.cdptab());
    }

    // increase MKR credit line
    function raise(uint amountDAI) public auth active {
        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be increased
        uint overcollAmountDAI =  calcOvercollAmount(amountDAI);
        // protection value for the creditline increase coming from the junior tranche => amount by that the juniorAssetValue should be decreased
        uint protectionDAI = safeSub(overcollAmountDAI, amountDAI);
        // check if the new creditline would break the pool constraints
        require((validate(0, protectionDAI, overcollAmountDAI, 0) == 0), "supply not possible, pool constraints violated");
        // increase MKR crediline by amount
        creditline = safeAdd(creditline, amountDAI);
    }

    // mint DROP, join DROP into cdp, draw DAI and send to reserve
    function draw(uint amountDAI) public auth active {
        // make sure ther eis no collateral deficit before drawing out new DAI
        // require(collatDeficit() == 0, "please heal cdp first"); // tbd
        require(amountDAI <= remainingCredit(), "not enough credit left");
        // collateral value that needs to be locked in vault to draw amountDAI
        uint collateralDAI = calcOvercollAmount(amountDAI);
        uint collateralDROP = rdiv(collateralDAI, assessor.calcSeniorTokenPrice());
        // mint required DROP
        tranche.mint(address(this), collateralDROP);
        // join collateral into the cdp
        collateral.approve(address(mgr), collateralDROP);
        mgr.join(collateralDROP);
        // draw dai from cdp
        mgr.draw(amountDAI, address(this));
        // move dai to reserve
        dai.approve(address(reserve), amountDAI);
        reserve.deposit(amountDAI);
        // increase seniorAsset by amountDAI
        updateSeniorAsset(0, collateralDAI);
    }

    // transfer DAI from reserve, wipe cdp debt, exit DROP from cdp, burn DROP, harvest junior profit
    function wipe(uint amountDAI) public auth active {
        require((mgr.cdptab() > 0), "cdp debt already repaid");

        // repayment amount should not exceed cdp debt
        if (amountDAI > mgr.cdptab()) {
            amountDAI = mgr.cdptab();
        }
        // get DAI from reserve
        reserve.payout(amountDAI);
        // repay cdp debt
        dai.approve(address(mgr), amountDAI);
        mgr.wipe(amountDAI);

        // harvest junior interest & burn surplus drop
        harvest();
    }

    // harvest junior profit
    function harvest() public active {
        require((cdpink() > 0), "nothing profit to harvest");
        uint dropPrice = assessor.calcSeniorTokenPrice();
        uint lockedCollateralDAI = rmul(cdpink(), dropPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint profitDAI = safeSub(lockedCollateralDAI, calcOvercollAmount(mgr.cdptab()));
        uint profitDROP = rdiv(profitDAI, dropPrice);
        // remove profitDROP from the vault & brun them
        mgr.exit(address(this), profitDROP);
        collateral.burn(address(this), profitDROP);
        // decrease the seniorAssetValue by profitDAI -> DROP price stays constant
        updateSeniorAsset(profitDAI, 0);
    }

    // decrease MKR creditline
    function sink(uint amountDAI) public auth active {
        require(remainingCredit() >= amountDAI, "decrease amount too high");

        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be decreased
        uint overcollAmountDAI = calcOvercollAmount(amountDAI);
        // protection value for the creditline decrease going to the junior tranche => amount by that the juniorAssetValue should be increased
        uint protectionDAI = safeSub(overcollAmountDAI, amountDAI);
        // check if the new creditline would break the pool constraints
        require((validate(protectionDAI, 0, 0, overcollAmountDAI) == 0), "pool constraints violated");

        // increase MKR crediline by amount
        creditline = safeSub(creditline, amountDAI);
    }

    function heal(uint amountDAI) public auth active {
        uint collatDeficitDAI = collatDeficit();
        require(collatDeficitDAI > 0, "no healing required");

        // heal max up to the required missing collateral amount
        if (collatDeficitDAI < amountDAI) {
            amountDAI = collatDeficitDAI;
        }

        require((validate(0, amountDAI, 0, 0) == 0), "supply not possible, pool constraints violated");
        // mint drop and move into cdp
        uint priceDROP = assessor.calcSeniorTokenPrice();
        uint collateralDROP = rdiv(amountDAI, priceDROP);
        tranche.mint(address(this), collateralDROP);
        collateral.approve(address(mgr), collateralDROP);
        mgr.join(collateralDROP);
        // increase seniorAsset by amountDAI
        updateSeniorAsset(0, amountDAI);
    }

    // heal the cdp and put in more drop in case the collateral value has fallen below the bufferedmat ratio
    function heal() public auth active{
        uint collatDeficitDAI = collatDeficit();
        if (collatDeficitDAI > 0) {
            heal(collatDeficitDAI);
        }
    }

    // checks if the Maker credit line increase could violate the pool constraints // -> make function pure and call with current pool values approxNav
    function validate(uint juniorSupplyDAI, uint juniorRedeemDAI, uint seniorSupplyDAI, uint seniorRedeemDAI) internal returns(int) {
        uint newReserve = safeSub(safeSub(safeAdd(safeAdd(assessor.totalBalance(), seniorSupplyDAI),
            juniorSupplyDAI), juniorRedeemDAI), seniorRedeemDAI);
        uint expectedSeniorAsset = assessor.calcExpectedSeniorAsset(seniorRedeemDAI, seniorSupplyDAI,
            assessor.seniorBalance(), assessor.seniorDebt());
        return coordinator.validatePoolConstraints(newReserve, expectedSeniorAsset,
            assessor.currentNAV());
   }

    function updateSeniorAsset(uint decreaseDAI, uint increaseDAI) internal  {
        assessor.changeSeniorAsset(increaseDAI, decreaseDAI);
    }

    // returns the collateral amount in the cdp
    function cdpink() public returns (uint) {
        (uint ink, ) = vat.urns(mgr.ilk(), address(mgr));
        return ink;
    }

    // returns the required security margin for the DROP tokens
    function mat() public returns (uint) {
        (, uint256 mat) = spotter.ilks(mgr.ilk());
        return safeAdd(mat, matBuffer); //  e.g 150% denominated in RAY
    }

    // helper function that returns the overcollateralized DAI amount considering the current mat value
    function calcOvercollAmount(uint amountDAI) public returns (uint) {
        return rmul(amountDAI, mat());
    }

        // In case contract received DAI as a leftover from the cdp liquidation return back to reserve
    function returnDAI() public auth {
        uint amountDAI = dai.balanceOf(address(this));
        dai.approve(address(reserve), amountDAI);
        reserve.deposit(amountDAI);
    }

    function changeOwnerMgr(address usr) public auth {
        mgr.setOwner(usr);
    }
}
