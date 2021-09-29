// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./../../borrower/feed/principal.sol";
import "./../../borrower/test/mock/pile.sol";
import "./mock/coordinator.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract RiskManagementPoolAdminTest is DSTest {

    uint constant ONE = 10e27;

    Assessor assessor;
    ClerkMock lending;
    MemberlistMock seniorMemberlist;
    MemberlistMock juniorMemberlist;
    CoordinatorMock coordinator;
    NAVFeedMock navFeedMock;
    NAVFeed public navFeed;
    PoolAdmin poolAdmin;
    PileMock pile;

    function setUp() public {
        assessor = new Assessor();
        lending = new ClerkMock();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        coordinator = new CoordinatorMock();
        navFeed = new PrincipalNAVFeed();
        poolAdmin = new PoolAdmin();
        pile = new PileMock();

        assessor.rely(address(poolAdmin));
        lending.rely(address(poolAdmin));
        seniorMemberlist.rely(address(poolAdmin));
        juniorMemberlist.rely(address(poolAdmin));
        coordinator.rely(address(poolAdmin));

        poolAdmin.depend("assessor", address(assessor));
        poolAdmin.depend("lending", address(lending));
        poolAdmin.depend("seniorMemberlist", address(seniorMemberlist));
        poolAdmin.depend("juniorMemberlist", address(juniorMemberlist));
        poolAdmin.depend("coordinator", address(coordinator));
        poolAdmin.depend("navFeed", address(navFeed));
        navFeed.depend("pile", address(pile));
    }

    function callOverrideWriteOff() public {
        uint loan = 1;
        uint index = 0;
        poolAdmin.overrideWriteOff(loan, index);
        assertEq(navFeedMock.values_uint("overrideWriteOff_loan"), loan);
        assertEq(navFeedMock.values_uint("overrideWriteOff_index"), index);
    }

    function testOverrideWriteOff() public {
        callOverrideWriteOff();
    }

    function testFailOverrideWriteOffNotOperator() public {
        poolAdmin.deny(address(this));
        callOverrideWriteOff(); 
    }

    function callAddRiskGroup() public {
        poolAdmin.addRiskGroup(0, 8*10**26, 6*10**26, ONE, ONE);
        (uint128 ceilingRatio, uint128 thresholdRatios, uint128 recoveryRatePDs) = navFeed.riskGroup(0);
        assertEq(uint256(ceilingRatio), 6*10**26);
        assertEq(uint256(thresholdRatios), 8*10**26);
        assertEq(uint256(recoveryRatePDs), ONE);
        assertEq(pile.calls("file"), 1);
    }

    function testAddRiskGroup() public {
        navFeed.rely(address(poolAdmin));
        callAddRiskGroup();
    }

    function testFailAddRiskGroupNotOperator() public {
        callAddRiskGroup(); 
    }

    // TODO: testAddRiskGroups

    function callAddRiskGroups(uint256[] memory risks_, uint256[] memory thresholdRatios_, uint256[] memory ceilingRatios_, uint256[] memory rates_, uint256[] memory recoveryRatePDs_) public {
        poolAdmin.addRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
        for (uint i; i < ceilingRatios_.length; i++) {
            (uint128 ceilingRatio, uint128 thresholdRatios, uint128 recoveryRatePDs) = navFeed.riskGroup(i);
            assertEq(uint256(ceilingRatio), ceilingRatios_[i]);
            assertEq(uint256(thresholdRatios), thresholdRatios_[i]);
            assertEq(uint256(recoveryRatePDs), recoveryRatePDs_[i]);
        }
        assertEq(pile.calls("file"), 3);
    }


    function testAddRiskGroups() public {
        navFeed.rely(address(poolAdmin));
        uint[] memory risks_ = new uint[](3);
        uint[] memory thresholdRatios_ = new uint[](3);
        uint[] memory ceilingRatios_ = new uint[](3);
        uint[] memory rates_ = new uint[](3);
        uint[] memory recoveryRatePDs_ = new uint[](3);
        risks_[0] = 0;
        risks_[1] = 1;
        risks_[2] = 2;
        thresholdRatios_[0] = 8*10**27;
        thresholdRatios_[1] = 5*10**26;
        thresholdRatios_[2] = 1*10**26;
        ceilingRatios_[0] = 2*10**26;
        ceilingRatios_[1] = 5*10**26;
        ceilingRatios_[2] = 1*10**27;
        rates_[0] = ONE;
        rates_[1] = 5;
        rates_[2] = 2;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = 2;
        recoveryRatePDs_[0] = 10;
        callAddRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
    }

    function testFailAddRiskGroupsWrongArrayLength() public {
        navFeed.rely(address(poolAdmin));
        uint[] memory risks_ = new uint[](3);
        uint[] memory thresholdRatios_ = new uint[](3);
        uint[] memory ceilingRatios_ = new uint[](3);
        uint[] memory rates_ = new uint[](2);
        uint[] memory recoveryRatePDs_ = new uint[](3);
        risks_[0] = 0;
        risks_[1] = 1;
        risks_[2] = 2;
        thresholdRatios_[0] = 8*10**27;
        thresholdRatios_[1] = 5*10**26;
        thresholdRatios_[2] = 1*10**26;
        ceilingRatios_[0] = 2*10**26;
        ceilingRatios_[1] = 5*10**26;
        ceilingRatios_[2] = 1*10**27;
        rates_[0] = ONE;
        rates_[1] = 5;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = 2;
        recoveryRatePDs_[0] = 10;
        callAddRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
    }

    function testFailAddRiskGroupsNoAuth() public {
        uint[] memory risks_ = new uint[](3);
        uint[] memory thresholdRatios_ = new uint[](3);
        uint[] memory ceilingRatios_ = new uint[](3);
        uint[] memory rates_ = new uint[](3);
        uint[] memory recoveryRatePDs_ = new uint[](3);
        risks_[0] = 0;
        risks_[1] = 1;
        risks_[2] = 2;
        thresholdRatios_[0] = 8*10**27;
        thresholdRatios_[1] = 5*10**26;
        thresholdRatios_[2] = 1*10**26;
        ceilingRatios_[0] = 2*10**26;
        ceilingRatios_[1] = 5*10**26;
        ceilingRatios_[2] = 1*10**27;
        rates_[0] = ONE;
        rates_[1] = 5;
        rates_[2] = 2;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = 2;
        recoveryRatePDs_[0] = 10;
        callAddRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
    }

    function callAddWriteOffGroup() public {
        poolAdmin.addWriteOffGroup(uint(1000000674400000000000000000), 75 * 10**25, 30);
        assertEq(navFeedMock.values_uint("file_writeOffPercentage"), 75 * 10**25);
    }

    function testAddWriteOffGroup() public {
        callAddWriteOffGroup();
    }

    function testFailAddWriteOffGroupNotOperator() public {
        poolAdmin.deny(address(this));
        callAddWriteOffGroup(); 
    }

    // TODO: testAddWriteOffGroups

    function setMatBuffer() public {
        uint matBuffer = 0.02 * 10**27;
        poolAdmin.setMatBuffer(matBuffer);
        assertEq(lending.values_uint("file_value"), matBuffer);
    }

    function testSetMatBuffer() public {
        setMatBuffer(); 
    }
    function callUpdateNFTValue() public {
        bytes32 nftID_ = "1";
        uint value = 100;
        poolAdmin.updateNFTValue(nftID_, value);
        assertEq(navFeedMock.values_bytes32("update_nftID"), nftID_);
        assertEq(navFeedMock.values_uint("update_value"), value);
    }

    function testUpdateNFTValue() public {
        callUpdateNFTValue();
    }

    function testFailUpdateNFTValueNotOperator() public {
        poolAdmin.deny(address(this));
        callUpdateNFTValue(); 
    }

    function callUpdateNFTValueRisk() public {
        bytes32 nftID_ = "1";
        uint value = 100;
        uint risk = 0;
        poolAdmin.updateNFTValueRisk(nftID_, value, risk);
        assertEq(navFeedMock.values_bytes32("update_nftID"), nftID_);
        assertEq(navFeedMock.values_uint("update_value"), value);
        assertEq(navFeedMock.values_uint("update_risk"), risk);
    }

    function testUpdateNFTValueRisk() public {
        callUpdateNFTValueRisk();
    }

    function testFailUpdateNFTValueRiskNotOperator() public {
        poolAdmin.deny(address(this));
        callUpdateNFTValueRisk(); 
    }

    function callUpdateNFTMaturityDate() public {
        bytes32 nftID_ = "1";
        uint maturityDate = block.timestamp + 4 weeks;
        poolAdmin.updateNFTMaturityDate(nftID_, maturityDate);
        assertEq(navFeedMock.values_bytes32("file_nftID"), nftID_);
        assertEq(navFeedMock.values_uint("file_maturityDate"), maturityDate);
    }

    function testUpdateNFTMaturityDate() public {
        callUpdateNFTMaturityDate();
    }

    function testFailUpdateNFTMaturityDateNotOperator() public {
        poolAdmin.deny(address(this));
        callUpdateNFTMaturityDate(); 
    }

}

