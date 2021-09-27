// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./../../borrower/feed/navfeed.sol";
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
    NAVFeed navFeed;
    PoolAdmin poolAdmin;

    function setUp() public {
        assessor = new Assessor();
        lending = new ClerkMock();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        coordinator = new CoordinatorMock();
        // navFeed = new NAVFeed();
        poolAdmin = new PoolAdmin();

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
        (uint128 ceilingRatio,,) = navFeed.riskGroup(0);
        emit log_named_uint("test", ceilingRatio);
        // assertEq(ceilingRatio, 6*10**26);
    }

    function testAddRiskGroup() public {
        callAddRiskGroup();
    }

    function testFailAddRiskGroupNotOperator() public {
        poolAdmin.deny(address(this));
        callAddRiskGroup(); 
    }

    // TODO: testAddRiskGroups

    function callAddRiskGroups(uint256[] memory risks_, uint256[] memory thresholdRatios_, uint256[] memory ceilingRatios_, uint256[] memory rates_, uint256[] memory recoveryRatePDs_) public {
        poolAdmin.addRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
        // emit log_named_uint("test", navFeed.calls("addRiskGroup"));
        // assertEq(navFeed.calls("addRiskGroup"), 3);
    }

    // function callFailAddRiskGroupsDifferentArrayLength(uint256[] risks_, uint256[] thresholdRatios_, uint256[] ceilingRatios_, uint256[] rates_, uint256[] recoveryRatePDs_) public {
    //     poolAdmin.addRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
    //     assertEq(navFeed.calls("addRiskGroup"), 3);
    // }

    function testAddRiskGroups() public {
        navFeed.rely(address(this));
        uint[] memory risks_ = new uint[](3);
        uint[] memory thresholdRatios_ = new uint[](3);
        uint[] memory ceilingRatios_ = new uint[](3);
        uint[] memory rates_ = new uint[](3);
        uint[] memory recoveryRatePDs_ = new uint[](3);
        risks_[0] = 0;
        risks_[1] = 1;
        risks_[2] = 2;
        thresholdRatios_[0] = 8*10**26;
        thresholdRatios_[1] = 8*10**26;
        thresholdRatios_[2] = 8*10**26;
        ceilingRatios_[0] = 6*10**26;
        ceilingRatios_[1] = 6*10**26;
        ceilingRatios_[2] = 6*10**26;
        rates_[0] = ONE;
        rates_[1] = ONE;
        rates_[2] = ONE;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = ONE;
        callAddRiskGroups(risks_, thresholdRatios_, ceilingRatios_, rates_, recoveryRatePDs_);
    }

    function testFailAddRiskGroups() public {
        uint[] memory risks_ = new uint[](3);
        uint[] memory thresholdRatios_ = new uint[](3);
        uint[] memory ceilingRatios_ = new uint[](3);
        uint[] memory rates_ = new uint[](2);
        uint[] memory recoveryRatePDs_ = new uint[](3);
        risks_[0] = 0;
        risks_[1] = 1;
        thresholdRatios_[0] = 8*10**26;
        thresholdRatios_[1] = 8*10**26;
        ceilingRatios_[0] = 6*10**26;
        ceilingRatios_[1] = 6*10**26;
        rates_[0] = ONE;
        rates_[1] = ONE;
        recoveryRatePDs_[0] = ONE;
        recoveryRatePDs_[0] = ONE;
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

