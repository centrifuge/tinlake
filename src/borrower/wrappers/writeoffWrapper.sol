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

contract WriteoffWrapper is Auth, Discounting {

    mapping(address => uint) public writeoffRates;

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        writeoffRates[address(0x09e43329552c9D81cF205Fd5f44796fBC40c822e)] = 0;  // REIF Pool ?? https://centrifuge.hackmd.io/31xg2b6jTLWzJdFvOngq0g?view
        writeoffRates[address(0x0CED6166873038Ac0cc688e7E6d19E2cBE251Bf0)] = 1000;  // Bling Series 1
        writeoffRates[address(0x235893Bf9695F68a922daC055598401D832b538b)] = 1001;  // Pezesha 1
        writeoffRates[address(0x3170D353772eD68676044f8b76F0641B2cbA084E)] = 0;  // Fortunafi 2  ?? https://centrifuge.hackmd.io/4vTa41y6QFmA3x-OogkenQ
        writeoffRates[address(0x3B03863BD553C4CE07eABF2278016533451c9101)] = 0;  // Cauris Global Fintech 1 ?? https://centrifuge.hackmd.io/2Vxnf3VmRU6lveB3xnrmFQ
        writeoffRates[address(0x3d167bd08f762FD391694c67B5e6aF0868c45538)] = 1001;  // GIG Pool
        writeoffRates[address(0x4B6CA198d257D755A5275648D471FE09931b764A)] = 1000;  // Fortunafi 1
        writeoffRates[address(0x4cA805cE8EcE2E63FfC1F9f8F2731D3F48DF89Df)] = 1000;  // Harbor Trade 2
        writeoffRates[address(0x53b2d22d07E069a3b132BfeaaD275b10273d381E)] = 1000;  // New Silver 2
        writeoffRates[address(0x560Ac248ce28972083B718778EEb0dbC2DE55740)] = 1001;  // Branch Series 3
        writeoffRates[address(0x714D520CfAC2027834c8Af8ffc901855c3aD41Ec)] = 1000;  // FactorChain 1
        writeoffRates[address(0x82B8617A16e388256617FeBBa1826093401a3fE5)] = 1000;  // Paperchain 3
        writeoffRates[address(0x92332a9831AC04275bC0f22b9140b21c72984EB8)] = 1001;  // Pezesha 1
        writeoffRates[address(0x9De3064f49696a25066252C35ede68850EA33BF8)] = 1001;  // UP Series 1
        writeoffRates[address(0xdB3bC9fB1893222d266762e9fF857EB74D75c7D6)] = 1001;  // ConsolFreight 4
        writeoffRates[address(0xF96F18F2c70b57Ec864cC0C8b828450b82Ff63e3)] = 0;  // ALT 1.0  ?? https://centrifuge.hackmd.io/FBFX0lldR9iFSZexHtCLuQ
        writeoffRates[address(0xfc2950dD337ca8496C18dfc0256Fb905A7E7E5c6)] = 1000;  // databased.FINANCE 1
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