// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import { Discounting } from "./discounting.sol";

interface PileLike {
    function changeRate(uint, uint) external;
}

interface FeedLike {
    function nftID(uint loan) public view returns (bytes32);
    function maturityDate(bytes32 nft_)     public view returns(uint)
}

contract writeoffWrapper is Auth {

    mapping(address => uint) public immutable writeoffRates;

    constructor() {
        rely(msg.sender);
    }
    
    function writeOff(uint loanID, address pile, address feed) public auth {
        PileLike pile = PileLike(pile);
        Feedlike feed = Feedlike(feed);
        uint nnow = uniqueDayTimestamp(block.timestamp);
        bytes32 nftID_ = feed.nftID(loan);
        uint maturityDate_ = feed.maturityDate(nftID_);
        
        require(maturityDate_ <= nnow, "loan isn't overdue yet.")

        pile.changeRate(loanID, writeoffRates[pile]);
    }

}