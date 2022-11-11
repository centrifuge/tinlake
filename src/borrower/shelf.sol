// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

import {TitleOwned, TitleLike} from "tinlake-title/title.sol";

interface NFTLike {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface TokenLike {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external;
}

interface PileLike {
    function total() external view returns (uint256);
    function debt(uint256) external returns (uint256);
    function accrue(uint256) external;
    function incDebt(uint256, uint256) external;
    function decDebt(uint256, uint256) external;
}

interface NAVFeedLike {
    function borrow(uint256 loan, uint256 currencyAmount) external;
    function repay(uint256 loan, uint256 currencyAmount) external;
    function presentValue(uint256 loan) external view returns (uint256);
    function futureValue(uint256 loan) external view returns (uint256);
    function zeroPV(uint256 loan) external view returns (bool);
}

interface ReserveLike {
    function deposit(uint256 currencyAmount) external;
    function payoutForLoans(uint256 currencyAmount) external;
}

interface SubscriberLike {
    function borrowEvent(uint256 loan, uint256 amount) external;
    function repayEvent(uint256 loan, uint256 amount) external;
    function lockEvent(uint256 loan) external;
    function unlockEvent(uint256 loan) external;
}

interface AssessorLike {
    function reBalance() external;
}

contract Shelf is Auth, TitleOwned, Math {
    // --- Data ---
    NAVFeedLike public ceiling;
    PileLike public pile;
    TokenLike public currency;
    ReserveLike public reserve;
    AssessorLike public assessor;
    SubscriberLike public subscriber;

    uint256 public balance;

    struct Loan {
        address registry;
        uint256 tokenId;
    }

    mapping(uint256 => uint256) public balances;
    mapping(uint256 => Loan) public shelf;
    mapping(bytes32 => uint256) public nftlookup;

    // Events
    event Close(uint256 indexed loan);
    event Issue(address indexed registry_, uint256 indexed token_);
    event Borrow(uint256 indexed loan, uint256 currencyAmount);
    event Withdraw(uint256 indexed loan, uint256 currencyAmount, address usr);
    event Repay(uint256 indexed loan, uint256 currencyAmount);
    event Recover(uint256 indexed loan, address usr, uint256 currencyAmount);
    event Lock(uint256 indexed loan);
    event Unlock(uint256 indexed loan);
    event Claim(uint256 indexed loan, address usr);
    event Depend(bytes32 indexed contractName, address addr);

    constructor(address currency_, address title_, address pile_, address ceiling_) TitleOwned(title_) {
        currency = TokenLike(currency_);
        pile = PileLike(pile_);
        ceiling = NAVFeedLike(ceiling_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // sets the dependency to another contract
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "token") {
            currency = TokenLike(addr);
        } else if (contractName == "title") {
            title = TitleLike(addr);
        } else if (contractName == "pile") {
            pile = PileLike(addr);
        } else if (contractName == "ceiling") {
            ceiling = NAVFeedLike(addr);
        } else if (contractName == "reserve") {
            if (address(reserve) != address(0)) currency.approve(address(reserve), uint256(0));
            currency.approve(addr, type(uint256).max);
            reserve = ReserveLike(addr);
        } else if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "subscriber") {
            subscriber = SubscriberLike(addr);
        } else {
            revert();
        }
        emit Depend(contractName, addr);
    }

    function token(uint256 loan) public view returns (address registry, uint256 nft) {
        return (shelf[loan].registry, shelf[loan].tokenId);
    }

    // issues a new loan in Tinlake - it requires the ownership of an nft
    // first step in the loan process - everyone could add an nft
    function issue(address registry_, uint256 token_) external returns (uint256) {
        require(NFTLike(registry_).ownerOf(token_) == msg.sender, "nft-not-owned");
        bytes32 nft = keccak256(abi.encodePacked(registry_, token_));
        require(nftlookup[nft] == 0, "nft-in-use");
        uint256 loan = title.issue(msg.sender);
        nftlookup[nft] = loan;
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = token_;

        emit Issue(registry_, token_);
        return loan;
    }

    function close(uint256 loan) external {
        require(!nftLocked(loan), "nft-locked");
        (address registry, uint256 tokenId) = token(loan);
        require(
            title.ownerOf(loan) == msg.sender || NFTLike(registry).ownerOf(tokenId) == msg.sender,
            "not-loan-or-nft-owner"
        );
        title.close(loan);
        bytes32 nft = keccak256(abi.encodePacked(shelf[loan].registry, shelf[loan].tokenId));
        nftlookup[nft] = 0;
        _resetLoanBalance(loan);
        emit Close(loan);
    }

