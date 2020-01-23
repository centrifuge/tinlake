// Copyright (C) 2019 Centrifuge

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

pragma solidity >=0.5.12;

import "ds-test/test.sol";
import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Borrower is DSTest {
    ERC20Like tkn;
    ShelfLike shelf;
    TDistributorLike distributor;
    PileLike pile;

    constructor (address shelf_, address distributor_, address tkn_, address pile_) public {
        shelf = ShelfLike(shelf_);
        distributor = TDistributorLike(distributor_);
        tkn = ERC20Like(tkn_);
        pile = PileLike(pile_);
    }

    function issue(address registry, uint nft) public returns (uint loan) {
        return shelf.issue(registry, nft);
    }

    function close(uint loan) public {
        shelf.close(loan);
    }

    function lock(uint loan) public {
        shelf.lock(loan);
    }

    function borrow(uint loan, uint currencyAmount) public {

        shelf.borrow(loan, currencyAmount);
    }

    function balance() public {
        distributor.balance();
    }

    function repay(uint loan, uint amount) public {
        shelf.repay(loan, amount);
    }

    function withdraw(uint loan, uint amount, address usr) public {
        shelf.withdraw(loan, amount, usr);
    }

    function borrowAction(uint loan, uint amount) public {
        shelf.lock(loan);
        shelf.borrow(loan, currencyAmount);
        distributor.balance();
        shelf.withdraw(loan, currencyAmount, address(this));
    }

    function approveNFT(Title nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }

    function repayAction(uint loan, uint wad, address usr) public {
        shelf.repay(loan, wad);
        shelf.unlock(loan);
        distributor.balance();
    }

    function doClose(uint loan) public {
        uint debt = pile.debt(loan);
        repayAction(loan, debt, usr);
    }

    function doApproveCurrency(address usr, uint currencyAmount) public {
        tkn.approve(usr, currencyAmount);
    }
}
