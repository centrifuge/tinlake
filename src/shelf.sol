// Copyright (C) 2019 lucasvo

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

pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;

contract AppraiserLike {
    function appraise(uint, address, uint) public returns (uint);
}

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract PileLike {
    struct Loan {
        uint debt;
        uint balance;
        uint fee;
        uint chi;
    }
    function loans(uint) public returns (Loan memory);
    function borrow(uint, uint) public;
}


contract Shelf {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike                  public pile;
    AppraiserLike             public appraiser;

    struct Loan {
        address registry;
        uint256 tokenId;
        uint price; //
        uint principal; //
    }

    mapping (uint => Loan) public shelf;

    uint public bags; // sum of all prices

    constructor(address pile_, address appraiser_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        appraiser = AppraiserLike(appraiser_);
    }
    
    // --- Shelf ---
    function file(uint loan, address registry_, uint nft_) public auth {
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = nft_;
    }
    
    function file(uint loan, address registry_, uint nft_, uint principal_) public auth {
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = nft_;
        shelf[loan].principal = principal_;
    }

    function file(uint loan, uint principal_) public auth {
        shelf[loan].principal = principal_;
    }

    // Move the NFT out of the shelf. To be used by Collector contract.
    function move(address registry_, uint nft_, address to) public auth {
        NFTLike(registry_).transferFrom(address(this), to, nft_);
    }
    
    function release (uint loan, address usr) public auth {
        require(pile.loans(loan).debt == 0, "debt");
        move(shelf[loan].registry, shelf[loan].tokenId, usr);
        adjust(loan);
    }

    function deposit (uint loan, address usr) public auth {
        NFTLike(shelf[loan].registry).transferFrom(usr, address(this), shelf[loan].tokenId);
        pile.borrow(loan, shelf[loan].principal);
        shelf[loan].principal = 0;
        adjust(loan);
    }
    
    // Value collateral and update the total value of the shelf
    // Anyone can call this method to force the shelf to adjust the shelf total value (bags).
    function adjust (uint loan) public {
        uint appraisal = 0;
        if (NFTLike(shelf[loan].registry).ownerOf(shelf[loan].tokenId) == address(this)) {
            appraisal  = appraiser.appraise(loan, shelf[loan].registry, shelf[loan].tokenId);
        }
        if (appraisal < shelf[loan].price) {
            bags -= (shelf[loan].price - appraisal);
        } else {
            bags += (appraisal - shelf[loan].price);
        }
        shelf[loan].price = appraisal;
    }
}
