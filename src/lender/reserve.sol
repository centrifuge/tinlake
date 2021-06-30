// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

interface ERC20Like {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint) external returns (bool);
    function mint(address, uint256) external;
    function burn(address, uint256) external;
    function totalSupply() external view returns (uint256);
    function approve(address, uint) external;
}

interface ShelfLike {
    function balanceRequest() external returns (bool requestWant, uint256 amount);
}

interface AssessorLike {
    function repaymentUpdate(uint amount) external;
    function borrowUpdate(uint amount) external;
}

interface LendingAdapter {
    function remainingCredit() external view returns (uint);
    function draw(uint amount) external;
    function wipe(uint amount) external;
    function debt() external returns(uint);
    function activated() external view returns(bool);
}

// The reserve keeps track of the currency and the bookkeeping
// of the total balance
contract Reserve is Math, Auth {
    ERC20Like public currency;
    ShelfLike public shelf;
    AssessorLike public assessor;

    // additional currency from lending adapters
    // for deactivating set to address(0)
    LendingAdapter public lending;

    // currency available for borrowing new loans
    uint256 public currencyAvailable;

    // address or contract which holds the currency
    // by default it is address(this)
    address pot;

    // total currency in the reserve
    uint public balance_;

    constructor(address currency_) {
        wards[msg.sender] = 1;
        currency = ERC20Like(currency_);
        pot = address(this);
        currency.approve(pot, type(uint256).max);
    }

    function file(bytes32 what, uint amount) public auth {
        if (what == "currencyAvailable") {
            currencyAvailable = amount;
        } else revert();
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "shelf") {
            shelf = ShelfLike(addr);
        } else if (contractName == "currency") {
            currency = ERC20Like(addr);
            if (pot == address(this)) {
                currency.approve(pot, type(uint256).max);
            }
        } else if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "pot") {
            pot = addr;
        } else if (contractName == "lending") {
            lending = LendingAdapter(addr);
        } else revert();
    }

    // returns the amount of currency currently in the reserve
    function totalBalance() public view returns (uint) {
        return balance_;
    }

    // return the amount of currency and the available currency from the lending adapter
    function totalBalanceAvailable() public view returns (uint) {
        if(address(lending) == address(0)) {
            return balance_;
        }

        return safeAdd(balance_, lending.remainingCredit());
    }

    // deposits currency in the the reserve
    function deposit(uint currencyAmount) public auth {
        if(currencyAmount == 0) return;
        _deposit(msg.sender, currencyAmount);
    }

    // hard deposit guarantees that the currency stays in the reserve
    function hardDeposit(uint currencyAmount) public auth {
        _depositAction(msg.sender, currencyAmount);
    }

    function _depositAction(address usr, uint currencyAmount) internal {
        require(currency.transferFrom(usr, pot, currencyAmount), "reserve-deposit-failed");
        balance_ = safeAdd(balance_, currencyAmount);
    }

    function _deposit(address usr, uint currencyAmount) internal {
        _depositAction(usr, currencyAmount);
        if(address(lending) != address(0) && lending.debt() > 0 && lending.activated()) {
            uint wipeAmount = lending.debt();
            uint available = currency.balanceOf(pot);
            if(available < wipeAmount) {
                wipeAmount = available;
            }
            lending.wipe(wipeAmount);
        }
    }

    // remove currency from the reserve
    function payout(uint currencyAmount) public auth {
        if(currencyAmount == 0) return;
        _payout(msg.sender, currencyAmount);
    }

    function _payoutAction(address usr, uint currencyAmount) internal {
        require(currency.transferFrom(pot, usr, currencyAmount), "reserve-payout-failed");
        balance_ = safeSub(balance_, currencyAmount);
    }

    // hard payout guarantees that the currency stays in the reserve
    function hardPayout(uint currencyAmount) public auth {
        _payoutAction(msg.sender, currencyAmount);
    }

    function _payout(address usr, uint currencyAmount)  internal {
        uint reserveBalance = currency.balanceOf(pot);
        if (currencyAmount > reserveBalance && address(lending) != address(0) && lending.activated()) {
            uint drawAmount = safeSub(currencyAmount, reserveBalance);
            uint left = lending.remainingCredit();
            if(drawAmount > left) {
                drawAmount = left;
            }
            
            lending.draw(drawAmount);
        }

        _payoutAction(usr, currencyAmount);
    }

    // balance handles currency requests from the borrower side
    // currency is moved between shelf and reserve if needed
    function balance() public {
        (bool requestWant, uint256 currencyAmount) = shelf.balanceRequest();
        if(currencyAmount == 0) {
            return;
        }
        if (requestWant) {
            require(
                currencyAvailable  >= currencyAmount,
                "not-enough-currency-reserve"
            );

            currencyAvailable = safeSub(currencyAvailable, currencyAmount);
            _payout(address(shelf), currencyAmount);
            assessor.borrowUpdate(currencyAmount);
            return;
        }
        _deposit(address(shelf), currencyAmount);
        assessor.repaymentUpdate(currencyAmount);
    }
}
