// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import "forge-std/Test.sol";

import "test/mock/mock.sol";
import "./vat.sol";
import {GemJoin} from "./gemJoin.sol";
import {Urn} from "./urn.sol";

contract ManagerMock is Mock {

    SimpleTokenLike currency;
    SimpleTokenLike collateral;
    VatMock vat;

    address public operator;

    GemJoin public gemJoin;
    Urn public urn;

    modifier ownerOnly {
        require(msg.sender == operator, "TinlakeMgr/owner-only");
        _;
    }

    constructor(address currency_, address collateral_) {
        operator = msg.sender;
        currency = SimpleTokenLike(currency_);
        collateral = SimpleTokenLike(collateral_);
        gemJoin = new GemJoin();
        urn = new Urn();
        urn.setReturn("gemJoin", address(gemJoin));
    }

    function setVat(address vat_) external {
        vat = VatMock(vat_);
    }

    function ilk() public view returns (bytes32) {
        return values_bytes32_return["ilk"];
    }

    function join(uint amountDROP) external {
        // mimic cdp behav and transfer DROP from clerk to mgr
        collateral.transferFrom(msg.sender, address(this), amountDROP);
    }

    function draw(uint amountDAI) external  {
        // mimic cdp behav and mint DAI to clerk
        currency.mint(msg.sender, amountDAI);
        vat.increaseTab(amountDAI);

    }

    function wipe(uint amountDAI) external {
        // mimic cdp behav: move DAI from clerk to mgr
        currency.transferFrom(msg.sender, address(this), amountDAI);
        vat.decreaseTab(amountDAI);
    }

    function safe() external view returns(bool) {
        return values_bool_return["safe"];
    }

    function glad() external view returns(bool) {
        return values_bool_return["glad"];
    }

    function live() external view returns(bool) {
        return values_bool_return["live"];
    }

    function exit(uint amountDROP) external {
       collateral.transferFrom(address(this), msg.sender, amountDROP);
    }

    // --- Administration ---
    function setOperator(address newOperator) external ownerOnly {
        operator = newOperator;
    }

    function setIlk(bytes32 ilk_) external {
        gemJoin.setBytes32Return("ilk", ilk_);
    }
    function file(bytes32 what, address addr) external {
        values_bytes32["file"] = what;
        values_address["address"] = addr;
        if(what == "owner") {
        values_address_return["owner"] = addr;
        }
    }

    function owner() public view returns(address) {
        return values_address_return["owner"];
    }
}
