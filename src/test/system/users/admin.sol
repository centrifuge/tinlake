// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract AdminUser {
    // --- Data ---
    ShelfLike shelf;
    PileLike pile;
    Title title;
    TReserveLike reserve;
    NAVFeedLike nftFeed;
    MemberlistLike juniorMemberlist;
    MemberlistLike seniorMemberlist;

    constructor(address shelf_, address pile_, address navFeed_, address title_, address reserve_, address juniorMemberlist_, address seniorMemberlist_) {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        title = Title(title_);
        reserve = TReserveLike(reserve_);
        nftFeed = NAVFeedLike(navFeed_);
        juniorMemberlist = MemberlistLike(juniorMemberlist_);
        seniorMemberlist = MemberlistLike(seniorMemberlist_);
    }

    function priceNFT(bytes32 lookupId, uint nftPrice) public {
        nftFeed.update(lookupId, nftPrice);
    }

    function priceNFTAndSetRiskGroup(bytes32 lookupId, uint nftPrice, uint riskGroup, uint maturityDate) public {
        nftFeed.update(lookupId, nftPrice, riskGroup);
        // add default maturity date
        nftFeed.file("maturityDate", lookupId , maturityDate);
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
}
