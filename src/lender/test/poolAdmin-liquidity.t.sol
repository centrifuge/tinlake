// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./mock/coordinator.sol";
import "./mock/navFeed.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract LiquidityManagementPoolAdminTest is DSTest {

    Assessor assessor;
    ClerkMock lending;
    MemberlistMock seniorMemberlist;
    MemberlistMock juniorMemberlist;
    CoordinatorMock coordinator;
    NAVFeedMock navFeed;
    PoolAdmin poolAdmin;

    address[] users;

    function setUp() public {
        assessor = new Assessor();
        lending = new ClerkMock();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        coordinator = new CoordinatorMock();
        navFeed = new NAVFeedMock();
        poolAdmin = new PoolAdmin();
        poolAdmin.relyLevel2(address(this)); // required to call relyLevel1()

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

        users = new address[](3);
        users[0] = address(1);
        users[1] = address(2);
        users[2] = address(3);
    }

    function callMaxReserve() public {
        uint maxReserve = 150 ether;
        
        poolAdmin.setMaxReserve(maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);
    }

    function testSetMaxReserve() public {
        poolAdmin.relyLevel1(address(this));
        callMaxReserve(); 
    }

    function testFailSetMaxReserveNotManager() public {
        callMaxReserve(); 
    }

    function callRaiseCreditline() public {
        uint amount = 100 ether;
        poolAdmin.raiseCreditline(amount);

        assertEq(lending.values_uint("clerk_raise_amount"), amount);
    }

    function testRaiseCreditline() public {
        poolAdmin.relyLevel1(address(this));
        callRaiseCreditline();
    }

    function testFailRaiseCreditlineNotManager() public {
        callRaiseCreditline();
    }

    function callSinkCreditline() public {
        uint amount = 100 ether;
        poolAdmin.sinkCreditline(amount);

        assertEq(lending.values_uint("clerk_sink_amount"), amount);
    }

    function testSinkCreditline() public {
        poolAdmin.relyLevel1(address(this));
        callSinkCreditline();
    }

    function testFailSinkCreditlineNotManager() public {
        callSinkCreditline();
    }

    function testHealCreditline() public {
        poolAdmin.relyLevel1(address(this));
        poolAdmin.healCreditline();

        assertEq(lending.calls("heal"), 1);
    }

    function testFailHealCreditline() public {
        poolAdmin.healCreditline();
    }

    function testSetMaxReserveAndRaiseCreditline() public {
        poolAdmin.relyLevel1(address(this));

        uint maxReserve = 150 ether;
        uint amount = 100 ether;
        poolAdmin.setMaxReserveAndRaiseCreditline(maxReserve, amount);

        assertEq(assessor.maxReserve(), maxReserve);
        assertEq(lending.values_uint("clerk_raise_amount"), amount);
    }

    function testSetMaxReserveAndSinkCreditline() public {
        poolAdmin.relyLevel1(address(this));

        uint maxReserve = 150 ether;
        uint amount = 100 ether;
        poolAdmin.setMaxReserveAndSinkCreditline(maxReserve, amount);

        assertEq(assessor.maxReserve(), maxReserve);
        assertEq(lending.values_uint("clerk_sink_amount"), amount);
    }

    function updateSeniorMember() public {
        address usr = address(1);
        uint validUntil = block.timestamp + 365 days;
        poolAdmin.updateSeniorMember(usr, validUntil);

        assertEq(seniorMemberlist.calls("updateMember"), 1);
        assertEq(seniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(seniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateSeniorMemberAsAdmin() public {
        poolAdmin.relyLevel1(address(this));
        updateSeniorMember();
    }

    function testFailUpdateSeniorMemberAsNonAdmin() public {
        poolAdmin.denyLevel1(address(this));
        updateSeniorMember();
    }

    function updateSeniorMembers() public {
        uint validUntil = block.timestamp + 365 days;
        poolAdmin.updateSeniorMembers(users, validUntil);

        assertEq(seniorMemberlist.calls("updateMembers"), 1);
        assertEq(seniorMemberlist.values_address("updateMembers_usr"), address(3));
        assertEq(seniorMemberlist.values_uint("updateMembers_validUntil"), validUntil);
    }

    function testUpdateSeniorMembersAsAdmin() public {
        poolAdmin.relyLevel1(address(this));
        updateSeniorMembers();
    }

    function testFailUpdateSeniorMembersAsNonAdmin() public {
        poolAdmin.denyLevel1(address(this));
        updateSeniorMembers();
    }

    function updateJuniorMember() public {
        address usr = address(1);
        uint validUntil = block.timestamp + 365 days;
        poolAdmin.updateJuniorMember(usr, validUntil);

        assertEq(juniorMemberlist.calls("updateMember"), 1);
        assertEq(juniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(juniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateJuniorMemberAsAdmin() public {
        poolAdmin.relyLevel1(address(this));
        updateJuniorMember();
    }

    function testFailUpdateJuniorMemberAsNonAdmin() public {
        poolAdmin.denyLevel1(address(this));
        updateJuniorMember();
    }

    function updateJuniorMembers() public {
        uint validUntil = block.timestamp + 365 days;
        poolAdmin.updateJuniorMembers(users, validUntil);

        assertEq(juniorMemberlist.calls("updateMembers"), 1);
        assertEq(juniorMemberlist.values_address("updateMembers_usr"), address(3));
        assertEq(juniorMemberlist.values_uint("updateMembers_validUntil"), validUntil);
    }

    function testUpdateJuniorMembersAsAdmin() public {
        poolAdmin.relyLevel1(address(this));
        updateJuniorMembers();
    }

    function testFailUpdateJuniorMembersAsNonAdmin() public {
        poolAdmin.denyLevel1(address(this));
        updateJuniorMembers();
    }

}

