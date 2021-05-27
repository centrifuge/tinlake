// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "../../deployer.sol";

interface ClerkFabLike {
    function newClerk(address dai, address collateral) external returns (address);
}

contract MKRLenderDeployer is LenderDeployer {
    ClerkFabLike public clerkFab;
    address public clerk;

    address mkrDeployer;

    address public mkrMgr;
    address public mkrVat;
    address public mkrSpotter;
    address public mkrJug;

    constructor(address root_, address currency_, address trancheFab_, address memberlistFab_,
        address restrictedtokenFab_, address reserveFab_, address assessorFab_, address coordinatorFab_,
        address operatorFab_, address assessorAdminFab_, address clerkFabLike_)
            public LenderDeployer(root_, currency_, trancheFab_, memberlistFab_,
        restrictedtokenFab_, reserveFab_, assessorFab_, coordinatorFab_, operatorFab_, assessorAdminFab_) {

        clerkFab = ClerkFabLike(clerkFabLike_);
        mkrDeployer = msg.sender;
    }

    function deployClerk() public {
        require(seniorToken != address(0));
        clerk = clerkFab.newClerk(currency, seniorToken);
        AuthLike(clerk).rely(root);
    }


    function initMKR(address mkrMgr_, address mkrSpotter_, address mkrVat_, address mkrJug_) public {
        require(mkrDeployer == msg.sender);
        mkrMgr = mkrMgr_;
        mkrSpotter = mkrSpotter_;
        mkrVat = mkrVat_;
        mkrJug = mkrJug_;
        mkrDeployer = address(1);
    }

    function deploy() public override {
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
        DependLike(clerk).depend("jug", mkrJug);

        // clerk as ward
        AuthLike(seniorTranche).rely(clerk);
        AuthLike(reserve).rely(clerk);
        AuthLike(assessor).rely(clerk);

        // reserve can draw and wipe on clerk
        AuthLike(clerk).rely(reserve);

        // allow clerk to hold seniorToken
        MemberlistLike(seniorMemberlist).updateMember(clerk, type(uint256).max);
        MemberlistLike(seniorMemberlist).updateMember(mkrMgr, type(uint256).max);

        DependLike(assessor).depend("lending", clerk);

    }
}

