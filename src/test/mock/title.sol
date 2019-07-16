pragma solidity >=0.4.24;

contract TitleMock {

    // calls
    uint public issueCalls;

    address public usr;

    // returns
    uint public issueReturn; function setIssueReturn(uint issueReturn_) public {issueReturn = issueReturn_;}
    address public ownerOfReturn; function setOwnerOfReturn(address ownerOfReturn_) public {ownerOfReturn=ownerOfReturn_;}

    function ownerOf(uint loan) public returns (address) {
    return ownerOfReturn;
    }

    function issue (address usr_) public  returns (uint) {
        issueCalls++;
        usr = usr_;
        return issueReturn;
    }
}
