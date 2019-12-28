// Copyright (C) 2019 Centrifuge
//
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

import "./distributor.sol";

contract LOC is Distributor {

    constructor (address manager_, address flow_) Distributor(manager_, flow_) public {}

    function balance() public auth line {
        require(manager.poolClosing() == false);

        int wad = manager.checkPile();
        if (wad > 0) {
            borrowFromTranches(uint(wad));
        } else if (wad < 0) {
            // takes extra money from Pile and repays tranche debt to avoid accumulation of fees
            repayTranches(uint(wad*-1));
        }
    }

    function borrowFromTranches(uint borrowAmount) private {
        for (uint i = 0; i < manager.trancheCount(); i++) {
            OperatorLike o = OperatorLike(manager.operatorOf(i));
            uint trancheReserve = o.balance();
            if (borrowAmount <= trancheReserve) {
                o.borrow(address(manager.pile), borrowAmount);
                return;
            }
            o.borrow(address(manager.pile), trancheReserve);
            borrowAmount = sub(borrowAmount, trancheReserve);
        }
    }

    // Note: assumes two tranche setup for now

    // max_take is how much liquidity can be taken out from a specific tranche, given the current equity reserve/equity debt,
    // in order to maintain the equity ratio which has been set by the pool manager.

    // Note that this formula is for the Maker scenario: we are assuming the Senior Reserve to be 0

    // max_take =  (Equity.Reserve + Equity.Debt)/Equity.Ratio * Senior.Ratio - Senior.Debt

    function calcMaxTake() public auth returns (uint) {
        OperatorLike oE = OperatorLike(manager.operatorOf(0));
        OperatorLike oS = OperatorLike(manager.operatorOf(1));

        uint wadER = oE.balance();
        uint wadED =  oE.debt();
        uint ratioE = manager.ratioOf(0);

        uint wadSD = oS.debt();
        uint ratioS = manager.ratioOf(1);

        return sub(mul(add(wadER, wadED)/ratioE, ratioS), wadSD);
    }

    // --- Math ---

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
}