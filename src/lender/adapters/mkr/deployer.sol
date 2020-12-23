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

import "../../deployer.sol";

interface ClerkFabLike {
    function newClerk(address dai, address collateral) external returns (address);
}

contract MKRLenderDeployer is LenderDeployer {
    ClerkFabLike public clerkFab;
    address public clerk;

    address public mkrMgr;
    address public mkrVat;
    address public mkrSpotter;

    constructor(address root_, address currency_, address trancheFab_, address memberlistFab_,
        address restrictedtokenFab_, address reserveFab_, address assessorFab_, address coordinatorFab_,
        address operatorFab_, address assessorAdminFab_, address clerkFabLike_)
            public LenderDeployer(root_, currency_, trancheFab_, memberlistFab_,
        restrictedtokenFab_, reserveFab_, assessorFab_, coordinatorFab_, operatorFab_, assessorAdminFab_) {

        clerkFab = ClerkFabLike(clerkFabLike_);
    }

    function deployClerk() public {
        require(seniorToken != address(0));
        clerk = clerkFab.newClerk(currency, seniorToken);
        AuthLike(clerk).rely(root);
    }

    function init(uint minSeniorRatio_, uint maxSeniorRatio_, uint maxReserve_, uint challengeTime_, uint seniorInterestRate_,
        string memory seniorName_, string memory seniorSymbol_, string memory juniorName_, string memory juniorSymbol_,
        address mkrMgr_, address mkrSpotter_, address mkrVat_) public {
        super.init(minSeniorRatio_, maxSeniorRatio_, maxReserve_,
                challengeTime_, seniorInterestRate_, seniorName_, seniorSymbol_, juniorName_, juniorSymbol_);

        mkrMgr = mkrMgr_;
        mkrSpotter = mkrSpotter_;
        mkrVat = mkrVat_;
    }

    function deploy() public {
        super.deploy();
        require(clerk != address(0));

        // clerk dependencies
        DependLike(clerk).depend("coordinator", coordinator);
        DependLike(clerk).depend("assessor", assessor);
        DependLike(clerk).depend("reserve", reserve);
        DependLike(clerk).depend("tranche", seniorTranche);
        DependLike(clerk).depend("mgr", mkrMgr);
        DependLike(clerk).depend("spotter", mkrSpotter);
        DependLike(clerk).depend("vat", mkrVat);

        // clerk as ward
        AuthLike(seniorTranche).rely(clerk);
        AuthLike(reserve).rely(clerk);
        AuthLike(assessor).rely(clerk);
        // allow clerk to hold seniorToken
        MemberlistLike(seniorMemberlist).updateMember(clerk, uint(-1));
        MemberlistLike(seniorMemberlist).updateMember(mkrMgr, uint(-1));

        DependLike(assessor).depend("clerk", clerk);

    }
}

