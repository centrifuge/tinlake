// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.5.15 <0.6.0;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";
import "ds-test/test.sol";

interface AdminOperatorLike {
    function relyInvestor(address usr) external;
}

contract AdminUser is DSTest {
    // --- Data ---
    ShelfLike shelf;
    PileLike pile;
    Title title;
    TDistributorLike distributor;
    CollectorLike collector;
    NFTFeedLike nftFeed;
    MemberlistLike juniorMemberlist;
    MemberlistLike seniorMemberlist;

    constructor(address shelf_, address pile_, address nftFeed_, address title_, address distributor_, address collector_, address juniorMemberlist_, address seniorMemberlist_) public {
        shelf = ShelfLike(shelf_);
        pile = PileLike(pile_);
        title = Title(title_);
        distributor = TDistributorLike(distributor_);
        collector = CollectorLike(collector_);
        nftFeed = NFTFeedLike(nftFeed_);
        juniorMemberlist = MemberlistLike(juniorMemberlist_);
        seniorMemberlist = MemberlistLike(seniorMemberlist_);
    }

    function priceNFT(bytes32 lookupId, uint nftPrice) public {
        nftFeed.update(lookupId, nftPrice);
    }

    function priceNFTAndSetRiskGroup(bytes32 lookupId, uint nftPrice, uint riskGroup) public {
        nftFeed.update(lookupId, nftPrice, riskGroup);
        // add default maturity date
        nftFeed.file("maturityDate", lookupId , now + 600 days);
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

    function makeJuniorTokenMember(address usr) public {
        juniorMemberlist.addMember(usr);
    }

    function makeSeniorTokenMember(address usr) public {
        emit log_named_uint("admin", 1);
        seniorMemberlist.addMember(usr);
    }

}
