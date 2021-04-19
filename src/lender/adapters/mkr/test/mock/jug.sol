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

import "../../../../../test/mock/mock.sol";

contract JugMock is Mock {
    bool interestUpdated = false;
    constructor() public {
        values_return["base"] = 10**27;
        values_return["ilks_duty"] = 10**27;
    }
    function ilks(bytes32 ilk) public view returns (uint ,uint) {
        uint rho = block.timestamp;
        if(interestUpdated == false) {
            rho = values_return["ilks_rho"];
        }
        return (values_return["ilks_duty"], rho);
    }

    function drip(bytes32 ilk) public returns(uint) {
        calls["drip"]++;
        values_bytes32["drip_ilk"] = ilk;
        return values_return["ilks_rates"];
    }

    function base() public view returns(uint) {
        return values_return["base"];
    }

    function setInterestUpToDate(bool flag) public {
        interestUpdated = flag;
    }
}