    // starts the borrow process of a loan
    // informs the system of the requested currencyAmount
    // interest accumulation starts with this method
    // the method can only be called if the nft is locked
    // a max ceiling needs to be defined by an oracle
    function borrow(uint256 loan, uint256 currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");

        if (address(subscriber) != address(0)) {
            subscriber.borrowEvent(loan, currencyAmount);
        }

        pile.accrue(loan);

        balances[loan] = safeAdd(balances[loan], currencyAmount);
        balance = safeAdd(balance, currencyAmount);

        // payout to shelf
        reserve.payoutForLoans(currencyAmount);

        // increase NAV
        ceiling.borrow(loan, currencyAmount);
        pile.incDebt(loan, currencyAmount);

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();

        emit Borrow(loan, currencyAmount);
    }

    // withdraw transfers the currency to the borrower account
    function withdraw(uint256 loan, uint256 currencyAmount, address usr) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(currencyAmount <= balances[loan], "withdraw-amount-too-high");

        balances[loan] = safeSub(balances[loan], currencyAmount);
        balance = safeSub(balance, currencyAmount);
        require(currency.transfer(usr, currencyAmount), "currency-transfer-failed");
        emit Withdraw(loan, currencyAmount, usr);
    }

    // repays the entire or partial debt of a loan
    function repay(uint256 loan, uint256 currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(balances[loan] == 0, "withdraw-required-before-repay");

        if (address(subscriber) != address(0)) {
            subscriber.repayEvent(loan, currencyAmount);
        }

        pile.accrue(loan);
        uint256 loanDebt = pile.debt(loan);

        // only repay max loan debt
        if (currencyAmount > loanDebt) {
            currencyAmount = loanDebt;
        }
        require(currency.transferFrom(msg.sender, address(this), currencyAmount), "currency-transfer-failed");
        ceiling.repay(loan, currencyAmount);
        pile.decDebt(loan, currencyAmount);
        reserve.deposit(currencyAmount);

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();

        emit Repay(loan, currencyAmount);
    }

    // a collector can recover defaulted loans
    // it is not required to recover the entire loan debt
    function recover(uint256 loan, address usr, uint256 currencyAmount) external auth {
        pile.accrue(loan);

        uint256 loanDebt = pile.debt(loan);

        require(currency.transferFrom(usr, address(this), currencyAmount), "currency-transfer-failed");

        ceiling.repay(loan, loanDebt);
        // sets loan debt to 0
        pile.decDebt(loan, loanDebt);
        _resetLoanBalance(loan);
        reserve.deposit(currencyAmount);
        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();
        emit Recover(loan, usr, currencyAmount);
    }

    // locks an nft in the shelf
    // requires an issued loan
    function lock(uint256 loan) external owner(loan) {
        if (address(subscriber) != address(0)) {
            subscriber.lockEvent(loan);
        }
        NFTLike(shelf[loan].registry).transferFrom(msg.sender, address(this), shelf[loan].tokenId);
        emit Lock(loan);
    }

    // unlocks an nft in the shelf
    // requires zero debt or 100% write off
    function unlock(uint256 loan) external owner(loan) {
        // loans can be unlocked and closed when the debt is 0, or the loan is written off 100%
        uint256 debt_ = pile.debt(loan);

        require(debt_ == 0 || ceiling.zeroPV(loan), "loan-has-outstanding-debt");

        if (address(subscriber) != address(0)) {
            subscriber.unlockEvent(loan);
        }

        NFTLike(shelf[loan].registry).transferFrom(address(this), msg.sender, shelf[loan].tokenId);

        emit Unlock(loan);
    }

    function nftLocked(uint256 loan) public view returns (bool) {
        return NFTLike(shelf[loan].registry).ownerOf(shelf[loan].tokenId) == address(this);
    }

    // a loan can be claimed by a collector if the loan debt is above the loan threshold
    // transfers the nft to the collector
    function claim(uint256 loan, address usr) public auth {
        NFTLike(shelf[loan].registry).transferFrom(address(this), usr, shelf[loan].tokenId);
        emit Claim(loan, usr);
    }

    function _resetLoanBalance(uint256 loan) internal {
        uint256 loanBalance = balances[loan];
        if (loanBalance > 0) {
            balances[loan] = 0;
            balance = safeSub(balance, loanBalance);
        }
    }

    // returns the total number of loans including closed loans
    function loanCount() public view returns (uint256) {
        return title.count();
    }
}
