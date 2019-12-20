pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;

contract PileMock {
    // calls
    uint public callsTotalBalance;
    uint public callsBorrow;
    uint public callsRepay;
    uint public callsWithdraw;
    uint public callsFile;
    uint public callsCollect;
    uint public callsRecovery;

    struct Loan {
        uint debt;
        uint balance;
        uint rate;
    }

    // returns
    uint public debtReturn; function setLoanDebtReturn(uint debtReturn_) public {debtReturn=debtReturn_;}
    uint public debtOfReturn; function setDebtOfReturn(uint debtOfReturn_) public {debtOfReturn=debtOfReturn_;}
    uint public balanceReturn; function setBalanceReturn(uint balanceReturn_) public {balanceReturn=balanceReturn_;}
    uint public totalBalanceReturn; function setTotalBalanceReturn(uint totalBalanceReturn_) public {totalBalanceReturn=totalBalanceReturn_;}
    int public wantReturn; function setWantReturn(int wantReturn_) public {wantReturn=wantReturn_;}
    Loan public loanReturn; function setLoanReturn(uint debt, uint balance, uint rate) public {loanReturn=Loan(debt,balance,rate);}

    uint public loan;
    uint public wad;
    uint public rate;
    address public usr;
    uint public balance;

    function totalBalance() public returns (uint) {
        callsTotalBalance++;
        return totalBalanceReturn;
    }

    function debtOf(uint loan) public returns (uint) {
        return debtOfReturn;
    }


    function recovery(uint loan_, address usr_, uint wad_) public  {
        loan = loan_;
        wad = wad_;
        usr = usr_;
        callsRecovery++;
    }

    function borrow(uint loan_, uint wad_) public  {
        loan = loan_;
        wad = wad_;
        callsBorrow++;
    }

    function collect(uint loan_) public {
        loan = loan_;
        callsCollect++;
    }

    function repay(uint loan_, uint wad_) public {
        loan = loan_;
        wad = wad_;
        callsRepay++;
    }

    function withdraw(uint loan_, uint wad_, address usr_) public  {
        loan = loan_;
        wad = wad_;
        usr = usr_;
        callsWithdraw++;
    }

    function debt(uint loan_) public returns (uint) {
        loan = loan_;
        return debtReturn;
    }

    function balanceOf(uint loan_) public returns (uint) {
        return balanceReturn;
    }

    function loans(uint loan_) public returns (Loan memory) {
        return loanReturn;
    }

    function want() public view returns (int) {
       return wantReturn;
    }

    function file(uint loan_, uint rate_, uint balance_) public {
        callsFile++;
        loan = loan_;
        rate = rate_;
        balance = balance_;
    }
}
