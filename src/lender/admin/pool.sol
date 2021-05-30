// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";

interface AssessorLike {
    function file(bytes32 name, uint256 value) external;
}

interface LendingAdapterLike {
    function raise(uint256 amount) external;
    function sink(uint256 amount) external;
    function heal() external;
}

interface MemberlistLike {
    function updateMember(address usr, uint256 validUntil) external;
    function updateMembers(address[] calldata users, uint256 validUntil) external;
}

// Wrapper contract for various pool management tasks.
contract PoolAdmin is Auth {
  
    AssessorLike public assessor;
    LendingAdapterLike public lending;
    MemberlistLike public seniorMemberlist;
    MemberlistLike public juniorMemberlist;

    bool public live = true;

    // Admins can manage pools, but have to be added and can be removed by any ward on the PoolAdmin contract
    mapping(address => uint256) public admins;

    // Events
    event File(bytes32 indexed what, bool indexed data);
    event RelyAdmin(address indexed usr);
    event DenyAdmin(address indexed usr);
    event SetMaxReserve(uint256 value);
    event RaiseCreditline(uint256 amount);
    event SinkCreditline(uint256 amount);
    event HealCreditline();
    event UpdateSeniorMember(address indexed usr, uint256 validUntil);
    event UpdateSeniorMembers(address[] indexed users, uint256 validUntil);
    event UpdateJuniorMember(address indexed usr, uint256 validUntil);
    event UpdateJuniorMembers(address[] indexed users, uint256 validUntil);

    constructor() public {
        wards[msg.sender] = 1;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "lending") {
            lending = LendingAdapterLike(addr);
        } else if (contractName == "seniorMemberlist") {
            seniorMemberlist = MemberlistLike(addr);
        } else if (contractName == "juniorMemberlist") {
            juniorMemberlist = MemberlistLike(addr);
        } else revert();
    }

    function file(bytes32 what, bool data) public auth {
        live = data;
        emit File(what, data);
    }

    modifier admin { require(admins[msg.sender] == 1 && live); _; }

    function relyAdmin(address usr) public auth {
        admins[usr] = 1;
        emit RelyAdmin(usr);
    }

    function denyAdmin(address usr) public auth {
        admins[usr] = 0;
        emit DenyAdmin(usr);
    }

    // Manage max reserve
    function setMaxReserve(uint256 value) public admin {
        assessor.file("maxReserve", value);
        emit SetMaxReserve(value);
    }

    // Manage creditline
    function raiseCreditline(uint256 amount) public admin {
        lending.raise(amount);
        emit RaiseCreditline(amount);
    }

    function sinkCreditline(uint256 amount) public admin {
        lending.sink(amount);
        emit SinkCreditline(amount);
    }

    function healCreditline() public admin {
        lending.heal();
        emit HealCreditline();
    }

    function setMaxReserveAndRaiseCreditline(uint256 newMaxReserve, uint256 creditlineRaise) public admin {
        setMaxReserve(newMaxReserve);
        raiseCreditline(creditlineRaise);
    }

    function setMaxReserveAndSinkCreditline(uint256 newMaxReserve, uint256 creditlineSink) public admin {
        setMaxReserve(newMaxReserve);
        sinkCreditline(creditlineSink);
    }

    // Manage memberlists
    function updateSeniorMember(address usr, uint256 validUntil) public admin {
        seniorMemberlist.updateMember(usr, validUntil);
        emit UpdateSeniorMember(usr, validUntil);
    }

    function updateSeniorMembers(address[] memory users, uint256 validUntil) public admin {
        seniorMemberlist.updateMembers(users, validUntil);
        emit UpdateSeniorMembers(users, validUntil);
    }

    function updateJuniorMember(address usr, uint256 validUntil) public admin {
        juniorMemberlist.updateMember(usr, validUntil);
        emit UpdateJuniorMember(usr, validUntil);
    }

    function updateJuniorMembers(address[] memory users, uint256 validUntil) public admin {
        juniorMemberlist.updateMembers(users, validUntil);
        emit UpdateJuniorMembers(users, validUntil);
    }
    
}
