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
contract JugMock {
    uint public duty;
    uint public base = 10**27;
    function file(bytes32 what, uint value) external {
        if(what == "duty") {
          duty = value;
        }
    }

    function ilks(bytes32 ilk) public view returns (uint ,uint) {
        // interest rate up to date in simpleMKR
      return (duty, block.timestamp);
    }

    function drip(bytes32 ilk) public returns(uint) {return 0;}
}

contract UrnMock {
    address public gemJoin;
    constructor(address gemJoin_) public {
        gemJoin = gemJoin_;
    }
}

contract GemJoinMock {
    bytes32 public ilk;
    constructor(bytes32 ilk_) public {
        ilk = ilk_;
    }
}

contract SimpleMkr is Interest, DSTest{
    ERC20Like public currency;
    ERC20Like public drop;
    uint public ratePerSecond;

    uint public lastFeeUpdate;
    uint public pie;

    bytes32 public ilk;

    bool safeFlag;
    bool gladFlag;
    bool liveFlag;

    JugMock public jugMock;
    UrnMock public urn;

    constructor(uint ratePerSecond_, bytes32 ilk_) public {
        ratePerSecond = ratePerSecond_;
        ilk = ilk_;
        safeFlag = true;
        gladFlag = true;
        liveFlag = true;
        lastFeeUpdate = block.timestamp;
        jugMock = new JugMock();
        jugMock.file("duty", ratePerSecond_);

        GemJoinMock gemJoin = new GemJoinMock(ilk);
        urn = new UrnMock(address(gemJoin));
    }

    function file(bytes32 what, uint value) public {
        if(what == "stabilityFee") {
            if(pie > 0) {
                uint debt = rmul(pie, stabilityFee());
                pie = rdivup(debt, value);
            }
            ratePerSecond =  value;
            lastFeeUpdate = block.timestamp;
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

    // put collateral into cdp
    function join(uint amountDROP) external {
        drop.transferFrom(msg.sender, address(this), amountDROP);
    }
    // draw DAI from cdp
    function draw(uint amountDAI) external  {
        currency.mint(msg.sender, amountDAI);
        pie = safeAdd(pie, rdivup(amountDAI, stabilityFee()));
    }
    // repay cdp debt
    function wipe(uint amountDAI) external {
        currency.transferFrom(msg.sender, address(this), amountDAI);
        currency.burn(address(this), amountDAI);
        pie = safeSub(pie, rdivup(amountDAI, stabilityFee()));
    }
    // remove collateral from cdp
    function exit(uint amountDROP) external {
        drop.transferFrom(address(this), msg.sender, amountDROP);
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
        return(0, stabilityFee(),  0, 0, 0);
    }

    function stabilityFee() public view returns (uint) {
        if (block.timestamp > lastFeeUpdate) {
            return rpow(ratePerSecond, safeSub(block.timestamp, lastFeeUpdate), ONE);
        }
        return ratePerSecond;
    }
}
