pragma solidity >=0.4.24;

contract TitleMock {

    // calls
    uint public issueCalls;

    // returns
    uint public issueReturn; function setIssueReturn(uint issueReturn_) public {issueReturn = issueReturn_;}
    address public ownerOfReturn; function setOwnerOfReturn(address ownerOfReturn_) public {ownerOfReturn=ownerOfReturn_;}

    function ownerOf(uint loan) public returns (address) {
    return ownerOfReturn;
    }

    function issue (address usr) public  returns (uint) {
        issueCalls++;
        return issueReturn;
    }

}
