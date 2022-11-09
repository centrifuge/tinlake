// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import {Title} from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Borrower {
    ERC20Like tkn;
    ShelfLike shelf;
    TReserveLike reserve;
    PileLike pile;

    constructor(address shelf_, address reserve_, address tkn_, address pile_) {
        shelf = ShelfLike(shelf_);
        reserve = TReserveLike(reserve_);
        tkn = ERC20Like(tkn_);
        pile = PileLike(pile_);
    }

    function issue(address registry, uint256 nft) public returns (uint256 loan) {
        return shelf.issue(registry, nft);
    }

    function close(uint256 loan) public {
        shelf.close(loan);
    }

    function lock(uint256 loan) public {
        shelf.lock(loan);
    }

    function unlock(uint256 loan) public {
        shelf.unlock(loan);
    }

    function borrow(uint256 loan, uint256 currencyAmount) public {
        shelf.borrow(loan, currencyAmount);
    }

    function repay(uint256 loan, uint256 currencyAmount) public {
        shelf.repay(loan, currencyAmount);
    }

    function withdraw(uint256 loan, uint256 currencyAmount, address usr) public {
        shelf.withdraw(loan, currencyAmount, usr);
    }

    function borrowAction(uint256 loan, uint256 currencyAmount) public {
        shelf.lock(loan);
        shelf.borrow(loan, currencyAmount);
        shelf.withdraw(loan, currencyAmount, address(this));
    }

    function approveNFT(Title nft, address usr) public {
        nft.setApprovalForAll(usr, true);
    }

    function repayAction(uint256 loan, uint256 currencyAmount) public {
        shelf.repay(loan, currencyAmount);
        shelf.unlock(loan);
    }

    function doClose(uint256 loan) public {
        uint256 debt = pile.debt(loan);
        repayAction(loan, debt);
    }

    function doApproveCurrency(address usr, uint256 currencyPrice) public {
        tkn.approve(usr, currencyPrice);
    }
}
