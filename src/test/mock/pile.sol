pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;

contract PileMock {
    // calls
    uint public callsTotalBalance;
    uint public callsBorrow;
    uint public callsRepay;
    uint public callsWithdraw;

    struct Loan {
        uint debt;
        uint balance;
        uint fee;
        uint chi;
    }


    // returns
    uint public debtReturn; function setDebtReturn(uint debtReturn_) public {debtReturn=debtReturn_;}
    uint public balanceReturn; function setBalanceReturn(uint balanceReturn_) public {balanceReturn=balanceReturn_;}
    uint public totalBalanceReturn; function setTotalBalanceReturn(uint totalBalanceReturn_) public {totalBalanceReturn=totalBalanceReturn_;}
    int public wantReturn; function setWantReturn(int wantReturn_) public {wantReturn=wantReturn_;}
    Loan public loanReturn; function setLoanReturn(uint debt, uint balance, uint fee, uint chi) public {loanReturn = Loan(debt, balance, fee, chi);}

    uint public loan;
    uint public wad;
    address public usr;

    function totalBalance() public returns (uint) {
        callsTotalBalance++;
        return totalBalanceReturn;
    }
    function borrow(uint loan_, uint wad_) public  {
        loan = loan_;
        wad = wad_;
        callsBorrow++;
    }

    function repay(uint loan_, uint wad_, address usr_) public {
        loan = loan_;
        wad = wad_;
        usr = usr_;
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
}
