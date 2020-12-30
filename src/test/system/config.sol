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

import "ds-test/test.sol";
import "./base_system.sol";

//  Contract to manage the config variables of a Tinlake test deployment
contract Config {
    struct TinlakeConfig {
        // borrower variables
        uint discountRate;
        string titleName;
        string titleSymbol;

        // lender variables
        uint seniorInterestRate;
        uint maxReserve;
        uint maxSeniorRatio;
        uint minSeniorRatio;
        uint challengeTime;
        string seniorTokenName;
        string seniorTokenSymbol;
        string juniorTokenName;
        string juniorTokenSymbol;

        // mkr variables
        uint mkrMAT;
        uint mkrStabilityFee;
        bytes32 mkrILK;
    }

    // returns a default config for a Tinlake deployment
    function defaultConfig() public returns(TinlakeConfig memory t) {
        return  TinlakeConfig({
            // 3% per day
            discountRate: uint(1000000342100000000000000000),
            titleName: "Tinlake Loan Token",
            titleSymbol: "TLNT",
            // 2% per day
            seniorInterestRate: uint(1000000229200000000000000000),
            maxReserve: uint(-1),
            maxSeniorRatio: 0.85 *10**27,
            minSeniorRatio: 0.75 *10**27,
            challengeTime: 1 hours,
            seniorTokenName: "DROP Token",
            seniorTokenSymbol: "DROP",
            juniorTokenName: "TIN Token",
            juniorTokenSymbol: "TIN",
            mkrMAT: 1.10 * 10**27,
            mkrStabilityFee: 10**27,
            mkrILK: "drop"
        });
    }
}
