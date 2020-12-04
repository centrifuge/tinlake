pragma solidity >=0.5.15. <0.6.0;

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
    function ilk() external returns(bytes);
}

interface VatLike {
    function urns(bytes32,address) external returns (uint,uint);
}

interface SpotterLike {
    function ilks(bytes32) public returns(address, uint256);
}

interface AssessorLike {
    function calcSeniorTokenPrice() external view returns(uint);
    function changeSeniorAsset(uint seniorRatio, uint seniorSupply, uint seniorRedeem) external;
    function seniorDebt() external returns(uint);
    function seniorBalance() external returns(uint);
}

interface NAVFeedLike {
    function currentNAV() external view returns(uint);
}

interface CoordinatorLike {
    function validate(uint seniorRedeem, uint juniorRedeem, uint seniorSupply, uint juniorSupply) external view returns(int);
    function calcSeniorAssetValue(uint seniorRedeem, uint seniorSupply, uint currSeniorAsset, uint reserve_, uint nav_) external pure returns(uint) ;
    function calcSeniorRatio(uint seniorAsset, uint NAV, uint reserve_) external pure returns(uint);
    function submissionPeriod() external returns(bool);
}

interface ReserveLike {
    function totalBalance() external view returns(uint);
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
    // remaing amount of DAI that can be brrowed from MKR
    uint remainingCredit;

    // tinlake contracts
    CoordinatorLike coordinator;
    AssessorLike assessor;
    ReserveLike reserve;
    TrancheLike tranche;
    NAVFeedLike nav;

    // MKR contracts
    ManagerLike mgr;
    VatLike vat;
    SpotterLike spotter;

    ERC20Like dai;
    ERC20Like collateral;

    // adapter functions can only be active if the tinlake pool is currently not in epoch closing/submissions/execution state
    modifier active() { (coordinator.submissionPeriod() == false); _; }

