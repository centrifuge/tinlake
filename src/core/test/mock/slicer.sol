pragma solidity >=0.4.24;

contract SlicerMock {

    uint public callsGetPayout;
    uint public callsGetSlice;

    uint public tokenAmount;
    uint public currencyAmount;

    uint public slicetReturn; function setTokenBalanceReturn(uint tokenAmount_) public {slicetReturn=tokenAmount_;}
    uint public payoutReturn; function setPayoutReturn(uint currencyAmount_) public {payoutReturn=currencyAmount_;}
    
    function getSlice(uint currencyAmount_) public returns(uint) {
        currencyAmount = currencyAmount_;
        callsGetSlice++;
        return slicetReturn;
    }

    function getPayout(uint tokenAmount_) public returns(uint) {
        tokenAmount = tokenAmount_;
        callsGetPayout++;
        return payoutReturn;
    }
}
