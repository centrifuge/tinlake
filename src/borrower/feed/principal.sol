// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "./navfeed.sol";

contract PrincipalNAVFeed is NAVFeed {

    // function init() public override {
    //     require(ceilingRatio(0) == 0, "already-initialized");
    // }

    // returns the ceiling of a loan
    // the ceiling defines the maximum amount which can be borrowed
    function ceiling(uint loan) public override view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        uint initialCeiling = rmul(nftValues(nftID_), ceilingRatio(risk(nftID_)));

        if (borrowed(loan) > initialCeiling) {
            return 0;
        }

        return safeSub(initialCeiling, borrowed(loan));
    }

}
