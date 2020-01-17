pragma solidity >=0.4.24;

contract PileMock {

    uint public callsIncDebt;
    uint public callsDecDebt;
    uint public callsAccrue;
    uint public callsFile;
    uint public callsSetRate;
    uint public callsChangeRate;

    struct Rate {
        uint pie;
        uint chi;
        uint speed;
        uint48 rho;
    }

    // returns
    uint public totalReturn; function setTotalReturn(uint totalReturn_) public {totalReturn=totalReturn_;}
    uint public debtReturn; function setDebtReturn(uint debtReturn_) public {debtReturn=debtReturn_;}
    uint public loanDebtReturn; function setLoanDebtReturn(uint loanDebtReturn_) public {loanDebtReturn=loanDebtReturn_;}
    uint public getCurrentDebtReturn; function setBurdenReturn(uint getCurrentDebtReturn_) public {getCurrentDebtReturn=getCurrentDebtReturn_;}
    uint public totalDebtReturn; function setTotalDebtReturn(uint totalDebtReturn_) public {totalDebtReturn=totalDebtReturn_;}
    Rate public rateReturn; function setRateReturn(uint pie, uint chi, uint speed, uint48 rho) public {rateReturn = Rate(pie, chi, speed, rho);}

    address public usr;
    uint public loan;
    uint public wad;
    uint public rate;
    uint public balance;

    function total() public returns(uint) {
        return totalReturn;
    }

    uint public speed;

    function rates(uint loan) public view returns(uint, uint, uint, uint) {
        return (rateReturn.pie, rateReturn.chi, rateReturn.speed, rateReturn.rho);
    }

    function setRate(uint loan_, uint rate_) public {
        loan = loan_;
        rate = rate_;
        callsSetRate++;

    }

    function changeRate(uint loan_, uint rate_) public {
        loan = loan_;
        rate = rate_;
        callsChangeRate++;

    }

    function debt(uint loan) public returns(uint) {
        return loanDebtReturn;
    }

    function debt() public returns(uint) {
        return debtReturn;
    }

    function incDebt(uint loan_, uint wad_) public {
       loan = loan_;
       wad = wad_;
       callsIncDebt++;
    }

    function decDebt(uint loan_, uint wad_) public {
       loan = loan_;
       wad = wad_;
       callsDecDebt++;
    }

    function accrue(uint loan_) public {
        loan = loan_;
        callsAccrue++;
    }

    function file(uint rate_, uint speed_) public {
        callsFile++;
        rate = rate_;
        speed = speed_;
    }

}
