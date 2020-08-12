pragma solidity >=0.5.15 <0.6.0;

import "../../../test/mock/mock.sol";
import "../../../test/simple/token.sol";

contract ShelfMock is Mock {

    function shelf(uint loan) public returns (address, uint)  {
        values_uint["shelf_loan"] = loan;
        calls["shelf"]++;
        return (values_address_return["shelf"], values_return["shelf"]);
    }

    function token(uint loan) public returns (address, uint) {
        values_uint["token_loan"] = loan;
        calls["token"]++;
        return (values_address_return["token"], values_return["token"]);
    }

    function recover (uint loan, address usr, uint currencyAmount) public {
        values_uint["recover_loan"] = loan;
        values_address["recover_usr"] = usr;
        values_uint["recover_currencyAmount"] = currencyAmount;
        calls["recover"]++;
    }

    function lock(uint loan, address usr) public {
        values_uint["lock_loan"] = loan;
        values_address["lock_usr"] = usr;
        calls["lock"]++;
    }

    function unlock(uint loan, address usr) public {
        values_uint["unlock_loan"] = loan;
        values_address["unlock_usr"] = usr;
        calls["unlock"]++;
    }

    function claim(uint loan, address usr) public {
        values_uint["claim_loan"] = loan;
        values_address["claim_usr"] = usr;
        calls["claim"]++;
    }

    function file(uint loan, address registry, uint nft) public  {
        values_uint["file_loan"] = loan;
        values_address["file_registry"] = registry;
        values_uint["file_nft"] = nft;
        calls["file"]++;

    }

    function balanceRequest() public returns (bool, uint) {
        calls["balanceRequest"]++;
        return (values_bool_return["balanceRequest"], values_return["balanceRequest"]);
    }

    function doApprove(address currency_, address recepeint, uint amount) public {
        SimpleToken currency = SimpleToken(currency_);
        currency.approve(recepeint, amount);
    }
}
