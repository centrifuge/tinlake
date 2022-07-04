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

        writeoffRates[address(0xc2a75288cf644b068fC1e765586c170f2529a87F)] = 0;  // REIF Pool ?? https://centrifuge.hackmd.io/31xg2b6jTLWzJdFvOngq0g?view
        writeoffRates[address(0x05739C677286d38CcBF0FfC8f9cdbD45904B47Fd)] = 1000;  // Bling Series 1
        writeoffRates[address(0xAAEaCfcCc3d3249f125Ba0644495560309C266cB)] = 1001;  // Pezesha 1
        writeoffRates[address(0x2bD53Bd2341329e0cf36c55380A77a3E457028Ca)] = 0;  // Fortunafi 2  ?? https://centrifuge.hackmd.io/4vTa41y6QFmA3x-OogkenQ
        writeoffRates[address(0x696866ea53C0f521C24a28D92fAbD2c559182D38)] = 0;  // Cauris Global Fintech 1 ?? https://centrifuge.hackmd.io/2Vxnf3VmRU6lveB3xnrmFQ
        writeoffRates[address(0x9E39e0130558cd9A01C1e3c7b2c3803baCb59616)] = 1001;  // GIG Pool
        writeoffRates[address(0x11C14AAa42e361Cf3500C9C46f34171856e3f657)] = 1000;  // Fortunafi 1
        writeoffRates[address(0xE7876f282bdF0f62e5fdb2C63b8b89c10538dF32)] = 1000;  // Harbor Trade 2
        writeoffRates[address(0x3eC5c16E7f2C6A80E31997C68D8Fa6ACe089807f)] = 1000;  // New Silver 2
        writeoffRates[address(0xe17F3c35C18b2Af84ceE2eDed673c6A08A671695)] = 1001;  // Branch Series 3
        writeoffRates[address(0x0168e7999318a6c2393c2Eb19A5Da4aB9d715173)] = 1000;  // FactorChain 1
        writeoffRates[address(0x37c8B836eA1b89b7cC4cFdDed4C4fbC454CcC679)] = 1000;  // Paperchain 3
        writeoffRates[address(0xAAEaCfcCc3d3249f125Ba0644495560309C266cB)] = 1001;  // Pezesha 1
        writeoffRates[address(0xB7d1DE24c0243e6A3eC4De9fAB2B19AB46Fa941F)] = 1001;  // UP Series 1
        writeoffRates[address(0x3fC72dA5545E2AB6202D81fbEb1C8273Be95068C)] = 1001;  // ConsolFreight 4
        writeoffRates[address(0xE18AAB16cC26EB23740D72875e0C6b52cEbb46b3)] = 0;  // ALT 1.0  ?? https://centrifuge.hackmd.io/FBFX0lldR9iFSZexHtCLuQ
        writeoffRates[address(0xdB07B21109117208a0317adfbed484C87c9c2aFf)] = 1000;  // databased.FINANCE 1
    }
    
    function writeOff(uint _loanID, address _pile, address _feed) public auth {
        PileLike pile = PileLike(_pile);
        FeedLike feed = FeedLike(_feed);
        uint nnow = uniqueDayTimestamp(block.timestamp);
        bytes32 nftID = feed.nftID(_loanID);
        uint maturityDate = feed.maturityDate(nftID);
        
        require(maturityDate <= nnow, "loan isn't overdue yet.");

        pile.changeRate(_loanID, writeoffRates[_pile]);
    }

}