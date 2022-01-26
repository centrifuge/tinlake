// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./mock/coordinator.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract PoolGovernancePoolAdminTest is DSTest {

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

    function setSeniorInterestRate() public {
        uint seniorInterestRate = 1000000674400000000000000000;
        poolAdmin.setSeniorInterestRate(seniorInterestRate);
        assertEq(assessor.seniorInterestRate(), seniorInterestRate);
    }

    function testSetSeniorInterestRate() public {
        setSeniorInterestRate(); 
    }

    function setDiscountRate() public {
        uint discountRate = 1000000674400000000000000000;
        poolAdmin.setDiscountRate(discountRate);
        assertEq(navFeed.values_uint("file_value"), discountRate);
    }

    function testSetDiscountRate() public {
        setDiscountRate(); 
    }

    function setMinimumEpochTime() public {
        uint minimumEpochTime = 2 days;
        poolAdmin.setMinimumEpochTime(minimumEpochTime);
        assertEq(coordinator.values_uint("file_value"), minimumEpochTime);
    }

    function testSetMinimumEpochTime() public {
        setMinimumEpochTime(); 
    }

    function setChallengeTime() public {
        uint challengeTime = 1 hours;
        poolAdmin.setChallengeTime(challengeTime);
        assertEq(coordinator.values_uint("file_value"), challengeTime);
    }

    function testSetChallengeTime() public {
        setChallengeTime(); 
    }

    function setMinSeniorRatio() public {
        // required to call first because minSeniorRatio < maxSeniorRatio must be true
        uint maxSeniorRatio = 0.8 * 10**27;
        poolAdmin.setMaxSeniorRatio(maxSeniorRatio);

        uint minSeniorRatio = 0.2 * 10**27;
        poolAdmin.setMinSeniorRatio(minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testAutoheal() public {
        poolAdmin.closePool();
        poolAdmin.closePool();
    }

    function testSetMinSeniorRatio() public {
        setMinSeniorRatio(); 
    }

    function testSetMaxAutoHeal() public {
        uint autoHeal = 50000000000000000000;
        poolAdmin.setMaxAutoHeal(autoHeal);
        assertEq(lending.values_uint("file_value"), autoHeal);
        assertEq(lending.values_bytes32("file_name"),"autoHealMax");
    }

    function setMaxSeniorRatio() public {
        uint maxSeniorRatio = 0.8 * 10**27;
        poolAdmin.setMaxSeniorRatio(maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);
    }

    function testSetMaxSeniorRatio() public {
        setMaxSeniorRatio(); 
    }

    function setEpochScoringWeights() public {
        poolAdmin.setEpochScoringWeights(2000, 200, 20, 2);
        assertEq(coordinator.values_bytes32("file_name"), "weightSeniorSupply");
        assertEq(coordinator.values_uint("file_value"), 2);
    }

    function testSetEpochScoringWeights() public {
        setEpochScoringWeights(); 
    }

    function testClosePool() public {
        poolAdmin.closePool();
        assertEq(coordinator.values_bytes32("file_name"), "poolClosing");
        assertEq(coordinator.values_uint("file_value"), 1);
    }

    function testUnclosePool() public {
        poolAdmin.closePool();
        assertEq(coordinator.values_bytes32("file_name"), "poolClosing");
        assertEq(coordinator.values_uint("file_value"), 1);

        poolAdmin.unclosePool();
        assertEq(coordinator.values_bytes32("file_name"), "poolClosing");
        assertEq(coordinator.values_uint("file_value"), 0);
    }

    function testFailUncloseOpenPool() public {
        poolAdmin.deny(address(this));
        poolAdmin.unclosePool();
    }

    function testFailCloseAlreadyClosedPool() public {
        poolAdmin.closePool();
        poolAdmin.closePool();
    }

}

