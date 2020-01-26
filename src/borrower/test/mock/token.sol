pragma solidity >=0.5.12;


import "../../../test/mock/mock.sol";

contract TokenMock is Mock {
    function balanceOf(address usr) public returns (uint) {
        values_address["balanceOf_usr"] = usr;
        return call("balanceOf");
    }
    
    function mint(address usr, uint amount) public {
        calls["mint"]++;
        values_address["mint_usr"] = usr;
        values_uint["mint_amount"] = amount;
    }

    function transferFrom(address from ,address to, uint amount) public {
        calls["transferFrom"]++;
        values_address["transferFrom_from"] = from;
        values_address["transferFrom_to"] = to;
        values_uint["transferFrom_amount"] = amount;
    }
    function burn(address usr, uint amount) public {
        calls["burn"]++;
        values_address["burn_usr"] = usr;
        values_uint["burn_amount"] = amount;
    }

    function approve(address usr, uint amount) public returns (bool) {
        calls["approve"]++;
        values_address["approve_usr"] = usr;
        values_uint["approve_amount"] = amount;
        return values_bool_return["approve"];
    }
}
