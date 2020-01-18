// Copyright (C) 2020 Centrifuge
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

import "tinlake-auth/auth.sol";

contract CollectorLike {
    function collect(uint loan, address usr) public;
}

contract CollectOperator is Auth {

    CollectorLike collector;

    constructor(address collector_) public {
        wards[msg.sender] = 1;
        collector = CollectorLike(collector_);
    }

    function depend(bytes32 what, address addr) public auth {
        if(what == "collector") { collector = CollectorLike(addr);}
        else revert();
    }

    function collect(uint loan) public auth {
        collector.collect(loan, msg.sender);
    }
}