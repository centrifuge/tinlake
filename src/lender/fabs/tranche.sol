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

import { Tranche } from "./../tranche.sol";
import { Memberlist } from "./../token/memberlist.sol";
import { RestrictedToken } from "./../token/restricted.sol";

contract TrancheFab {
    function newTranche(address currency, string memory name, string memory symbol) public returns (address tranche, address token, address memberlist) {
        Memberlist memberlist = new Memberlist();
        RestrictedToken restrictedToken = new RestrictedToken(symbol, name);
        Tranche tranche = new Tranche(currency, address(restrictedToken));
        
        restrictedToken.rely(address(tranche));
        restrictedToken.rely(msg.sender);
        restrictedToken.deny(address(this));

        tranche.rely(msg.sender);
        tranche.deny(address(this));
        memberlist.rely(msg.sender);
        memberlist.deny(address(this));


        return (address(tranche), address(restrictedToken), address(memberlist));
    }
}
