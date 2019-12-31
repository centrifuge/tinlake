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

pragma solidity >=0.4.24;

import {OperatorLike} from "../../tranche/distributor/distributor.sol";

// TODO refactor mock
contract ManagerMock {

    struct Tranche {
        uint ratio;
        OperatorLike operator;
    }

    Tranche[] public tranches;

    uint public assetReturn; function setAssetReturn(uint assetAmount_) public {assetReturn=assetAmount_;}
    bool public poolClosing; function setPoolClosing(bool close_) public {poolClosing=close_;}
    address public pile; function setPile(address p_) public {pile=p_;}
    int public pileAmount; function setPileAmount(int wad_) public {pileAmount=wad_;}

    // calls
    uint public callsBalance;
    uint public callsReduce;

    uint public wad;
    address public tranche;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
        wad = wad_;
        callsReduce++;
    }

    function getTrancheAssets(address tranche_) public returns (uint) {
        tranche = tranche_;
        return assetReturn;
    }

    function addTranche(uint ratio, address operator_) public {
        Tranche memory t;
        t.ratio = ratio;
        t.operator = OperatorLike(operator_);
        tranches.push(t);
    }

    function trancheCount() public returns (uint) {
        return tranches.length;
    }

    function operatorOf(uint i) public returns (address) {
        return address(tranches[i].operator);
    }

    function ratioOf(uint i) public returns (uint) {
        return tranches[i].ratio;
    }

    function checkPile() public returns (int) {
        return pileAmount;
    }
}