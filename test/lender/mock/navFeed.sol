// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "forge-std/Test.sol";

import "test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract NAVFeedMock is Mock, Auth {
    constructor() {
        wards[msg.sender] = 1;
    }

    function latestNAV() public view returns (uint256) {
        return values_return["latestNAV"];
    }

    function calcUpdateNAV() public returns (uint256) {
        return call("calcUpdateNAV");
    }

    function currentNAV() public view returns (uint256) {
        return values_return["currentNAV"];
    }

    function lastNAVUpdate() public view returns (uint256) {
        return block.timestamp;
    }

    function overrideWriteOff(uint256 loan, uint256 writeOffGroupIndex_) public {
        values_uint["overrideWriteOff_loan"] = loan;
        values_uint["overrideWriteOff_index"] = writeOffGroupIndex_;
    }

    function file(bytes32 name, uint256 value) public {
        values_bytes32["file_name"] = name;
        values_uint["file_value"] = value;
    }

    function file(
        bytes32 name,
        uint256 risk_,
        uint256 thresholdRatio_,
        uint256 ceilingRatio_,
        uint256 rate_,
        uint256 recoveryRatePD_
    ) public {
        values_bytes32["file_name"] = name;
        values_uint["file_risk"] = risk_;
        values_uint["file_thresholdRatio_"] = thresholdRatio_;
        values_uint["file_ceilingRatio"] = ceilingRatio_;
        values_uint["file_rate"] = rate_;
        values_uint["file_recoveryRatePD"] = recoveryRatePD_;
    }

    function file(bytes32 name, uint256 rate_, uint256 writeOffPercentage_, uint256 overdueDays_) public {
        values_bytes32["file_name"] = name;
        values_uint["file_rate"] = rate_;
        values_uint["file_writeOffPercentage"] = writeOffPercentage_;
        values_uint["file_overdueDays"] = overdueDays_;
    }

    function update(bytes32 nftID_, uint256 value) public {
        values_bytes32["update_nftID"] = nftID_;
        values_uint["update_value"] = value;
    }

    function update(bytes32 nftID_, uint256 value, uint256 risk_) public {
        values_bytes32["update_nftID"] = nftID_;
        values_uint["update_value"] = value;
        values_uint["update_risk"] = risk_;
    }

    function file(bytes32 name, bytes32 nftID_, uint256 maturityDate_) public {
        values_bytes32["file_name"] = name;
        values_bytes32["file_nftID"] = nftID_;
        values_uint["file_maturityDate"] = maturityDate_;
    }
}
