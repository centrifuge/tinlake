pragma solidity >=0.5.15 <0.6.0;
import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "../../../lib/tinlake-math/src/interest.sol";
import "ds-test/test.sol";

interface ERC20Like {
    function transferFrom(address from, address to, uint amount) external;
    function mint(address to, uint amount) external;
    function burn(address usr, uint amount) external;
    function balanceOf(address usr) external view returns (uint);
}

// simple mock implementation of relevant MKR contracts
// contract will mint currency tokens to simulate the mkr behaviour
// implements mgr, spotter, vat interfaces
contract SimpleMkr is Interest, DSTest{
    ERC20Like public currency;
    ERC20Like public drop;
    uint public stabilityFee;
    uint public ratePerSecond;

    uint public lastDebtUpdate;
    uint public pie;

    bytes32 public ilk;

    bool safeFlag;
    bool gladFlag;
    bool liveFlag;

    constructor(uint stabilityFee_, bytes32 ilk_) public {
        stabilityFee = stabilityFee_;
        ratePerSecond =  stabilityFee_;
        ilk = ilk_;
        safeFlag = true;
        gladFlag = true;
        liveFlag = true;
        lastDebtUpdate = block.timestamp;
    }

    function file(bytes32 what, uint value) public {
        if(what == "stabilityFee") {
            if(pie > 0) {
                dripFee();
                uint debt = rmul(pie, stabilityFee);
                pie = rdivup(debt, value);
            }
            stabilityFee = value;
            ratePerSecond =  value;
        }
        else {
            revert();
        }
    }

    function file(bytes32 what, bool value) public {
        if(what == "safe") {
            safeFlag = value;
        } else if (what == "glad") {
            gladFlag = value;
        } else if (what == "live") {
            liveFlag = value;
        } else {
            revert();
        }
    }

    function depend(bytes32 name, address addr) public {
        if(name == "currency") {
            currency = ERC20Like(addr);
        } else if (name == "drop") {
            drop = ERC20Like(addr);
        } else {
            revert();
        }
    }
    
    function dripFee() public returns (uint) {
        if (block.timestamp >= lastDebtUpdate) {
            stabilityFee = rpow(ratePerSecond, safeSub(block.timestamp, lastDebtUpdate), ONE);
            lastDebtUpdate = block.timestamp;
        }
    }

    // put collateral into cdp
    function join(uint amountDROP) external {
        drop.transferFrom(msg.sender, address(this), amountDROP);
    }
    // draw DAI from cdp
    function draw(uint amountDAI, address usr) external  {
        currency.mint(usr, amountDAI);
        dripFee();
        pie = safeAdd(pie, rdivup(amountDAI, stabilityFee));
    }
    // repay cdp debt
    function wipe(uint amountDAI) external {
        currency.transferFrom(msg.sender, address(this), amountDAI);
        currency.burn(address(this), amountDAI);
        dripFee();
        pie = safeSub(pie, rmul(amountDAI, stabilityFee));
    }
    // remove collateral from cdp
    function exit(address usr, uint amountDROP) external {
        drop.transferFrom(address(this), usr, amountDROP);
    }

    // indicates if soft-liquidation was activated
    function safe() external returns(bool) {
        return safeFlag;
    }

    // indicates if soft-liquidation was activated
    function glad() external returns(bool) {
        return gladFlag;
    }

    // indicates if soft-liquidation was activated
    function live() external returns(bool) {
        return liveFlag;
    }

    // VAT Like
    function urns(bytes32, address) external view returns (uint,uint) {
        return (drop.balanceOf(address(this)), pie);
    }

    function ilks(bytes32) external view returns(uint, uint, uint, uint, uint)  {
        return(0, stabilityFee, 0, 0, 0);
    }
}
