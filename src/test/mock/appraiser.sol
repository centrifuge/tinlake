pragma solidity >=0.4.24;

contract AppraiserMock {
    mapping (uint => uint) public appraisal;
    function setMockAppraisal(uint loan, uint wad) public {
    appraisal[loan] = wad;
    }
    function appraise (uint loan) public returns (uint) {
        return  appraisal[loan];
    }
}
