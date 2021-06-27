// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract AdminUser {
    // --- Data ---
    ShelfLike shelf;
    PileLike pile;
    Title title;
    TReserveLike reserve;
    CollectorLike collector;
    NFTFeedLike nftFeed;
    MemberlistLike juniorMemberlist;
    MemberlistLike seniorMemberlist;
    TrancheLike juniorTranche;

    constructor(address shelf_, address pile_, address nftFeed_, address title_, address reserve_, address collector_, address juniorMemberlist_, address seniorMemberlist_, address juniorTranche_) {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        title = Title(title_);
        reserve = TReserveLike(reserve_);
        collector = CollectorLike(collector_);
        nftFeed = NFTFeedLike(nftFeed_);
        juniorMemberlist = MemberlistLike(juniorMemberlist_);
        seniorMemberlist = MemberlistLike(seniorMemberlist_);
        juniorTranche = TrancheLike(juniorTranche_);
    }

    function priceNFT(bytes32 lookupId, uint nftPrice) public {
        nftFeed.update(lookupId, nftPrice);
    }

    function priceNFTAndSetRiskGroup(bytes32 lookupId, uint nftPrice, uint riskGroup, uint maturityDate) public {
        nftFeed.update(lookupId, nftPrice, riskGroup);
        // add default maturity date
        nftFeed.file("maturityDate", lookupId , maturityDate);
    }

    function setCollectPrice(uint loan, uint price) public {
        collector.file("loan", loan, address(0), price);
    }

    function addKeeper(uint loan, address usr, uint price) public {
        collector.file("loan", loan, usr, price);
    }

    function whitelistKeeper(address usr) public {
        collector.relyCollector(usr);
    }

    function collect(uint loan, address usr) public {
        collector.collect(loan, usr);
    }

    function makeJuniorTokenMember(address usr, uint validitUntil) public {
        juniorMemberlist.updateMember(usr, validitUntil);
    }

    function makeSeniorTokenMember(address usr, uint validitUntil) public {
        seniorMemberlist.updateMember(usr, validitUntil);
    }

    function fileFixedRate(uint rateGroup, uint rate) public {
        pile.file("fixedRate", rateGroup, rate);
    }

    function relyNftFeed(address addr) public {
        nftFeed.rely(addr);
    }

    function relyJuniorTranche(address addr) public {
        juniorTranche.rely(addr);
    }
}
