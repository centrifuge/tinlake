// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
pragma solidity >=0.7.6;

import "tinlake-auth/auth.sol";
import { Discounting } from "../feed/discounting.sol";

interface PileLike {
    function changeRate(uint, uint) external;
}

interface FeedLike {
    function nftID(uint loan) external view returns (bytes32);
    function maturityDate(bytes32 nft_) external view returns(uint);
}

contract writeoffWrapper is Auth, Discounting {

    mapping(address => uint) public writeoffRates;

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }
    
    function writeOff(uint _loanID, address _pile, address _feed) public auth {
        PileLike pile = PileLike(_pile);
        FeedLike feed = FeedLike(_feed);
        uint nnow = uniqueDayTimestamp(block.timestamp);
        bytes32 nftID = feed.nftID(_loanID);
        uint maturityDate = feed.maturityDate(nftID);
        
        require(maturityDate <= nnow, "loan isn't overdue yet.");

        pile.changeRate(_loanID, writeoffRates[address(pile)]);
    }

}