    constructor(address dai_, address spotter_, address vat_) {
        vat = VatLike(vat_);
        spotter = SpotterLike(spotter_);
        dai =  ERC20Like(dai_);
        
        wards[msg.sender] = 1;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "mgr") {
            mgr =  ManagerLike(mgr);
        } else if (contractName == "coordinator") {
            coordinator = CoordinatorLike(addr);
        } else if (contractName == "assessor") {
            coordinator = AssessorLike(addr);
        } else if (contractName == "nav") {
            nav = NAVFeedLike(addr);
        } else if (contractName == "reserve") {
            reserve = ReserveLike(addr);
        } else if (contractName == "tranche") {
            tranche = TrancheLike(addr);
            collateral = ERC20Like(tranche.token());
        } else revert();
    }

    function remainingCredit() public view returns (uint) {
        if (creditline < mgr.cdptab()) {
            return 0;
        }
        return safeSub(creditline, mgr.cdptab());
    }

    // junior stake in the cdpink -> value of drop used for cdptab protection
    function juniorStake() public view returns (uint) {
        return safeSub(rmul(mgr.cdptab(), mat()), mgr.cdptab());
    }

    // increase MKR credit line 
    function raise(uint amountDAI) public auth active {
        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be increased
        overcollAmountDAI = rmul(amountDAI, mat());
        // protection value for the creditline increase coming from the junior tranche => amount by that the juniorAssetValue should be decreased
        uint protectionDAI = safeSub(overcollAmountDAI, amountDAI);
        
        // check if the new creditline would break the pool constraints
        validate(0, protectionDAI, overcollAmountDAI, 0);
    
        // increase MKR crediline by amount
        creditline = safeAdd(creditline, amountDAI);
    }

    // mint DROP, join DROP into cdp, draw DAI and send to reserve
    function draw(uint amountDAI) public auth active {
        require(amountDAI <= remainingCredit(), "not enough credit left");

        // collateral value that needs to be locked in vault to draw amountDAI
        uint collateralDAI = rmul(amountDAI, mat());
        uint collateralDROP = rdiv(collateralDAI, assessor.calcSeniorTokenPrice());
        
        // mint required DROP
        tranche.mint(address(this), amountDROP);
        // join collateral into the cdp
        mgr.join(collateralDROP);
        // draw dai from cdp
        mgr.draw(amountDAI, address(this));
        // move dai to reserve
        dai.approve(address(reserve), amountDAI);
        reserve.deposit(amountDAI);
    }

    // transfer DAI from reserve, wipe cdp debt, exit DROP from cdp, burn DROP, harvest junior profit
    function wipe(uint amountDAI) public auth active {
        require((mgr.tab() > 0), "cdp debt already repaid");

        uint repayDAI = amountDAI;
        // repayment amount should not exceed cdp debt
        if (amountDAI > mgr.tab()) {
            repayDAI = mgr.tab();
        }
        // get DAI from reserve
        reserve.payout(repayDAI);
        // repay cdp debt
        mgr.wipe(repayDAI); 
        // exit DROP worth repaid DAI
        uint collateralDROP = rdiv(repayDAI, assessor.calcSeniorTokenPrice());
        mgr.exit(address(this), collateralDROP);
        // burn DROP
        collateral.burn(address(this), amountDROP);
        // harvest junior interest 
        harvest();        
    }

    // harvest junior profit
    function harvest() public active {
        require(cdpink() > 0), "nothing profit to harvest");
        uint dropPrice = assessor.calcSeniorTokenPrice();
        uint lockedCollateralDAI = rmul(cdpink(), dropPrice);
        // profit => diff between the DAI value of the locked collateral in the cdp & the actual cdp debt including protection buffer
        uint profitDAI = safeSub(lockedCollateralDAI, rmul(mgr.cdptab(), mat());
        uint profitDROP = rdiv(profitDAI, dropPrice);
        // remove profitDROP from the vault & brun them
        mgr.exit(address(this), collateralDROP);
        collateral.burn(address(this), amountDROP);
        // decrease the seniorAssetValue by profitDAI -> DROP price stays constant
        decreaseSeniorAsset(profitDAI);
    }

    // decrease MKR creditline
    function sink(uint amountDAI) public auth active {
        require(remainingCredit() >= amountDAI, "decrease amount too high");

        // creditline amount including required overcollateralization => amount by that the seniorAssetValue should be decreased
        overcollAmountDAI = rmul(amountDAI, mat());
        // protection value for the creditline decrease going to the junior tranche => amount by that the juniorAssetValue should be increased
        uint protectionDAI = safeSub(overcollAmountDAI, amountDAI);

        uint juniorSupply, uint juniorRedeemDAI, uint seniorSupplyDAI, uint seniorRedeem
        
        // check if the new creditline would break the pool constraints
        validate(protectionDAI, 0, 0, overcollAmountDAI);
    
        // increase MKR crediline by amount
        creditline = safeSub(creditline, amountDAI);
    }

    // checks if the Maker credit line increase could violate the pool constraints // -> make function pure and call with current pool values approxNav
    function validate(uint juniorSupply, uint juniorRedeemDAI, uint seniorSupplyDAI, uint seniorRedeem) internal {
        require((coordinator.validate(juniorSupply, juniorRedeemDAI, seniorSupplyDAI, seniorRedeem) == 0), "supply not possible, pool constraints violated");
    }
    
    function decreaseSeniorAsset(uint amount) internal  {
        uint currenNav = nav.currentNAV();
        uint newSeniorAsset = coordinator.calcSeniorAssetValue(amount, 0,
            assessor.calcSeniorAssetValue(assessor.seniorDebt(), assessor.seniorBalance()), reserve.totalBalance(), currenNav);
        uint newSeniorRatio = coordinator.calcSeniorRatio(newSeniorAsset, currenNav, reserve.totalBalance());
        assessor.changeSeniorAsset(newSeniorRatio, supply, redeem);
    }

    // returns the collateral amount in the cdp
    function cdpink() public view returns (uint) {
        (uint ink, ) = vat.urns(mgr.ilk(), address(mgr));
        return ink;
    }

    // returns the required security margin for the DROP tokens
    function mat() public view returns (uint) {
        (, uint256 mat) = spotter.ilks(mgr.ilk());
        return mat; //  e.g 150% denominated in RAY
    }
