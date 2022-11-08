// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "../../../lib/tinlake-math/src/interest.sol";
import "forge-std/Test.sol";

interface ERC20Like {
    function transferFrom(address from, address to, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function burn(address usr, uint256 amount) external;
    function balanceOf(address usr) external view returns (uint256);
}

// simple mock implementation of relevant MKR contracts
// contract will mint currency tokens to simulate the mkr behaviour
// implements mgr, spotter, vat interfaces
contract JugMock {
    uint256 public duty;
    uint256 public base = 0;

    function file(bytes32 what, uint256 value) external {
        if (what == "duty") {
            duty = value;
        }
    }

    function ilks(bytes32) public view returns (uint256, uint256) {
        // interest rate up to date in simpleMKR
        return (duty, block.timestamp);
    }

    function drip(bytes32) public pure returns (uint256) {
        return 0;
    }
}

contract UrnMock {
    address public gemJoin;

    constructor(address gemJoin_) {
        gemJoin = gemJoin_;
    }
}

contract GemJoinMock {
    bytes32 public ilk;

    constructor(bytes32 ilk_) {
        ilk = ilk_;
    }
}

contract SimpleMkr is Interest, Test, Auth {
    ERC20Like public currency;
    ERC20Like public drop;
    uint256 public ratePerSecond;

    uint256 public lastFeeUpdate;
    uint256 public pie;

    bytes32 public ilk;

    bool safeFlag;
    bool gladFlag;
    bool liveFlag;

    JugMock public jugMock;
    UrnMock public urn;

    constructor(uint256 ratePerSecond_, bytes32 ilk_) {
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

        wards[msg.sender] = 1;
    }

    function file(bytes32 what, uint256 value) public {
        if (what == "stabilityFee") {
            if (pie > 0) {
                uint256 debt = rmul(pie, stabilityFee());
                pie = rdivup(debt, value);
            }
            ratePerSecond = value;
            lastFeeUpdate = block.timestamp;
        } else {
            revert();
        }
    }

    function file(bytes32 what, bool value) public {
        if (what == "safe") {
            safeFlag = value;
        } else if (what == "glad") {
            gladFlag = value;
        } else if (what == "live") {
            liveFlag = value;
        } else {
            revert();
        }
    }

    function file(bytes32 what, address addr) public {
        // enable file(bytes32, address) calls to make it compatible with the TinlakeManager interface
        emit log_named_bytes32("file_what", what);
        emit log_named_address("file_addr", addr);
        return;
    }

    function lock(uint256 amt) public {
        // enable lock(uint) calls to make it compatible with the TinlakeManager interface
        emit log_named_uint("lock_amt", amt);
        return;
    }

    function depend(bytes32 name, address addr) public {
        if (name == "currency") {
            currency = ERC20Like(addr);
        } else if (name == "drop") {
            drop = ERC20Like(addr);
        } else {
            revert();
        }
    }

    // put collateral into cdp
    function join(uint256 amountDROP) external {
        drop.transferFrom(msg.sender, address(this), amountDROP);
    }
    // draw DAI from cdp

    function draw(uint256 amountDAI) external {
        currency.mint(msg.sender, amountDAI);
        pie = safeAdd(pie, rdivup(amountDAI, stabilityFee()));
    }
    // repay cdp debt

    function wipe(uint256 amountDAI) external {
        currency.transferFrom(msg.sender, address(this), amountDAI);
        currency.burn(address(this), amountDAI);
        pie = safeSub(pie, rdivup(amountDAI, stabilityFee()));
    }
    // remove collateral from cdp

    function exit(uint256 amountDROP) external {
        drop.transferFrom(address(this), msg.sender, amountDROP);
    }

    // indicates if soft-liquidation was activated
    function safe() external view returns (bool) {
        return safeFlag;
    }

    // indicates if soft-liquidation was activated
    function glad() external view returns (bool) {
        return gladFlag;
    }

    // indicates if soft-liquidation was activated
    function live() external view returns (bool) {
        return liveFlag;
    }

    // VAT Like
    function urns(bytes32, address) external view returns (uint256, uint256) {
        return (drop.balanceOf(address(this)), pie);
    }

    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256) {
        return (0, stabilityFee(), 0, 0, 0);
    }

    function stabilityFee() public view returns (uint256) {
        if (block.timestamp > lastFeeUpdate) {
            return rpow(ratePerSecond, safeSub(block.timestamp, lastFeeUpdate), ONE);
        }
        return ratePerSecond;
    }
}
