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
    NAVFeedLike navFeed;
    MemberlistLike juniorMemberlist;
    MemberlistLike seniorMemberlist;
    TrancheLike juniorTranche;
    ERC20Like juniorToken;

    constructor(address shelf_, address pile_, address navFeed_, address title_, address reserve_, address collector_, address juniorMemberlist_, address seniorMemberlist_, address juniorTranche_, address juniorToken_) {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        title = Title(title_);
        reserve = TReserveLike(reserve_);
        collector = CollectorLike(collector_);
        navFeed = NAVFeedLike(navFeed_);
        juniorMemberlist = MemberlistLike(juniorMemberlist_);
        seniorMemberlist = MemberlistLike(seniorMemberlist_);
        juniorTranche = TrancheLike(juniorTranche_);
        juniorToken = ERC20Like(juniorToken_);
    }

    function priceNFT(bytes32 lookupId, uint nftPrice) public {
        navFeed.update(lookupId, nftPrice);
    }

    function setMaturityDate(address collateralNFT_, uint tokenId, uint maturityDate) public {
        bytes32 lookupId = keccak256(abi.encodePacked(collateralNFT_, tokenId));
        navFeed.file("maturityDate", lookupId , maturityDate);
    }

    function priceNFTAndSetRiskGroup(bytes32 lookupId, uint nftPrice, uint riskGroup, uint maturityDate) public {
        navFeed.update(lookupId, nftPrice, riskGroup);
        // add default maturity date
        navFeed.file("maturityDate", lookupId , maturityDate);
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
        navFeed.rely(addr);
    }

    function relyJuniorTranche(address addr) public {
        juniorTranche.rely(addr);
    }

    function relyJuniorToken(address addr) public {
        juniorToken.rely(addr);
    }
}
