// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2018  Rain <rainbreak@riseup.net>, Centrifuge
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import {Discounting} from "../feed/discounting.sol";

struct Loan {
    address registry;
    uint256 tokenId;
}

interface ShelfLike {
    function shelf(uint256) external view returns (Loan memory);
}

interface PileLike {
    function changeRate(uint256, uint256) external;
}

interface FeedLike {
    function pile() external view returns (address);
    function shelf() external view returns (address);
    function nftID(uint256 loan) external view returns (bytes32);
    function maturityDate(bytes32 nft_) external view returns (uint256);
}

/// @notice WriteOff contract can move overdue loans into a write off group
/// The wrapper contract manages multiple different pools
contract WriteOffWrapper is Auth, Discounting {
    mapping(address => uint256) public writeOffRates;

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        writeOffRates[address(0x05739C677286d38CcBF0FfC8f9cdbD45904B47Fd)] = 1000; // Bling Series 1
        writeOffRates[address(0xAAEaCfcCc3d3249f125Ba0644495560309C266cB)] = 1001; // Pezesha 1
        writeOffRates[address(0x9E39e0130558cd9A01C1e3c7b2c3803baCb59616)] = 1001; // GIG Pool
        writeOffRates[address(0x11C14AAa42e361Cf3500C9C46f34171856e3f657)] = 1000; // Fortunafi 1
        writeOffRates[address(0xE7876f282bdF0f62e5fdb2C63b8b89c10538dF32)] = 1000; // Harbor Trade 2
        writeOffRates[address(0x3eC5c16E7f2C6A80E31997C68D8Fa6ACe089807f)] = 1000; // New Silver 2
        writeOffRates[address(0xe17F3c35C18b2Af84ceE2eDed673c6A08A671695)] = 1001; // Branch Series 3
        writeOffRates[address(0x99D0333f97432fdEfA25B7634520d505e58B131B)] = 1000; // FactorChain 1
        writeOffRates[address(0x37c8B836eA1b89b7cC4cFdDed4C4fbC454CcC679)] = 1000; // Paperchain 3
        writeOffRates[address(0xB7d1DE24c0243e6A3eC4De9fAB2B19AB46Fa941F)] = 1001; // UP Series 1
        writeOffRates[address(0x3fC72dA5545E2AB6202D81fbEb1C8273Be95068C)] = 1000; // ConsolFreight 4
        writeOffRates[address(0xdB07B21109117208a0317adfbed484C87c9c2aFf)] = 1000; // databased.FINANCE 1
        writeOffRates[address(0x4b0f712Aa9F91359f48D8628De8483B04530751a)] = 1001; // Peoples 1
    }

    /// @notice writes off an overdue loan
    /// @param loan the loan id
    /// @param navFeed address of the feed
    /// @param pile address of the pile
    /// @param shelf address of the shelf
    function writeOff(uint256 loan, address navFeed, address pile, address shelf) public auth {
        FeedLike feed = FeedLike(navFeed);
        PileLike pile = PileLike(pile);
        require(writeOffRates[address(pile)] != 0, "WriteOffWrapper/pile-has-no-write-off-group");
        ShelfLike shelf = ShelfLike(shelf);
        require(shelf.shelf(loan).tokenId != 0, "WriteOffWrapper/loan-does-not-exist");
        uint256 nnow = uniqueDayTimestamp(block.timestamp);
        bytes32 nftID = feed.nftID(loan);
        uint256 maturityDate = feed.maturityDate(nftID);

        require(maturityDate < nnow, "WriteOffWrapper/loan-not-overdue");

        pile.changeRate(loan, writeOffRates[address(pile)]);
    }

    function file(bytes32 what, address addr, uint256 data) public auth {
        if (what == "writeOffRates") {
            writeOffRates[addr] = data;
        }
    }
}
