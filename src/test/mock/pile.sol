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

    struct Loan {
        uint debt;
        uint balance;
        uint fee;
        uint chi;
    }

    struct Fee {
        uint debt;
        uint chi;
        uint speed; // Accumulation per second
        uint48 rho; // Last time the rate was accumulated
    }

    // returns
    uint public debtReturn; function setDebtReturn(uint debtReturn_) public {debtReturn=debtReturn_;}
    uint public balanceReturn; function setBalanceReturn(uint balanceReturn_) public {balanceReturn=balanceReturn_;}
    uint public totalBalanceReturn; function setTotalBalanceReturn(uint totalBalanceReturn_) public {totalBalanceReturn=totalBalanceReturn_;}
    int public wantReturn; function setWantReturn(int wantReturn_) public {wantReturn=wantReturn_;}
    Loan public loanReturn; function setLoanReturn(uint debt, uint balance, uint fee, uint chi) public {loanReturn = Loan(debt, balance, fee, chi);}
    Fee public feeReturn; function setFeeReturn(uint debt, uint chi, uint speed, uint48 rho) public {feeReturn = Fee(debt,chi,speed, rho);}

    function fees(uint loan) public view returns(uint, uint, uint, uint) {
        return (feeReturn.debt,feeReturn.chi,feeReturn.speed, feeReturn.rho);
    }

    uint public loan;
    uint public wad;
    address public usr;
    uint public balance;
    uint public fee;
    uint public speed;

    function totalBalance() public returns (uint) {
        callsTotalBalance++;
        return totalBalanceReturn;
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



    function file(uint loan_, uint fee_, uint balance_) public {
        callsFile++;
        loan = loan_;
        fee = fee_;
        balance = balance_;

    }
    function file(uint fee_, uint speed_) public {
        callsFile++;
        fee = fee_;
        speed = speed_;
    }
}
