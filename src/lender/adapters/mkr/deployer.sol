// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "../../deployer.sol";

interface MgrLike {
    function file(bytes32 name, address value) external;
    function lock(uint) external;
}

contract MKRLenderDeployer is LenderDeployer {
    ClerkFabLike public clerkFab;
    address public clerk;

    address mkrDeployer;

    address public mkrMgr;
    address public mkrVat;
    address public mkrSpotter;
    address public mkrJug;
    address public mkrUrn;
    address public mkrLiq;
    address public mkrEnd;
    uint public matBuffer;

    constructor(address root_, address currency_, address trancheFab_, address memberlistFab_,
        address restrictedtokenFab_, address reserveFab_, address assessorFab_, address coordinatorFab_,
        address operatorFab_, address poolAdminFab_, address clerkFabLike_, address memberAdmin_)
         LenderDeployer(root_, currency_, trancheFab_, memberlistFab_,
        restrictedtokenFab_, reserveFab_, assessorFab_, coordinatorFab_, operatorFab_, poolAdminFab_, memberAdmin_) {

        clerkFab = ClerkFabLike(clerkFabLike_);
        mkrDeployer = msg.sender;
    }

    function deployClerk() public {
        require(seniorToken != address(0));
        clerk = clerkFab.newClerk(currency, seniorToken);
        AuthLike(clerk).rely(root);
    }

    function initMKR(address mkrMgr_, address mkrSpotter_, address mkrVat_, address mkrJug_, address mkrUrn_, address mkrLiq_, address mkrEnd_, uint matBuffer_) public {
        require(mkrDeployer == msg.sender);
        mkrMgr = mkrMgr_;
        mkrSpotter = mkrSpotter_;
        mkrVat = mkrVat_;
        mkrJug = mkrJug_;
        mkrUrn = mkrUrn_;
        mkrLiq = mkrLiq_;
        mkrEnd = mkrEnd_;
        matBuffer = matBuffer_;
        mkrDeployer = address(1);
    }

    function deploy() public override {
        super.deploy();
    }

}

