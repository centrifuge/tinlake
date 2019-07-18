pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;

contract AdmitMock {

    //calls
    uint public callsAdmit;
    uint public callsUpdate;

    // returns
    uint public admitReturn; function setAdmitReturn(uint admitReturn_) public {admitReturn = admitReturn_;}

    address public registry;
    uint public nft;
    uint public principal;
    address public usr;
    uint public loan;

    // --- Admit ---
    function admit (address registry_, uint nft_, uint principal_, address usr_) public  returns (uint) {
        callsAdmit++;
        registry = registry_;
        nft = nft_;
        principal = principal_;
        usr = usr_;

        return admitReturn;
    }
    function update(uint loan_, address registry_, uint nft_, uint principal_) public  {
        callsUpdate++;
        loan = loan_;
        registry = registry_;
        nft = nft_;
        principal = principal_;
    }

    function update(uint loan_, uint principal_) public  {
        callsUpdate++;
        principal = principal_;

    }
}
