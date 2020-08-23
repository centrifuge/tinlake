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
pragma experimental ABIEncoderV2;

import "./ticker.sol";
import "tinlake-auth/auth.sol";
import "./data_types.sol";
import "tinlake-math/interest.sol";

interface NAVFeed {
    function currentNAV() external;
}

contract Assessor is Auth, DataTypes, Interest  {
    // senior ratio from the last epoch executed
    Fixed27 public lastSeniorRatio;
    uint public seniorDebt;
    uint public seniorBalance;

    // system parameter

    // interest rate per second for senior tranche
    Fixed27 public seniorInterestRate;
    Fixed27 public maxSeniorRatio;
    Fixed27 public minSeniorRatio;

    uint public maxReserve;

    constructor() public {
        wards[msg.sender] = 1;
        seniorInterestRate.value = ONE;
    }

    function file(bytes32 name, uint value) public auth {
        if(name == "seniorInterestRate") {
            seniorInterestRate  = Fixed27(value);
        }
        else if (name == "maxReserve") {maxReserve = value;}
        else if (name == "maxSeniorRatio") {
            require(value > minSeniorRatio.value);
            maxSeniorRatio = Fixed27(value);
        }
        else if (name == "minSeniorRatio") {
            require(value < maxSeniorRatio.value);
            minSeniorRatio = Fixed27(value);
        }
        else {revert("unkown-variable");}
    }

    function updateSenior(uint seniorDebt_, uint seniorBalance_) public auth {

    }

    function seniorRatioBounds() public view returns (uint minSeniorRatio_, uint maxSeniorRatio_) {
        return (0, 0);
    }

    function calcNAV() external returns (uint) {
        return 0;
    }

    function calcSeniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        return 0;
    }

    function calcJuniorTokenPrice(uint epochNAV, uint epochReserve) external returns(uint) {
        return 0;
    }

    function repaymentUpdate(uint amount) public auth {

    }

    function borrowUpdate(uint amount) public auth {

    }
}
