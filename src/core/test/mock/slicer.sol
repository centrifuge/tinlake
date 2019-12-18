pragma solidity >=0.4.24;

contract SlicerMock {

    uint public callsupdateSupplyRate;
    uint public callsDrip;
    uint public callsCalcPayout;
    uint public callsCalcSlice;
    uint public callsFile;

    uint public borrowSpeed;
    uint public speed;
    uint public debt;
    uint public reserve;
    uint public tokenAmount;
    uint public currencyAmount;

    uint public calcSliceReturn; function setCalcSliceReturn(uint tokenAmount_) public {calcSliceReturn=tokenAmount_;}
    uint public calcPayoutReturn; function setCalcPayoutReturn(uint currencyAmount_) public {calcPayoutReturn=currencyAmount_;}
    
    function file(bytes32 what, uint speed_) public {
        speed = speed_;
        callsFile++;
    }

    function updateSupplyRate(uint borrowSpeed_, uint debt_, uint reserve_) public { 
        borrowSpeed = borrowSpeed_;
        debt = debt_;
        reserve = reserve_;
        callsupdateSupplyRate++;
    }

    function drip() public {
        callsDrip++;
    }

    function calcSlice(uint currencyAmount_) public returns(uint) {
        currencyAmount = currencyAmount_;
        callsCalcSlice++;
        return calcSliceReturn;
    }

    function calcPayout(uint tokenAmount_) public returns(uint) {
        tokenAmount = tokenAmount_;
        callsCalcPayout++;
        return calcPayoutReturn;
    }
}
