// shelf.sol -- keeps track and owns NFTs
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

import { Title, TitleOwned } from "tinlake-title/title.sol";
import { DebtLike, DebtRegister } from "./debt_register.sol";

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract PileLike {
    struct Loan {
        uint balance;
        uint rate;
    }
    function debtOf(uint) public returns (uint debt);
    function borrow(uint, uint) public;
}

contract Shelf is TitleOwned {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    PileLike public  pile;
    Title public     title;
    DebtLike public  debt;

    struct Loan {
        address registry;
        uint256 tokenId;
        uint price;
        uint principal;
        uint initial;
    }

    mapping (uint => Loan) public    shelf;
    mapping (bytes32 => uint) public nftlookup;

    uint public bags; // sum of all prices

    constructor(address pile_, address title_) TitleOwned(title_) public {
        wards[msg.sender] = 1;
        pile = PileLike(pile_);
        title = Title(title_);
    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "pile") { pile = PileLike(addr); }
        else revert();
    }

    // --- Shelf: Getters ---
    function token(uint loan) public view returns (address registry, uint nft) {
        return (shelf[loan].registry, shelf[loan].tokenId);
    }

    // --- Shelf: Creation and closing of a loan ---
    function issue(address registry, uint token) public returns (uint) {
        require(NFTLike(registry).ownerOf(token) == msg.sender, "nft-not-owned");

        bytes32 nft = keccak256(abi.encodePacked(registry, token));
        // Title.issue() never assigns the "0" token id.
        require(nftlookup[nft] == 0, "nft-in-use");

        uint loan = title.issue(msg.sender);
        nftlookup[nft] = loan;

        shelf[loan].registry = registry;
        shelf[loan].tokenId = token;

        return loan;
    }

    function close(uint loan) public owner(loan) {
        require(pile.debtOf(loan) == 0, "outstanding-debt"); // TODO: only allow closing of a loan that isn't active anymore. maybe there is a better criteria
        title.close(loan);
        bytes32 nft = keccak256(abi.encodePacked(shelf[loan].registry, shelf[loan].tokenId));
        nftlookup[nft] = 0;
    }

    // ---- Shelf ---
    function file(uint loan, address registry_, uint nft_, uint principal_) public auth {
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = nft_;
        shelf[loan].principal = principal_;
        shelf[loan].initial = principal_;
    }

    function file(uint loan, uint principal_) public auth {
        shelf[loan].principal = principal_;
        shelf[loan].initial = principal_;
    }

    function deposit(uint loan, address usr) public owner(loan) {
        NFTLike(shelf[loan].registry).transferFrom(usr, address(this), shelf[loan].tokenId);
        pile.borrow(loan, shelf[loan].principal);
        shelf[loan].principal = 0;
    }

    // --- Currency actions ---
    function borrow(uint loan, uint wad) public owner(loan) {
        debt.accrue(loan);
        // principal.borrow(loan, wad); TODO: reentrancy
        debt.inc(loan, wad);
    }

    function repay(uint loan, uint wad) public owner(loan) {
        debt.accrue(loan);
        // principal.repay(loan, wad); TODO: reentrancy
        debt.dec(loan, wad);
    }

    // --- NFT actions ---
    function lock(uint loan) public owner(loan) {
        NFTLike(shelf[loan].registry).transferFrom(msg.sender, address(this), shelf[loan].tokenId);
    }

    function unlock(uint loan) public owner(loan) {
        require(pile.debtOf(loan) == 0, "has-debt");
        NFTLike(shelf[loan].registry).transferFrom(address(this), msg.sender, shelf[loan].tokenId);
    }

    // Used by the collector
    function claim(uint loan, address usr) public auth {
        // TODO: need to update pile/shelf to let it know it's gone.
        NFTLike(shelf[loan].registry).transferFrom(address(this), usr, shelf[loan].tokenId);
    }
}
