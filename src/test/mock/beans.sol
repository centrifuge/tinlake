pragma solidity >=0.4.24;

contract BeansMock {

    uint public callsIncLoanDebt;
    uint public callsDecLoanDebt;
    uint public callsDrip;
    uint public callsBurden;
    uint public callsDebtOf;
    uint public callsFile;

    struct Fee {
        uint debt;
        uint chi;
        uint speed;
        uint48 rho;
    }

    uint public loanDebtReturn; function setLoanDebtReturn(uint loanDebtReturn_) public {loanDebtReturn=loanDebtReturn_;}
    uint public burdenReturn; function setBurdenReturn(uint burdenReturn_) public {burdenReturn=burdenReturn_;}
    uint public totalDebtReturn; function setTotalDebtReturn(uint totalDebtReturn_) public {totalDebtReturn=totalDebtReturn_;} 
    Fee public feeReturn; function setFeeReturn(uint debt, uint chi, uint speed, uint48 rho) public {feeReturn = Fee(debt, chi, speed, rho);}

    address public usr;
    uint public loan;
    uint public wad;
    uint public fee;
    uint public speed;

    function fees(uint loan) public view returns(uint, uint, uint, uint) {
        return (feeReturn.debt, feeReturn.chi, feeReturn.speed, feeReturn.rho);
    }

    function incLoanDebt(uint loan_, uint fee_, uint wad_) public {
       loan = loan_;
       fee = fee_;
       wad = wad_;
       callsIncLoanDebt++;
    }

    function decLoanDebt(uint loan_, uint fee_, uint wad_) public {
       loan = loan_;
       fee = fee_;
       wad = wad_;
       callsDecLoanDebt++;
    }

    function drip(uint fee_) public {
        fee = fee_;
        callsDrip++;
    }

    function burden(uint loan_, uint fee_) public returns (uint){
       return burdenReturn;
    }

    function debtOf(uint loan_, uint fee_) public returns (uint){
       return loanDebtReturn;
    }

    function totalDebt() public returns (uint){
        return totalDebtReturn;
    }

    function file(uint fee_, uint speed_) public {
        callsFile++;
        fee = fee_;
        speed = speed_;
    }

}
