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

import "ds-note/note.sol";
import { Title, TitleOwned } from "tinlake-title/title.sol";
import { DebtLike } from "./debt_register.sol";

contract NFTLike {
    function ownerOf(uint256 tokenId) public view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) public;
}

contract TokenLike{
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
    function approve(address, uint) public;
}

contract CeilingLike {
    function borrow(uint loan, uint currencyAmount) public;
}

contract Shelf is DSNote, TitleOwned {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    function deny(address usr) public auth { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    Title public title;
    CeilingLike public ceiling;
    DebtLike public debt;
    TokenLike public tkn;

    struct Loan {
        address registry;
        uint256 tokenId;
    }
    
    mapping (uint => uint) public balances;
    mapping (uint => Loan) public shelf;
    mapping (bytes32 => uint) public nftlookup;
    uint public Balance;
    address public lender;

    constructor(address tkn_, address title_, address debt_, address ceiling_) TitleOwned(title_) public {
        wards[msg.sender] = 1;
        tkn = new TokenLike(tkn_);
        title = Title(title_);
        debt = DebtLike(addr);
        ceiling = CeilingLike(ceiling_);

    }

    function depend (bytes32 what, address addr) public auth {
        if (what == "lender") { lender = addr; }
        else revert();
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function file(uint loan, address registry_, uint nft_) public auth {
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = nft_;
    }

    function token(uint loan) public view returns (address registry, uint nft) {
        return (shelf[loan].registry, shelf[loan].tokenId);
    }

    // --- Shelf: Loan actions ---
    function issue(address registry, uint token) public returns (uint) {
        require(NFTLike(registry).ownerOf(token) == msg.sender, "nft-not-owned");

        bytes32 nft = keccak256(abi.encodePacked(registry, token));
        require(nftlookup[nft] == 0, "nft-in-use");

        uint loan = title.issue(msg.sender);
        nftlookup[nft] = loan;

        shelf[loan].registry = registry;
        shelf[loan].tokenId = token;

        return loan;
    }

/*
    function close(uint loan) public owner(loan) {
        require(debt.debt(loan) == 0, "outstanding-debt"); // TODO: only allow closing of a loan that isn't active anymore. maybe there is a better criteria
        title.close(loan);
        bytes32 nft = keccak256(abi.encodePacked(shelf[loan].registry, shelf[loan].tokenId));
        nftlookup[nft] = 0;
    }
    */

    // --- Currency actions ---
    function want() public view returns (int) {
        return int(Balance) - int(tkn.balanceOf(address(this))); // safemath
    }

    function borrow(uint loan, uint wad) public owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        principal.borrow(loan, wad);
        debt.accrue(loan);
        debt.increase(loan, wad);
        balances[loan] = add(balances[loan], wad);
        Balance += wad;
    }

    function withdraw(uint loan, uint wad, address usr) public owner(loan) note {
        require(nftLocked(loan), "nft-not-locked");
        require(wad <= balances[loan], "amount-too-high");
        balances[loan] -= wad;
        Balance -= wad;
        tkn.transferFrom(address(this), usr, wad);
    }

    function repay(uint loan, uint wad) public owner(loan) note {
        require(nftLocked(loan), "nft-not-locked");
        require(balances[loan] == 0,"before repay loan needs to be withdrawn");
        doRepay(loan, msg.sender, wad);
    }

    function recover(uint loan, address usr, uint wad) public auth {
        doRepay(loan, usr, wad);
        uint loss = debt.debt(loan);
        debt.decrease(loan, loss);
    }

    function doRepay(uint loan, address usr, uint wad) internal {
        debt.accrue(loan);
        uint loanDebt = debt.debt(loan);

        // only repay max loan debt
        if (wad > loanDebt) {
            wad = loanDebt;
        }

        tkn.transferFrom(usr, address(this), wad);
        debt.decrease(loan, wad);
        tkn.approve(lender, wad);
    }

    function balanceOf(uint loan) public view returns (uint) {
        return balances[loan];
    }

    // --- NFT actions ---
    // deposit = lock
    function lock(uint loan, address usr) public owner(loan) {
        NFTLike(shelf[loan].registry).transferFrom(usr, address(this), shelf[loan].tokenId);
    }
 
    function unlock(uint loan) public owner(loan) {
        require(debt.debt(loan) == 0, "has-debt");
        NFTLike(shelf[loan].registry).transferFrom(address(this), msg.sender, shelf[loan].tokenId);
    }

    function nftLocked(uint loan) internal returns (bool) {
        return NFTLike(shelf[loan].registry).ownerOf(shelf[loan].tokenId) == address(this);
    }

    // Used by the collector
    function claim(uint loan, address usr) public auth {
        // TODO: need to update pile/shelf to let it know it's gone.
        NFTLike(shelf[loan].registry).transferFrom(address(this), usr, shelf[loan].tokenId);
    }
}
