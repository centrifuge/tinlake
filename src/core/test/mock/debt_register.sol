pragma solidity >=0.4.24;

contract DebtRegisterMock {

    uint public callsIncLoanDebt;
    uint public callsDecLoanDebt;
    uint public callsDrip;
    uint public callsBurden;
    uint public callsDebtOf;
    uint public callsFile;

    struct Rate {
        uint debt;
        uint chi;
        uint speed;
        uint48 rho;
    }

    uint public loanDebtReturn; function setLoanDebtReturn(uint loanDebtReturn_) public {loanDebtReturn=loanDebtReturn_;}
    uint public getCurrentDebtReturn; function setBurdenReturn(uint getCurrentDebtReturn_) public {getCurrentDebtReturn=getCurrentDebtReturn_;}
    uint public totalDebtReturn; function setTotalDebtReturn(uint totalDebtReturn_) public {totalDebtReturn=totalDebtReturn_;} 
    Rate public rateReturn; function setRateReturn(uint debt, uint chi, uint speed, uint48 rho) public {rateReturn = Rate(debt, chi, speed, rho);}

    address public usr;
    uint public loan;
    uint public wad;
    uint public rate;
    uint public speed;

    function rates(uint loan) public view returns(uint, uint, uint, uint) {
        return (rateReturn.debt, rateReturn.chi, rateReturn.speed, rateReturn.rho);
    }

    function incLoanDebt(uint loan_, uint rate_, uint wad_) public {
       loan = loan_;
       rate = rate_;
       wad = wad_;
       callsIncLoanDebt++;
    }

    function decLoanDebt(uint loan_, uint rate_, uint wad_) public {
       loan = loan_;
       rate = rate_;
       wad = wad_;
       callsDecLoanDebt++;
    }

    function drip(uint rate_) public {
        rate = rate_;
        callsDrip++;
    }

    function getCurrentDebt(uint loan_, uint rate_) public returns (uint){
       return getCurrentDebtReturn;
    }

    function debtOf(uint loan_, uint rate_) public returns (uint){
       return loanDebtReturn;
    }

    function totalDebt() public returns (uint){
        return totalDebtReturn;
    }

    function file(uint rate_, uint speed_) public {
        callsFile++;
        rate = rate_;
        speed = speed_;
    }

}
