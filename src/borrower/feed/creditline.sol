// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./navfeed.sol";

contract CreditlineNAVFeed is NAVFeed {
    function init() public override {
        require(ceilingRatio(0) == 0, "already-initialized");
    }

    function ceiling(uint loan) public override view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        uint initialCeiling = rmul(nftValues(nftID_), ceilingRatio(risk(nftID_)));
        return safeSub(initialCeiling, pile.debt(loan));
    }
}
