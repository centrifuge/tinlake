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
    function assessor() external returns (address);
    function reserve() external returns (address);
    function poolAdmin() external returns (address);
}

interface AdapterDeployerLike {
    function mgr() external returns (address);
    function wireAdapter() external;
}

interface PoolAdminLike {
    function rely(address) external;
    function relyAdmin(address) external;
}

contract TinlakeRoot is Auth {
    BorrowerDeployerLike public borrowerDeployer;
    LenderDeployerLike public  lenderDeployer;
    AdapterDeployerLike public  adapterDeployer;

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
    function prepare(address lender_, address borrower_, address adapter_, address oracle_, address[] memory poolAdmins_) public {
        require(deployUsr == msg.sender);
        
        borrowerDeployer = BorrowerDeployerLike(borrower_);
        lenderDeployer = LenderDeployerLike(lender_);
        if (adapter_ != address(0)) adapterDeployer = AdapterDeployerLike(adapter_);
        oracle = oracle_;
        poolAdmins = poolAdmins_;

        deployUsr = address(0); // disallow the deploy user to call this more than once.
    }

    function prepare(address lender_, address borrower_) public {
        prepare(lender_, borrower_, address(0), address(0), new address[](0));
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
