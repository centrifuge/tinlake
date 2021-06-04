// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { ReserveFabLike, AssessorFabLike, TrancheFabLike, CoordinatorFabLike, OperatorFabLike, MemberlistFabLike, RestrictedTokenFabLike, PoolAdminFabLike, ClerkFabLike } from "./fabs/interfaces.sol";

import {FixedPoint}      from "./../fixed_point.sol";


interface DependLike {
    function depend(bytes32, address) external;
}

interface AuthLike {
    function rely(address) external;
    function deny(address) external;
}

interface MemberlistLike {
    function updateMember(address, uint) external;
}

interface FileLike {
    function file(bytes32 name, uint value) external;
}

interface RootLike {
    function governance() external returns (address);
}

contract LenderDeployer is FixedPoint {
    address public root;
    address public currency;
    address public governance;
    address public memberAdmin;

    // factory contracts
    TrancheFabLike          public trancheFab;
    ReserveFabLike          public reserveFab;
    AssessorFabLike         public assessorFab;
    CoordinatorFabLike      public coordinatorFab;
    OperatorFabLike         public operatorFab;
    MemberlistFabLike       public memberlistFab;
    RestrictedTokenFabLike  public restrictedTokenFab;
    PoolAdminFabLike        public poolAdminFab;
    ClerkFabLike            public clerkFab;

    // lender state variables
    Fixed27             public minSeniorRatio;
    Fixed27             public maxSeniorRatio;
    uint                public maxReserve;
    uint                public challengeTime;
    uint                public matBuffer;
    Fixed27             public seniorInterestRate;


    // contract addresses
    address             public assessor;
    address             public poolAdmin;
    address             public seniorTranche;
    address             public juniorTranche;
    address             public seniorOperator;
    address             public juniorOperator;
    address             public reserve;
    address             public coordinator;

    address             public seniorToken;
    address             public juniorToken;

    // token names
    string              public seniorName;
    string              public seniorSymbol;
    string              public juniorName;
    string              public juniorSymbol;
    // restricted token member list
    address             public seniorMemberlist;
    address             public juniorMemberlist;

    // mkr adapter
    address             public clerk;

    address             public deployer;

    constructor(address root_, address currency_, address trancheFab_, address memberlistFab_, address restrictedtokenFab_, address reserveFab_, address assessorFab_, address coordinatorFab_, address operatorFab_, address poolAdminFab_, address memberAdmin_, address clerkFab_) {
        deployer = msg.sender;
        root = root_;
        currency = currency_;
        memberAdmin = memberAdmin_;

        trancheFab = TrancheFabLike(trancheFab_);
        memberlistFab = MemberlistFabLike(memberlistFab_);
        restrictedTokenFab = RestrictedTokenFabLike(restrictedtokenFab_);
        reserveFab = ReserveFabLike(reserveFab_);
        assessorFab = AssessorFabLike(assessorFab_);
        poolAdminFab = PoolAdminFabLike(poolAdminFab_);
        coordinatorFab = CoordinatorFabLike(coordinatorFab_);
        operatorFab = OperatorFabLike(operatorFab_);
        clerkFab = ClerkFabLike( clerkFab_);
    }

    function init(uint minSeniorRatio_, uint maxSeniorRatio_, uint maxReserve_, uint challengeTime_, uint seniorInterestRate_, string memory seniorName_, string memory seniorSymbol_, string memory juniorName_, string memory juniorSymbol_, uint matBuffer_) public {
        require(msg.sender == deployer);
        challengeTime = challengeTime_;
        minSeniorRatio = Fixed27(minSeniorRatio_);
        maxSeniorRatio = Fixed27(maxSeniorRatio_);
        maxReserve = maxReserve_;
        seniorInterestRate = Fixed27(seniorInterestRate_);

        // token names
        seniorName = seniorName_;
        seniorSymbol = seniorSymbol_;
        juniorName = juniorName_;
        juniorSymbol = juniorSymbol_;

        // mkr
        matBuffer = matBuffer_;

        deployer = address(1);
    }

    function deployJunior() public {
        require(juniorTranche == address(0) && deployer == address(1));
        juniorToken = restrictedTokenFab.newRestrictedToken(juniorName, juniorSymbol);
        juniorTranche = trancheFab.newTranche(currency, juniorToken);
        juniorMemberlist = memberlistFab.newMemberlist();
        juniorOperator = operatorFab.newOperator(juniorTranche);
        AuthLike(juniorMemberlist).rely(root);
        AuthLike(juniorToken).rely(root);
        AuthLike(juniorToken).rely(juniorTranche);
        AuthLike(juniorOperator).rely(root);
        AuthLike(juniorTranche).rely(root);
    }

    function deploySenior() public {
        require(seniorTranche == address(0) && deployer == address(1));
        seniorToken = restrictedTokenFab.newRestrictedToken(seniorName, seniorSymbol);
        seniorTranche = trancheFab.newTranche(currency, seniorToken);
        seniorMemberlist = memberlistFab.newMemberlist();
        seniorOperator = operatorFab.newOperator(seniorTranche);
        AuthLike(seniorMemberlist).rely(root);
        AuthLike(seniorToken).rely(root);
        AuthLike(seniorToken).rely(seniorTranche);
        AuthLike(seniorOperator).rely(root);
        AuthLike(seniorTranche).rely(root);

    }

    function deployReserve() public {
        require(reserve == address(0) && deployer == address(1));
        reserve = reserveFab.newReserve(currency);
        AuthLike(reserve).rely(root);
    }

    function deployAssessor() public {
        require(assessor == address(0) && deployer == address(1));
        assessor = assessorFab.newAssessor();
        AuthLike(assessor).rely(root);
    }

    function deployPoolAdmin() public {
        require(poolAdmin == address(0) && deployer == address(1));
        poolAdmin = poolAdminFab.newPoolAdmin();
        AuthLike(poolAdmin).rely(root);
    }

    function deployCoordinator() public {
        require(coordinator == address(0) && deployer == address(1));
        coordinator = coordinatorFab.newCoordinator(challengeTime);
        AuthLike(coordinator).rely(root);
    }

    function deployClerk() public {
         require(clerk == address(0) && deployer == address(1) && 
         seniorToken != address(0) && currency != address(0));
         clerk = clerkFab.newClerk(currency, seniorToken);
         AuthLike(clerk).rely(root);
    }

    function deploy() public virtual {
        require(coordinator != address(0) && assessor != address(0) &&
                reserve != address(0) && seniorTranche != address(0));

        // required depends
        // reserve
        DependLike(reserve).depend("assessor", assessor);
        AuthLike(reserve).rely(seniorTranche);
        AuthLike(reserve).rely(juniorTranche);
        AuthLike(reserve).rely(coordinator);
        AuthLike(reserve).rely(assessor);


        // tranches
        DependLike(seniorTranche).depend("reserve",reserve);
        DependLike(juniorTranche).depend("reserve",reserve);
        AuthLike(seniorTranche).rely(coordinator);
        AuthLike(juniorTranche).rely(coordinator);
        AuthLike(seniorTranche).rely(seniorOperator);
        AuthLike(juniorTranche).rely(juniorOperator);

        // coordinator implements epoch ticker interface
        DependLike(seniorTranche).depend("coordinator", coordinator);
        DependLike(juniorTranche).depend("coordinator", coordinator);

        //restricted token
        DependLike(seniorToken).depend("memberlist", seniorMemberlist);
        DependLike(juniorToken).depend("memberlist", juniorMemberlist);

        //allow tinlake contracts to hold drop/tin tokens
        MemberlistLike(juniorMemberlist).updateMember(juniorTranche, type(uint256).max);
        MemberlistLike(seniorMemberlist).updateMember(seniorTranche, type(uint256).max);

        // operator
        DependLike(seniorOperator).depend("tranche", seniorTranche);
        DependLike(juniorOperator).depend("tranche", juniorTranche);
        DependLike(seniorOperator).depend("token", seniorToken);
        DependLike(juniorOperator).depend("token", juniorToken);

        // coordinator
        DependLike(coordinator).depend("reserve", reserve);
        DependLike(coordinator).depend("seniorTranche", seniorTranche);
        DependLike(coordinator).depend("juniorTranche", juniorTranche);
        DependLike(coordinator).depend("assessor", assessor);

        // assessor
        DependLike(assessor).depend("seniorTranche", seniorTranche);
        DependLike(assessor).depend("juniorTranche", juniorTranche);
        DependLike(assessor).depend("reserve", reserve);

        AuthLike(assessor).rely(coordinator);
        AuthLike(assessor).rely(reserve);
        AuthLike(assessor).rely(poolAdmin);
        
        // maker contracts
        if (clerk != address(0)) {
            DependLike(clerk).depend("assessor", assessor);
            DependLike(clerk).depend("coordinator", coordinator);
            DependLike(clerk).depend("reserve", reserve); 
            DependLike(clerk).depend("tranche", seniorTranche);
            DependLike(clerk).depend("collateral", seniorToken);
            DependLike(assessor).depend("clerk", clerk); 
            DependLike(reserve).depend("lending", clerk);
            // !!! mkr contracts & mgr dependencies missing 
            // DependLike(clerk).depend("mgr", mgr);
            // DependLike(clerk).depend("spotter", spotter);
            // DependLike(clerk).depend("vat", vat);
            // DependLike(clerk).depend("jug", jug);

            FileLike(clerk).file("buffer", matBuffer);

            AuthLike(clerk).rely(coordinator);
            AuthLike(clerk).rely(reserve);
            AuthLike(seniorTranche).rely(clerk);
            AuthLike(reserve).rely(clerk);
            AuthLike(assessor).rely(clerk);
            MemberlistLike(seniorMemberlist).updateMember(clerk, uint(-1));
        
            // poolAdmin setup
            DependLike(poolAdmin).depend("clerk", clerk);
            AuthLike(clerk).rely(poolAdmin);
        }
     
        // poolAdmin
        DependLike(poolAdmin).depend("assessor", assessor);
        DependLike(poolAdmin).depend("juniorMemberlist", juniorMemberlist);
        DependLike(poolAdmin).depend("seniorMemberlist", seniorMemberlist);
        

        AuthLike(juniorMemberlist).rely(poolAdmin);
        AuthLike(seniorMemberlist).rely(poolAdmin);

        if (memberAdmin != address(0)) AuthLike(juniorMemberlist).rely(memberAdmin);
        if (memberAdmin != address(0)) AuthLike(seniorMemberlist).rely(memberAdmin);

        FileLike(assessor).file("seniorInterestRate", seniorInterestRate.value);
        FileLike(assessor).file("maxReserve", maxReserve);
        FileLike(assessor).file("maxSeniorRatio", maxSeniorRatio.value);
        FileLike(assessor).file("minSeniorRatio", minSeniorRatio.value);
    }
}
