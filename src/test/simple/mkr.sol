pragma solidity >=0.5.15 <0.6.0;
import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";

interface ERC20Like {
    function transferFrom(address from, address to, uint amount) external;
    function mint(address to, uint amount) external;
    function burn(address usr, uint amount) external;
    function balanceOf(address usr) external returns (uint);
}

// simple mock implementation of relevant MKR contracts
// contract will mint currency tokens to simulate the mkr behaviour
// implements mgr, spotter, vat interfaces
contract SimpleMkr is Math {

    ERC20Like public currency;
    ERC20Like public drop;
    uint public stabilityFee;

    uint debt;

    bytes32 public ilk;

    bool safeFlag;

    constructor(uint stabilityFee_, bytes32 ilk_) public {
        stabilityFee = stabilityFee_;
        ilk = ilk_;
        safeFlag = true;
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

    // collateral debt
    function cdptab() external returns(uint) {
        return debt;
    }
    // put collateral into cdp
    function join(uint amountDROP) external {
        drop.transferFrom(msg.sender, address(this), amountDROP);
    }
    // draw DAI from cdp
    function draw(uint amountDAI, address usr) external  {
        currency.mint(usr, amountDAI);
        debt = safeAdd(debt, amountDAI);
    }
    // repay cdp debt
    function wipe(uint amountDAI) external {
        currency.transferFrom(msg.sender, address(this), amountDAI);
        currency.burn(address(this), amountDAI);
        debt = safeSub(debt, amountDAI);
    }
    // remove collateral from cdp
    function exit(address usr, uint amountDROP) external {
        drop.transferFrom(address(this), usr, amountDROP);
    }

    // indicates if soft-liquidation was activated
    function safe() external returns(bool) {
        return safeFlag;
    }

    // VAT Like
    function urns(bytes32, address) external returns (uint,uint) {
        return (drop.balanceOf(address(this)), 0);
    }

    function ilks(bytes32) external returns(uint, uint, uint, uint, uint)  {
        return(0, stabilityFee, 0, 0, 0);
    }

//    // Spotter Like
//    function ilks(bytes32) external returns(address, uint256) {
//        return (address(drop), mat);
//    }
}
