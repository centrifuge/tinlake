// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./mock/coordinator.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract OperatorPoolAdminTest is DSTest {

    uint constant ONE = 10e27;

    Assessor assessor;
    ClerkMock lending;
    MemberlistMock seniorMemberlist;
    MemberlistMock juniorMemberlist;
    CoordinatorMock coordinator;
    NAVFeedMock navFeed;
    PoolAdmin poolAdmin;

    function setUp() public {
        assessor = new Assessor();
        lending = new ClerkMock();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        coordinator = new CoordinatorMock();
        navFeed = new NAVFeedMock();
        poolAdmin = new PoolAdmin();
        poolAdmin.relyWard(address(this)); // required to call relyOperator()

        assessor.rely(address(poolAdmin));
        lending.rely(address(poolAdmin));
        seniorMemberlist.rely(address(poolAdmin));
        juniorMemberlist.rely(address(poolAdmin));
        coordinator.rely(address(poolAdmin));
        navFeed.rely(address(poolAdmin));

        poolAdmin.depend("assessor", address(assessor));
        poolAdmin.depend("lending", address(lending));
        poolAdmin.depend("seniorMemberlist", address(seniorMemberlist));
        poolAdmin.depend("juniorMemberlist", address(juniorMemberlist));
        poolAdmin.depend("coordinator", address(coordinator));
        poolAdmin.depend("navFeed", address(navFeed));
    }

    function callOverrideWriteOff() public {
        uint loan = 1;
        uint index = 0;
        poolAdmin.overrideWriteOff(loan, index);
        assertEq(navFeed.values_uint("overrideWriteOff_loan"), loan);
        assertEq(navFeed.values_uint("overrideWriteOff_index"), index);
    }

    function testOverrideWriteOff() public {
        poolAdmin.relyOperator(address(this));
        callOverrideWriteOff();
    }

    function testFailOverrideWriteOffNotOperator() public {
        callOverrideWriteOff(); 
    }

    function callFileRiskGroup() public {
        poolAdmin.fileRiskGroup(0, 8*10**26, 6*10**26, ONE, ONE);
        assertEq(navFeed.values_uint("file_thresholdRatio_"), 8*10**26);
    }

    function testFileRiskGroup() public {
        poolAdmin.relyOperator(address(this));
        callFileRiskGroup();
    }

    function testFailFileRiskGroupNotOperator() public {
        callFileRiskGroup(); 
    }

    // TODO: testFileRiskGroups

    function callFileWriteOffGroup() public {
        poolAdmin.fileWriteOffGroup(uint(1000000674400000000000000000), 75 * 10**25, 30);
        assertEq(navFeed.values_uint("file_writeOffPercentage"), 75 * 10**25);
    }

    function testFileWriteOffGroup() public {
        poolAdmin.relyOperator(address(this));
        callFileWriteOffGroup();
    }

    function testFailFileWriteOffGroupNotOperator() public {
        callFileWriteOffGroup(); 
    }

    // TODO: testFileWriteOffGroups

    function callUpdateNFTValue() public {
        bytes32 nftID_ = "1";
        uint value = 100;
        poolAdmin.updateNFTValue(nftID_, value);
        assertEq(navFeed.values_bytes32("update_nftID"), nftID_);
        assertEq(navFeed.values_uint("update_value"), value);
    }

    function testUpdateNFTValue() public {
        poolAdmin.relyOperator(address(this));
        callUpdateNFTValue();
    }

    function testFailUpdateNFTValueNotOperator() public {
        callUpdateNFTValue(); 
    }

    function callUpdateNFTValueRisk() public {
        bytes32 nftID_ = "1";
        uint value = 100;
        uint risk = 0;
        poolAdmin.updateNFTValueRisk(nftID_, value, risk);
        assertEq(navFeed.values_bytes32("update_nftID"), nftID_);
        assertEq(navFeed.values_uint("update_value"), value);
        assertEq(navFeed.values_uint("update_risk"), risk);
    }

    function testUpdateNFTValueRisk() public {
        poolAdmin.relyOperator(address(this));
        callUpdateNFTValueRisk();
    }

    function testFailUpdateNFTValueRiskNotOperator() public {
        callUpdateNFTValueRisk(); 
    }

    function callUpdateNFTMaturityDate() public {
        bytes32 nftID_ = "1";
        uint maturityDate = block.timestamp + 4 weeks;
        poolAdmin.updateNFTMaturityDate(nftID_, maturityDate);
        assertEq(navFeed.values_bytes32("file_nftID"), nftID_);
        assertEq(navFeed.values_uint("file_maturityDate"), maturityDate);
    }

    function testUpdateNFTMaturityDate() public {
        poolAdmin.relyOperator(address(this));
        callUpdateNFTMaturityDate();
    }

    function testFailUpdateNFTMaturityDateNotOperator() public {
        callUpdateNFTMaturityDate(); 
    }

}

