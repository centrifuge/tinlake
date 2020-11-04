// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity >=0.5.15 <0.6.0;

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

interface AssessorAdminFabLike {
    function newAssessorAdmin() external returns (address);
}


