// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
import "ds-test/test.sol";

import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract NAVFeedMock is Mock, Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    function latestNAV() public view returns (uint) {
        return values_return["latestNAV"];
    }

    function calcUpdateNAV() public returns (uint) {
        return call("calcUpdateNAV");
    }

    function currentNAV() public view returns (uint) {
        return values_return["currentNAV"];
    }

    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) public {
        values_uint["overrideWriteOff_loan"] = loan;
        values_uint["overrideWriteOff_index"] = writeOffGroupIndex_;
    }

    function file(bytes32 name, uint value) public {
        values_bytes32["file_name"] = name;
        values_uint["file_value"] = value;
    }

    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_) public {
        values_bytes32["file_name"] = name;
        values_uint["file_risk"] = risk_;
        values_uint["file_thresholdRatio_"] = thresholdRatio_;
        values_uint["file_ceilingRatio"] = ceilingRatio_;
        values_uint["file_rate"] = rate_;
        values_uint["file_recoveryRatePD"] = recoveryRatePD_;
    }

    function file(bytes32 name, uint rate_, uint writeOffPercentage_, uint overdueDays_) public {
        values_bytes32["file_name"] = name;
        values_uint["file_rate"] = rate_;
        values_uint["file_writeOffPercentage"] = writeOffPercentage_;
        values_uint["file_overdueDays"] = overdueDays_;
    }

    function update(bytes32 nftID_,  uint value) public {
        values_bytes32["update_nftID"] = nftID_;
        values_uint["update_value"] = value;
    }

    function update(bytes32 nftID_, uint value, uint risk_) public {
        values_bytes32["update_nftID"] = nftID_;
        values_uint["update_value"] = value;
        values_uint["update_risk"] = risk_;
    }

    function file(bytes32 name, bytes32 nftID_, uint maturityDate_) public {
        values_bytes32["file_name"] = name;
        values_bytes32["file_nftID"] = nftID_;
        values_uint["file_maturityDate"] = maturityDate_;
    }
}
