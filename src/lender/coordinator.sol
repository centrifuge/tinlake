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

import "./ticker.sol";
import "tinlake-auth/auth.sol";

interface EpochTrancheLike {
    function epochUpdate(uint epochID, uint supplyFulfillment_,
        uint redeemFulfillment_, uint tokenPrice_) external;
}

interface ReserveLike {
    function updateMaxCurrency(uint currencyAmount) external;
}

contract EpochCoordinator is Ticker, Auth {

    EpochTrancheLike juniorTranche;
    EpochTrancheLike seniorTranche;

    ReserveLike reserve;

    uint public lastEpochExecuted;

    constructor() public {
        wards[msg.sender] = 1;
    }

    /// sets the dependency to another contract
    function depend (bytes32 contractName, address addr) public auth {
        if (contractName == "juniorTranche") { juniorTranche = EpochTrancheLike(addr); }
        else if (contractName == "seniorTranche") { seniorTranche = EpochTrancheLike(addr); }
        else if (contractName == "reserve") { reserve = ReserveLike(addr); }
        else revert();
    }

    function executeEpoch() external {
        uint currEpoch = currentEpoch();
        require(lastEpochExecuted < currentEpoch());

        lastEpochExecuted = currEpoch;
    }

}
