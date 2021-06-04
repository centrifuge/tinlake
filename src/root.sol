// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface DependLike {
    function depend(bytes32, address) external;
}

interface BorrowerDeployerLike {
    function collector() external returns (address);
    function feed() external returns (address);
    function shelf() external returns (address);
    function title() external returns (address);
}

interface LenderDeployerLike {
    function coordinator() external returns (address);
    function assessor() external returns (address);
    function reserve() external returns (address);
    function seniorOperator() external returns (address);
    function seniorTranche() external returns (address);
    function seniorToken() external returns (address);
    function clerk() external returns (address);
    function matBuffer() external returns (uint);
    function poolAdmin() external returns (address);
    function seniorMemberlist() external returns (address);
    function mkrMgr() external returns (address);
    function mkrSpotter() external returns (address);
    function mkrVat() external returns (address);
    function mkrJug() external returns (address);
    function mkrUrn() external returns (address);
    function mkrLiq() external returns (address);
    function mkrEnd() external returns (address);

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

contract TinlakeRoot is Auth {
    BorrowerDeployerLike public borrowerDeployer;
    LenderDeployerLike public  lenderDeployer;

    bool public             deployed;
    address public          deployUsr;
    address public          governance;

    address public          oracle;
    address[] public        poolAdmins;

    constructor (address deployUsr_, address governance_) {
        deployUsr = deployUsr_;
        governance = governance_;
        wards[governance] = 1;
    }

    // --- Prepare ---
    // Sets the two deployer dependencies. This needs to be called by the deployUsr
    function prepare(address lender_, address borrower_, address oracle_, address[] memory poolAdmins_) public {
        require(deployUsr == msg.sender);
        
        borrowerDeployer = BorrowerDeployerLike(borrower_);
        lenderDeployer = LenderDeployerLike(lender_);
        oracle = oracle_;
        poolAdmins = poolAdmins_;

        deployUsr = address(0); // disallow the deploy user to call this more than once.
    }

    function prepare(address lender_, address borrower_) public {
        prepare(lender_, borrower_, address(0), new address[](0));
    }

    // --- Deploy ---
    // After going through the deploy process on the lender and borrower method, this method is called to connect
    // lender and borrower contracts.
    function deploy() public {
        require(address(borrowerDeployer) != address(0) && address(lenderDeployer) != address(0) && deployed == false);
        deployed = true;

        address reserve_ = lenderDeployer.reserve();
        address shelf_ = borrowerDeployer.shelf();

        // Borrower depends
        DependLike(borrowerDeployer.collector()).depend("reserve", reserve_);
        DependLike(borrowerDeployer.shelf()).depend("lender", reserve_);
        DependLike(borrowerDeployer.shelf()).depend("reserve", reserve_);

        // Lender depends
        address navFeed = borrowerDeployer.feed();

        DependLike(reserve_).depend("shelf", shelf_);
        DependLike(lenderDeployer.assessor()).depend("navFeed", navFeed);

        // Lender wards
        if (oracle != address(0)) AuthLike(navFeed).rely(oracle);

        // directly relying governance so it can be used to directly add/remove pool admins without going through the root
        PoolAdminLike poolAdmin = PoolAdminLike(lenderDeployer.poolAdmin());
        PoolAdminLike(poolAdmin).rely(governance);

        for (uint i = 0; i < poolAdmins.length; i++) {
            PoolAdminLike(poolAdmin).relyAdmin(poolAdmins[i]);
        }

        if (lenderDeployer.clerk() != address(0)) {
            setupMkr();
        }
    }

    function setupMkr() internal {
        address clerk = lenderDeployer.clerk();
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
        DependLike(clerk).depend("mgr", lenderDeployer.mkrMgr());
        DependLike(clerk).depend("spotter", lenderDeployer.mkrSpotter());
        DependLike(clerk).depend("vat", lenderDeployer.mkrVat());
        DependLike(clerk).depend("jug", lenderDeployer.mkrJug());

        // clerk as ward
        AuthLike(seniorTranche).rely(clerk);
        AuthLike(reserve).rely(clerk);
        AuthLike(assessor).rely(clerk);

        // reserve can draw and wipe on clerk
        DependLike(reserve).depend("lending", clerk);
        AuthLike(clerk).rely(reserve);

        // set the mat buffer
        FileLike(clerk).file("buffer", lenderDeployer.matBuffer());

        // allow clerk to hold seniorToken
        MemberlistLike(seniorMemberlist).updateMember(clerk, type(uint256).max);
        MemberlistLike(seniorMemberlist).updateMember(lenderDeployer.mkrMgr(), type(uint256).max);

        DependLike(assessor).depend("lending", clerk);

        // poolAdmin setup
        DependLike(poolAdmin).depend("lending", clerk);
        AuthLike(clerk).rely(poolAdmin);

        // setup mgr
        MgrLike mgr = MgrLike(lenderDeployer.mkrMgr());
        mgr.rely(clerk);
        mgr.file("urn", lenderDeployer.mkrUrn());
        mgr.file("liq", lenderDeployer.mkrLiq());
        mgr.file("end", lenderDeployer.mkrEnd());
        mgr.file("owner", lenderDeployer.clerk());
        mgr.file("pool", lenderDeployer.seniorOperator());
        mgr.file("tranche", lenderDeployer.seniorTranche());

        // lock token
        mgr.lock(1 ether);
    }
    
    // --- Governance Functions ---
    // `relyContract` & `denyContract` can be called by any ward on the TinlakeRoot
    // contract to make an arbitrary address a ward on any contract the TinlakeRoot
    // is a ward on.
    function relyContract(address target, address usr) public auth {
        AuthLike(target).rely(usr);
    }

    function denyContract(address target, address usr) public auth {
        AuthLike(target).deny(usr);
    }

}
