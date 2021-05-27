// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

interface ReserveFabLike {
    function newReserve(address) external returns (address);
}

interface AssessorFabLike {
    function newAssessor() external returns (address);
}

interface TrancheFabLike {
    function newTranche(address, address) external returns (address);
}

interface CoordinatorFabLike {
    function newCoordinator(uint) external returns (address);
}

interface OperatorFabLike {
    function newOperator(address) external returns (address);
}

interface MemberlistFabLike {
    function newMemberlist() external returns (address);
}

interface RestrictedTokenFabLike {
    function newRestrictedToken(string calldata, string calldata) external returns (address);
}

interface PoolAdminFabLike {
    function newPoolAdmin() external returns (address);
}


