// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { ClerkFabLike } from "../fabs/interfaces.sol";
interface LenderDeployerLike {
    function coordinator() external returns (address);
    function assessor() external returns (address);
    function reserve() external returns (address);
    function seniorOperator() external returns (address);
    function seniorTranche() external returns (address);
    function seniorToken() external returns (address);
    function currency() external returns (address);
    function poolAdmin() external returns (address);
    function seniorMemberlist() external returns (address);
}

interface PoolAdminLike {
    function rely(address) external;
    function relyAdmin(address) external;
}

interface FileLike {
    function file(bytes32 name, uint value) external;
}

interface MemberlistLike {
    function updateMember(address, uint) external;
}

interface MgrLike {
    function rely(address) external;
    function file(bytes32 name, address value) external;
    function lock(uint) external;
}

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface DependLike {
    function depend(bytes32, address) external;
}

contract AdapterDeployer {
    ClerkFabLike public clerkFab;
    address public clerk;

    address mkrDeployer;

    address public root;
    LenderDeployerLike public lenderDeployer;

    address public mgr;
    address public mkrVat;
    address public mkrSpotter;
    address public mkrJug;
    address public mkrUrn;
    address public mkrLiq;
    address public mkrEnd;

    uint public matBuffer;
    bool public wired;

    constructor(address root_, address clerkFabLike_) {
      root = root_;
      clerkFab = ClerkFabLike(clerkFabLike_);
      mkrDeployer = msg.sender;
    }

    function deployClerk() public {
        require(lenderDeployer.seniorToken() != address(0));
        clerk = clerkFab.newClerk(lenderDeployer.currency(), lenderDeployer.seniorToken());

        address assessor = lenderDeployer.assessor();
        address reserve = lenderDeployer.reserve();
        address seniorTranche = lenderDeployer.seniorTranche();
        address seniorMemberlist = lenderDeployer.seniorMemberlist();
        address poolAdmin = lenderDeployer.poolAdmin();
        // clerk dependencies
        DependLike(clerk).depend("coordinator", lenderDeployer.coordinator());
        DependLike(clerk).depend("assessor", assessor);
        DependLike(clerk).depend("reserve", reserve);
        DependLike(clerk).depend("tranche", seniorTranche);
        DependLike(clerk).depend("collateral", lenderDeployer.seniorToken());
        DependLike(clerk).depend("mgr", mgr);
        DependLike(clerk).depend("spotter", mkrSpotter);
        DependLike(clerk).depend("vat", mkrVat);
        DependLike(clerk).depend("jug", mkrJug);
        // clerk as ward
        AuthLike(seniorTranche).rely(clerk);
        AuthLike(reserve).rely(clerk);
        AuthLike(assessor).rely(clerk);

        // reserve can draw and wipe on clerk
        DependLike(reserve).depend("lending", clerk);
        AuthLike(clerk).rely(reserve);

        // set the mat buffer
        FileLike(clerk).file("buffer", matBuffer);

        // allow clerk to hold seniorToken
        MemberlistLike(seniorMemberlist).updateMember(clerk, type(uint256).max);
        MemberlistLike(seniorMemberlist).updateMember(mgr, type(uint256).max);

        DependLike(assessor).depend("lending", clerk);

        // poolAdmin setup
        DependLike(poolAdmin).depend("lending", clerk);
        AuthLike(clerk).rely(poolAdmin);

        AuthLike(clerk).rely(root);
        AuthLike(clerk).deny(address(this));
    }

    function initMKR(address lenderDeployer_, address mgr_, address mkrSpotter_, address mkrVat_, address mkrJug_, address mkrUrn_, address mkrLiq_, address mkrEnd_, uint matBuffer_) public {
        require(mkrDeployer == msg.sender);
        lenderDeployer = LenderDeployerLike(lenderDeployer_);
        mgr = mgr_;
        mkrSpotter = mkrSpotter_;
        mkrVat = mkrVat_;
        mkrJug = mkrJug_;
        mkrUrn = mkrUrn_;
        mkrLiq = mkrLiq_;
        mkrEnd = mkrEnd_;
        matBuffer = matBuffer_;
        mkrDeployer = address(1);
    }

    function wireAdapter() public {
        require(!wired, "adapter already wired"); // make sure adapter only wired once
        wired = true;
        // setup mgr
        MgrLike mkrMgr = MgrLike(mgr);
        mkrMgr.rely(clerk);
        mkrMgr.file("urn", mkrUrn);
        mkrMgr.file("liq", mkrLiq);
        mkrMgr.file("end", mkrEnd);
        mkrMgr.file("owner", clerk);
        mkrMgr.file("pool", lenderDeployer.seniorOperator());
        mkrMgr.file("tranche", lenderDeployer.seniorTranche());
        // lock token
        mkrMgr.lock(1 ether);
    }
}

