// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./mock/coordinator.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract WardPoolAdminTest is DSTest {

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

    function fileSeniorInterestRate() public {
        uint seniorInterestRate = 1000000674400000000000000000;
        poolAdmin.fileSeniorInterestRate(seniorInterestRate);
        assertEq(assessor.seniorInterestRate(), seniorInterestRate);
    }

    function testFileSeniorInterestRate() public {
        fileSeniorInterestRate(); 
    }

    function fileDiscountRate() public {
        uint discountRate = 1000000674400000000000000000;
        poolAdmin.fileDiscountRate(discountRate);
        assertEq(navFeed.values_uint("file_value"), discountRate);
    }

    function testFileDiscountRate() public {
        fileDiscountRate(); 
    }

    function fileMinimumEpochTime() public {
        uint minimumEpochTime = 2 days;
        poolAdmin.fileMinimumEpochTime(minimumEpochTime);
        assertEq(coordinator.values_uint("file_value"), minimumEpochTime);
    }

    function testFileMinimumEpochTime() public {
        fileMinimumEpochTime(); 
    }

    function fileChallengeTime() public {
        uint challengeTime = 1 hours;
        poolAdmin.fileChallengeTime(challengeTime);
        assertEq(coordinator.values_uint("file_value"), challengeTime);
    }

    function testFileChallengeTime() public {
        fileChallengeTime(); 
    }

    function fileMinSeniorRatio() public {
        // required to call first because minSeniorRatio < maxSeniorRatio must be true
        uint maxSeniorRatio = 0.8 * 10**27;
        poolAdmin.fileMaxSeniorRatio(maxSeniorRatio);

        uint minSeniorRatio = 0.2 * 10**27;
        poolAdmin.fileMinSeniorRatio(minSeniorRatio);
        assertEq(assessor.minSeniorRatio(), minSeniorRatio);
    }

    function testFileMinSeniorRatio() public {
        fileMinSeniorRatio(); 
    }

    function fileMaxSeniorRatio() public {
        uint maxSeniorRatio = 0.8 * 10**27;
        poolAdmin.fileMaxSeniorRatio(maxSeniorRatio);
        assertEq(assessor.maxSeniorRatio(), maxSeniorRatio);
    }

    function testFileMaxSeniorRatio() public {
        fileMaxSeniorRatio(); 
    }

}

