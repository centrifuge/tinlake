// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "./navfeed.sol";

contract PrincipalNAVFeed is NAVFeed {

    // rate group for write-offs in pile contract
    uint constant public WRITE_OFF_PHASE_A = 1001;
    uint constant public WRITE_OFF_PHASE_B = 1002;

    function init() public override {
        require(ceilingRatio[0] == 0, "already-initialized");

        // gas optimized initialization of writeOffs and risk groups
        // write off are hardcoded in the contract instead of init function params

        // risk groups are extended by the recoveryRatePD parameter compared with NFTFeed

        // The following score cards just examples that are mostly optimized for the system test cases

        // risk group: 0
        file("riskGroup",
            0,                                      // riskGroup:       0
            8*10**26,                               // thresholdRatio   80%
            6*10**26,                               // ceilingRatio     60%
            ONE,                                    // interestRate     1.0
            ONE                                     // recoveryRatePD:  1.0
        );

        // risk group: 1
        file("riskGroup",
            1,                                      // riskGroup:       1
            7*10**26,                               // thresholdRatio   70%
            5*10**26,                               // ceilingRatio     50%
            uint(1000000003593629043335673583),     // interestRate     12% per year
            90 * 10**25                             // recoveryRatePD:  0.9
        );

        // risk group: 2
        file("riskGroup",
            2,                                      // riskGroup:       2
            7*10**26,                               // thresholdRatio   70%
            5*10**26,                               // ceilingRatio     50%
            uint(1000000564701133626865910626),     // interestRate     5% per day
            90 * 10**25                             // recoveryRatePD:  0.9
        );

        // risk group: 3
        file("riskGroup",
            3,                                      // riskGroup:       3
            7*10**26,                               // thresholdRatio   70%
            ONE,                                    // ceilingRatio     100%
            uint(1000000564701133626865910626),     // interestRate     5% per day
            ONE                                     // recoveryRatePD:  1.0
        );

        // risk group: 4 (used by collector tests)
        file("riskGroup",
            4,                                      // riskGroup:       4
            5*10**26,                               // thresholdRatio   50%
            6*10**26,                               // ceilingRatio     60%
            uint(1000000564701133626865910626),     // interestRate     5% per day
            ONE                                     // recoveryRatePD:  1.0
        );

        /// Overdue loans (= loans that were not repaid by the maturityDate) are moved to write Offs
        // 6% interest rate & 60% write off
        setWriteOff(0, WRITE_OFF_PHASE_A, uint(1000000674400000000000000000), 6 * 10**26, 30);
        // 6% interest rate & 80% write off
        setWriteOff(1, WRITE_OFF_PHASE_B, uint(1000000674400000000000000000), 8 * 10**26, 90);
    }

    // returns the ceiling of a loan
    // the ceiling defines the maximum amount which can be borrowed
    function ceiling(uint loan) public override view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        uint initialCeiling = rmul(nftValues[nftID_], ceilingRatio[risk[nftID_]]);

        if (borrowed[loan] > initialCeiling) {
            return 0;
        }

        return safeSub(initialCeiling, borrowed[loan]);
    }

}