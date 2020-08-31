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

    uint256 public currencyAvailable;

    address self;

    constructor(address currency_) public {
        wards[msg.sender] = 1;
        currency = ERC20Like(currency_);
        self = address(this);
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

    function file(bytes32 what, uint amount) public auth {
        if (what == "maxcurrency") {
            currencyAvailable = amount;
        } else revert();
    }

    function increaseMaxCurrency(uint256 amount) public auth {
        currencyAvailable = safeAdd(currencyAvailable, amount);
    }

    function balance() public {
        (bool requestWant, uint256 currencyAmount) = shelf.balanceRequest();
        if (requestWant) {
            require(
                currencyAvailable >= currencyAmount,
                "not-enough-currency-reserve"
            );
            currencyAvailable = safeSub(currencyAvailable, currencyAmount);
            require(
                currency.transferFrom(self, address(shelf), currencyAmount),
                "currency-transfer-from-reserve-failed"
            );
            assessor.borrowUpdate(currencyAmount);
            return;
        }
        require(
            currency.transferFrom(address(shelf), self, currencyAmount),
            "currency-transfer-from-shelf-failed"
        );
        assessor.repaymentUpdate(currencyAmount);
    }
}
