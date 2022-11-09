// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";
import "../../../test/simple/token.sol";

contract ShelfMock is Mock {
    function shelf(uint256) public view returns (address, uint256) {
        return (values_address_return["shelf"], values_return["shelf"]);
    }

    function nftlookup(bytes32 nftID) public returns (uint256 loan) {
        values_bytes32[nftID] = nftID;
        return values_return["nftlookup"];
    }

    function token(uint256 loan) public returns (address, uint256) {
        values_uint["token_loan"] = loan;
        calls["token"]++;
        return (values_address_return["token"], values_return["token"]);
    }

    function recover(uint256 loan, address usr, uint256 currencyAmount) public {
        values_uint["recover_loan"] = loan;
        values_address["recover_usr"] = usr;
        values_uint["recover_currencyAmount"] = currencyAmount;
        calls["recover"]++;
    }

    function lock(uint256 loan, address usr) public {
        values_uint["lock_loan"] = loan;
        values_address["lock_usr"] = usr;
        calls["lock"]++;
    }

    function unlock(uint256 loan, address usr) public {
        values_uint["unlock_loan"] = loan;
        values_address["unlock_usr"] = usr;
        calls["unlock"]++;
    }

    function claim(uint256 loan, address usr) public {
        values_uint["claim_loan"] = loan;
        values_address["claim_usr"] = usr;
        calls["claim"]++;
    }

    function file(uint256 loan, address registry, uint256 nft) public {
        values_uint["file_loan"] = loan;
        values_address["file_registry"] = registry;
        values_uint["file_nft"] = nft;
        calls["file"]++;
    }

    function balanceRequest() public returns (bool, uint256) {
        calls["balanceRequest"]++;
        return (values_bool_return["balanceRequest"], values_return["balanceRequest"]);
    }

    function doApprove(address currency_, address recepeint, uint256 amount) public {
        SimpleToken currency = SimpleToken(currency_);
        currency.approve(recepeint, amount);
    }

    function loanCount() public view returns (uint256) {
        return values_return["loanCount"];
    }
}
