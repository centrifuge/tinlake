// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "ds-test/test.sol";

import "./../assessor.sol";
import "./../admin/pool.sol";
import "./mock/memberlist.sol";
import "./mock/clerk.sol";

contract PoolAdminTest is DSTest {

    Assessor assessor;
    ClerkMock lending;
    MemberlistMock seniorMemberlist;
    MemberlistMock juniorMemberlist;
    PoolAdmin poolAdmin;

    address[] users;

    function setUp() public {
        assessor = new Assessor();
        lending = new ClerkMock();
        seniorMemberlist = new MemberlistMock();
        juniorMemberlist = new MemberlistMock();
        poolAdmin = new PoolAdmin();

        assessor.rely(address(poolAdmin));
        lending.rely(address(poolAdmin));
        seniorMemberlist.rely(address(poolAdmin));
        juniorMemberlist.rely(address(poolAdmin));

        poolAdmin.depend("assessor", address(assessor));
        poolAdmin.depend("lending", address(lending));
        poolAdmin.depend("seniorMemberlist", address(seniorMemberlist));
        poolAdmin.depend("juniorMemberlist", address(juniorMemberlist));

        users = new address[](3);
        users[0] = address(1);
        users[1] = address(2);
        users[2] = address(3);
    }

    // Test setting max reserve
    function callMaxReserve() public {
        uint maxReserve = 150 ether;
        
        poolAdmin.setMaxReserve(maxReserve);
        assertEq(assessor.maxReserve(), maxReserve);
    }

    function testSetMaxReserve() public {
        poolAdmin.relyAdmin(address(this));
        callMaxReserve(); 
    }

    function testFailSetMaxReserveNotAdmin() public {
        callMaxReserve(); 
    }

    // Test lending adapter
    function callRaiseCreditline() public {
        uint amount = 100 ether;
        poolAdmin.raiseCreditline(amount);

        assertEq(lending.values_uint("clerk_raise_amount"), amount);
    }

    function testRaiseCreditline() public {
        poolAdmin.relyAdmin(address(this));
        callRaiseCreditline();
    }

    function testFailRaiseCreditlineNotAdmin() public {
        callRaiseCreditline();
    }

    function callSinkCreditline() public {
        uint amount = 100 ether;
        poolAdmin.sinkCreditline(amount);

        assertEq(lending.values_uint("clerk_sink_amount"), amount);
    }

    function testSinkCreditline() public {
        poolAdmin.relyAdmin(address(this));
        callSinkCreditline();
    }

    function testFailSinkCreditlineNotAdmin() public {
        callSinkCreditline();
    }

    function testHealCreditline() public {
        poolAdmin.relyAdmin(address(this));
        poolAdmin.healCreditline();

        assertEq(lending.calls("heal"), 1);
    }

    function testFailHealCreditline() public {
        poolAdmin.healCreditline();
    }

    // Test senior memberlist
    function updateSeniorMember() public {
        address usr = address(1);
        uint validUntil = now + 365 days;
        poolAdmin.updateSeniorMember(usr, validUntil);

        assertEq(seniorMemberlist.calls("updateMember"), 1);
        assertEq(seniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(seniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateSeniorMemberAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateSeniorMember();
    }

    function testFailUpdateSeniorMemberAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateSeniorMember();
    }

    function updateSeniorMembers() public {
        uint validUntil = now + 365 days;
        poolAdmin.updateSeniorMembers(users, validUntil);

        assertEq(seniorMemberlist.calls("updateMembers"), 1);
        assertEq(seniorMemberlist.values_address("updateMember_usr"), users[users.length]);
        assertEq(seniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateSeniorMembersAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateSeniorMember();
    }

    function testFailUpdateSeniorMembersAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateSeniorMember();
    }

    // Test junior memberlist
    function updateJuniorMember() public {
        address usr = address(1);
        uint validUntil = now + 365 days;
        poolAdmin.updateJuniorMember(usr, validUntil);

        assertEq(juniorMemberlist.calls("updateMember"), 1);
        assertEq(juniorMemberlist.values_address("updateMember_usr"), usr);
        assertEq(juniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateJuniorMemberAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateJuniorMember();
    }

    function testFailUpdateJuniorMemberAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateJuniorMember();
    }

    function updateJuniorMembers() public {
        uint validUntil = now + 365 days;
        poolAdmin.updateJuniorMembers(users, validUntil);

        assertEq(juniorMemberlist.calls("updateMembers"), 1);
        assertEq(juniorMemberlist.values_address("updateMember_usr"), users[users.length]);
        assertEq(juniorMemberlist.values_uint("updateMember_validUntil"), validUntil);
    }

    function testUpdateJuniorMembersAsAdmin() public {
        poolAdmin.relyAdmin(address(this));
        updateJuniorMember();
    }

    function testFailUpdateJuniorMembersAsNonAdmin() public {
        poolAdmin.denyAdmin(address(this));
        updateJuniorMember();
    }

}

