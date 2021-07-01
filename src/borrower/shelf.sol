// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";
import { TitleOwned, TitleLike } from "tinlake-title/title.sol";

interface NFTLike {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface TokenLike {
    function totalSupply() external view returns(uint);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address,address,uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint) external;
}

interface PileLike {
    function total() external view returns(uint);
    function debt(uint) external returns (uint);
    function accrue(uint) external;
    function incDebt(uint, uint) external;
    function decDebt(uint, uint) external;
}

interface NAVFeedLike {
    function borrow(uint loan, uint currencyAmount) external;
    function repay(uint loan, uint currencyAmount) external;
}

interface ReserveLike {
    function balance() external;
}

interface SubscriberLike {
    function borrowEvent(uint loan) external;
    function unlockEvent(uint loan) external;
}

interface AssessorLike {
    function reBalance() external;
}

contract Shelf is Auth, TitleOwned, Math {

    // --- Data ---
    NAVFeedLike         public ceiling;
    PileLike            public pile;
    TokenLike           public currency;
    ReserveLike         public reserve;
    AssessorLike        public assessor;
    SubscriberLike      public subscriber;

    uint                public balance;
    address             public lender;

    struct Loan {
        address registry;
        uint256 tokenId;
    }

    mapping (uint => uint) public balances;
    mapping (uint => Loan) public shelf;
    mapping (bytes32 => uint) public nftlookup;

    // Events
    event Close(uint indexed loan);
    event Issue(address indexed registry_, uint indexed token_);
    event Borrow(uint indexed loan, uint currencyAmount);
    event Withdraw(uint indexed loan, uint currencyAmount, address usr);
    event Repay(uint indexed loan, uint currencyAmount);
    event Recover(uint indexed loan, address usr, uint currencyAmount);
    event Lock(uint indexed loan);
    event Unlock(uint indexed loan);
    event Claim(uint indexed loan, address usr);
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
        if (contractName == "lender") {
            if (lender != address(0)) currency.approve(lender, uint(0));
            currency.approve(addr, type(uint256).max);
            lender = addr;
        }
        else if (contractName == "token") { currency = TokenLike(addr); }
        else if (contractName == "title") { title = TitleLike(addr); }
        else if (contractName == "pile") { pile = PileLike(addr); }
        else if (contractName == "ceiling") { ceiling = NAVFeedLike(addr); }
        else if (contractName == "reserve") { reserve = ReserveLike(addr); }
        else if (contractName == "assessor") { assessor = AssessorLike(addr);}
        else if (contractName == "subscriber") { subscriber = SubscriberLike(addr); }
        else revert();
        emit Depend(contractName, addr);
    }

    function token(uint loan) public view returns (address registry, uint nft) {
        return (shelf[loan].registry, shelf[loan].tokenId);
    }

    // issues a new loan in Tinlake - it requires the ownership of an nft
    // first step in the loan process - everyone could add an nft
    function issue(address registry_, uint token_) external returns (uint) {
        require(NFTLike(registry_).ownerOf(token_) == msg.sender, "nft-not-owned");
        bytes32 nft = keccak256(abi.encodePacked(registry_, token_));
        require(nftlookup[nft] == 0, "nft-in-use");
        uint loan = title.issue(msg.sender);
        nftlookup[nft] = loan;
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = token_;

        emit Issue(registry_, token_);
        return loan;
    }

    function close(uint loan) external {
        require(pile.debt(loan) == 0, "loan-has-outstanding-debt");
        require(!nftLocked(loan), "nft-not-locked");
        (address registry, uint tokenId) = token(loan);
        require(title.ownerOf(loan) == msg.sender || NFTLike(registry).ownerOf(tokenId) == msg.sender, "not-loan-or-nft-owner");
        title.close(loan);
        bytes32 nft = keccak256(abi.encodePacked(shelf[loan].registry, shelf[loan].tokenId));
        nftlookup[nft] = 0;
        resetLoanBalance(loan);
        emit Close(loan);
    }

    // used by the lender contracts to know if currency is needed or currency can be taken
    function balanceRequest() external view returns (bool, uint) {
        uint currencyBalance = currency.balanceOf(address(this));
        if (balance > currencyBalance) {
            return (true, safeSub(balance, currencyBalance));

        } else {
            return (false, safeSub(currencyBalance, balance));
        }
    }

    // starts the borrow process of a loan
    // informs the system of the requested currencyAmount
    // interest accumulation starts with this method
    // the method can only be called if the nft is locked
    // a max ceiling needs to be defined by an oracle
    function borrow(uint loan, uint currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        if(address(subscriber) != address(0)) {
            subscriber.borrowEvent(loan);
        }
        pile.accrue(loan);

        balances[loan] = safeAdd(balances[loan], currencyAmount);
        balance = safeAdd(balance, currencyAmount);

        // request currency from lender contracts
        reserve.balance();

        // increase NAV
        ceiling.borrow(loan, currencyAmount);
        pile.incDebt(loan, currencyAmount);

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();

        emit Borrow(loan, currencyAmount);
    }


    // withdraw transfers the currency to the borrower account
    function withdraw(uint loan, uint currencyAmount, address usr) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(currencyAmount <= balances[loan], "withdraw-amount-too-high");

        balances[loan] = safeSub(balances[loan], currencyAmount);
        balance = safeSub(balance, currencyAmount);
        require(currency.transfer(usr, currencyAmount), "currency-transfer-failed");
        emit Withdraw(loan, currencyAmount, usr);
    }

    // repays the entire or partial debt of a loan
    function repay(uint loan, uint currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(balances[loan] == 0, "withdraw-required-before-repay");
        _repay(loan, msg.sender, currencyAmount);
        emit Repay(loan, currencyAmount);
    }

    // a collector can recover defaulted loans
    // it is not required to recover the entire loan debt
    function recover(uint loan, address usr, uint currencyAmount) external auth {
        pile.accrue(loan);

        uint loanDebt = pile.debt(loan);

        require(currency.transferFrom(usr, address(this), currencyAmount), "currency-transfer-failed");

        ceiling.repay(loan, loanDebt);
        // sets loan debt to 0
        pile.decDebt(loan, loanDebt);
        resetLoanBalance(loan);
        reserve.balance();
        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();
        emit Recover(loan, usr, currencyAmount);
    }

    function _repay(uint loan, address usr, uint currencyAmount) internal {
        pile.accrue(loan);
        uint loanDebt = pile.debt(loan);

        // only repay max loan debt
        if (currencyAmount > loanDebt) {
            currencyAmount = loanDebt;
        }
        require(currency.transferFrom(usr, address(this), currencyAmount), "currency-transfer-failed");
        ceiling.repay(loan, currencyAmount);
        pile.decDebt(loan, currencyAmount);
        reserve.balance();

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();
    }

    // locks an nft in the shelf
    // requires an issued loan
    function lock(uint loan) external owner(loan) {
        if(address(subscriber) != address(0)) {
            subscriber.unlockEvent(loan);
        }
        NFTLike(shelf[loan].registry).transferFrom(msg.sender, address(this), shelf[loan].tokenId);
        emit Lock(loan);
    }

    // unlocks an nft in the shelf
    // requires zero debt
    function unlock(uint loan) external owner(loan) {
        require(pile.debt(loan) == 0, "loan-has-outstanding-debt");
        NFTLike(shelf[loan].registry).transferFrom(address(this), msg.sender, shelf[loan].tokenId);
        emit Unlock(loan);
    }

    function nftLocked(uint loan) public view returns (bool) {
        return NFTLike(shelf[loan].registry).ownerOf(shelf[loan].tokenId) == address(this);
    }

    // a loan can be claimed by a collector if the loan debt is above the loan threshold
    // transfers the nft to the collector
    function claim(uint loan, address usr) public auth {
        NFTLike(shelf[loan].registry).transferFrom(address(this), usr, shelf[loan].tokenId);
        emit Claim(loan, usr);
    }

    function resetLoanBalance(uint loan) internal {
        uint loanBalance = balances[loan];
        if (loanBalance  > 0) {
            balances[loan] = 0;
            balance = safeSub(balance, loanBalance);
        }
    }
}
