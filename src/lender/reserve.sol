pragma solidity >=0.5.15 <0.6.0;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract ERC20Like {
    function balanceOf(address) public view returns (uint256);

    function transferFrom(
        address,
        address,
        uint256
    ) public returns (bool);

    function mint(address, uint256) public;

    function burn(address, uint256) public;

    function totalSupply() public view returns (uint256);
}

contract ShelfLike {
    function balanceRequest() public returns (bool requestWant, uint256 amount);
}

contract AssessorLike {
    function repaymentUpdate(uint amount) public;
    function borrowUpdate(uint amount) public;
}

contract Reserve is Math, Auth {
    ERC20Like public currency;
    ShelfLike public shelf;
    AssessorLike public assessor;

    // currency available for borrowing new loans
    uint256 public currencyAvailable;

    address self;

    // total currency in the reserve
    uint public balance_;

    constructor(address currency_) public {
        wards[msg.sender] = 1;
        currency = ERC20Like(currency_);
        self = address(this);
    }

    function file(bytes32 what, uint amount) public auth {
        if (what == "maxcurrency") {
            currencyAvailable = amount;
        } else revert();
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "shelf") {
            shelf = ShelfLike(addr);
        } else if (contractName == "currency") {
            currency = ERC20Like(addr);
        } else if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else revert();
    }

    function totalBalance() public view returns (uint) {
        return balance_;
    }

    function deposit(uint currencyAmount) public auth {
        _deposit(msg.sender, currencyAmount);
    }

    function _deposit(address usr, uint currencyAmount) internal {
        require(currency.transferFrom(usr, self, currencyAmount), "reserve-deposit-failed");
        balance_ = safeAdd(balance_, currencyAmount);
    }

    function payout(uint currencyAmount) public auth {
        _payout(msg.sender, currencyAmount);
    }

    function _payout(address usr, uint currencyAmount)  internal {
        require(currency.transferFrom(self, usr, currencyAmount), "reserve-payout-failed");
        balance_ = safeSub(balance_, currencyAmount);
    }


    function balance() public {
        (bool requestWant, uint256 currencyAmount) = shelf.balanceRequest();
        if (requestWant) {
            require(
                currencyAvailable >= currencyAmount,
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
