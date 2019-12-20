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

import "ds-note/note.sol";

import {Diffuser} from "./diffuser.sol";
import {Distributor} from "./distributor.sol";

contract Orchestrator is DSNote{

    Diffuser public diffuser;
    Distributor public distributor;

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    function handleFlow(bool flowThrough, bool poolClosing) public auth {
        if (flowThrough) {
            distributor.handleFlow(flowThrough, poolClosing);
        } else {
            diffuser.handleFlow(flowThrough, poolClosing);
        }
    }

}