pragma solidity >=0.5.12;

import "../../../test/mock/mock.sol";

contract TitleMock is Mock {
    function ownerOf(uint loan) public returns (address) {
        values_uint["ownerOf_loan"] = loan;
        calls["ownerOf"]++;
        return values_address_return["ownerOf"];
    }

    function issue(address usr) public returns (uint) {
        values_address["issue_usr"] = usr;
        return call("issue");
    }

    function close(uint loan) public {
        values_uint["close_loan"] = loan;
        calls["close"]++;
    }
}
