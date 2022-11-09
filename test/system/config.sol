// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./base_system.sol";

//  Contract to manage the config variables of a Tinlake test deployment
contract Config {
    struct TinlakeConfig {
        // borrower variables
        uint256 discountRate;
        string titleName;
        string titleSymbol;
        // lender variables
        uint256 seniorInterestRate;
        uint256 maxReserve;
        uint256 maxSeniorRatio;
        uint256 minSeniorRatio;
        uint256 challengeTime;
        string seniorTokenName;
        string seniorTokenSymbol;
        string juniorTokenName;
        string juniorTokenSymbol;
        // mkr variables
        uint256 mkrMAT;
        uint256 mkrStabilityFee;
        bytes32 mkrILK;
    }

    // returns a default config for a Tinlake deployment
    function defaultConfig() public pure returns (TinlakeConfig memory t) {
        return TinlakeConfig({
            // 3% per day
            discountRate: uint256(1000000342100000000000000000),
            titleName: "Tinlake Loan Token",
            titleSymbol: "TLNT",
            // 2% per day
            seniorInterestRate: uint256(1000000229200000000000000000),
            maxReserve: type(uint256).max,
            maxSeniorRatio: 0.85 * 10 ** 27,
            minSeniorRatio: 0.75 * 10 ** 27,
            challengeTime: 1 hours,
            seniorTokenName: "DROP Token",
            seniorTokenSymbol: "DROP",
            juniorTokenName: "TIN Token",
            juniorTokenSymbol: "TIN",
            mkrMAT: 1.1 * 10 ** 27,
            mkrStabilityFee: 10 ** 27,
            mkrILK: "drop"
        });
    }
}
