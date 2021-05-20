// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
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
    function defaultConfig() public pure returns(TinlakeConfig memory t) {
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
