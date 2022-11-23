// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "./navfeed.sol";

/// @notice CreditlineNAVFeed contract ceiling is based on collateral value
contract CreditlineNAVFeed is NAVFeed {
    /// @notice returns the ceiling (max borrow amount) for a loan
    /// @param loan the loan id
    function ceiling(uint256 loan) public view override returns (uint256) {
        bytes32 nftID_ = nftID(loan);
        uint256 initialCeiling = rmul(nftValues(nftID_), ceilingRatio(risk(nftID_)));
        return safeSub(initialCeiling, pile.debt(loan));
    }
}
