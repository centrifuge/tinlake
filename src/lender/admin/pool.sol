// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

interface AssessorLike {
    function file(bytes32 name, uint256 value) external;
}

interface LendingAdapterLike {
    function raise(uint256 amount) external;
    function sink(uint256 amount) external;
    function heal() external;
}

interface FeedLike {
    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) external;
    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_) external;
    function file(bytes32 name, uint rate_, uint writeOffPercentage_, uint overdueDays_) external;
    function file(bytes32 name, uint value) external;
    function file(bytes32 name, bytes32 nftID_, uint maturityDate_) external;
    function update(bytes32 nftID_,  uint value) external;
    function update(bytes32 nftID_, uint value, uint risk_) external;
}

interface MemberlistLike {
    function updateMember(address usr, uint256 validUntil) external;
    function updateMembers(address[] calldata users, uint256 validUntil) external;
}

interface CoordinatorLike {
    function file(bytes32 name, uint value) external;
}

// Wrapper contract for various pool management tasks.
contract PoolAdmin {
  
    AssessorLike        public assessor;
    LendingAdapterLike  public lending;
    FeedLike            public navFeed;
    MemberlistLike      public seniorMemberlist;
    MemberlistLike      public juniorMemberlist;
    CoordinatorLike     public coordinator;

    bool                public live = true;

    mapping (address => uint256) public managers;
    mapping (address => uint256) public operators;
    mapping (address => uint256) public wards;

    modifier manager    { require(managers[msg.sender] == 1 && live); _; }
    modifier operator   { require(operators[msg.sender] == 1 && live); _; }
    modifier ward       { require(wards[msg.sender] == 1 && live); _; }

    constructor() {
        wards[msg.sender] = 1;
        emit RelyWard(msg.sender);
    }

    // --- Low severity actions, authorized by managers ---
    event SetMaxReserve(uint256 value);
    event RaiseCreditline(uint256 amount);
    event SinkCreditline(uint256 amount);
    event HealCreditline();
    event UpdateSeniorMember(address indexed usr, uint256 validUntil);
    event UpdateSeniorMembers(address[] indexed users, uint256 validUntil);
    event UpdateJuniorMember(address indexed usr, uint256 validUntil);
    event UpdateJuniorMembers(address[] indexed users, uint256 validUntil);

    // Manage max reserve
    function setMaxReserve(uint256 value) public manager {
        assessor.file("maxReserve", value);
        emit SetMaxReserve(value);
    }

    // Manage creditline
    function raiseCreditline(uint256 amount) public manager {
        lending.raise(amount);
        emit RaiseCreditline(amount);
    }

    function sinkCreditline(uint256 amount) public manager {
        lending.sink(amount);
        emit SinkCreditline(amount);
    }

    function healCreditline() public manager {
        lending.heal();
        emit HealCreditline();
    }

    function setMaxReserveAndRaiseCreditline(uint256 newMaxReserve, uint256 creditlineRaise) public manager {
        setMaxReserve(newMaxReserve);
        raiseCreditline(creditlineRaise);
    }

    function setMaxReserveAndSinkCreditline(uint256 newMaxReserve, uint256 creditlineSink) public manager {
        setMaxReserve(newMaxReserve);
        sinkCreditline(creditlineSink);
    }

    // Manage memberlists
    function updateSeniorMember(address usr, uint256 validUntil) public manager {
        seniorMemberlist.updateMember(usr, validUntil);
        emit UpdateSeniorMember(usr, validUntil);
    }

    function updateSeniorMembers(address[] memory users, uint256 validUntil) public manager {
        seniorMemberlist.updateMembers(users, validUntil);
        emit UpdateSeniorMembers(users, validUntil);
    }

    function updateJuniorMember(address usr, uint256 validUntil) public manager {
        juniorMemberlist.updateMember(usr, validUntil);
        emit UpdateJuniorMember(usr, validUntil);
    }

    function updateJuniorMembers(address[] memory users, uint256 validUntil) public manager {
        juniorMemberlist.updateMembers(users, validUntil);
        emit UpdateJuniorMembers(users, validUntil);
    }
    
    // --- Medium severity actions, authorized by operators ---
    event RelyManager(address indexed usr);
    event DenyManager(address indexed usr);
    event OverrideWriteOff(uint loan, uint writeOffGroupIndex);
    event FileRiskGroup(uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_);
    event FileRiskGroups(uint[] risks_, uint[] thresholdRatios_, uint[] ceilingRatios_, uint[] rates_);
    event FileWriteOffGroup(uint rate_, uint writeOffPercentage_, uint overdueDays_);
    event UpdateNFTValue(bytes32 nftID_, uint value);
    event UpdateNFTValueRisk(bytes32 nftID_, uint value, uint risk_);
    event UpdateNFTMaturityDate(bytes32 nftID_, uint maturityDate_);

    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) public operator {
        navFeed.overrideWriteOff(loan, writeOffGroupIndex_);
        emit OverrideWriteOff(loan, writeOffGroupIndex_);
    }

    function fileRiskGroup(uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_) public operator {
        navFeed.file("riskGroup", risk_, thresholdRatio_, ceilingRatio_, rate_);
        emit FileRiskGroup(risk_, thresholdRatio_, ceilingRatio_, rate_);
    }

    function fileRiskGroups(uint[] memory risks_, uint[] memory thresholdRatios_, uint[] memory ceilingRatios_, uint[] memory rates_) public operator {
        require(risks_.length == thresholdRatios_.length && thresholdRatios_.length == ceilingRatios_.length && ceilingRatios_.length == rates_.length, "non-matching-arguments");
        for (uint i = 0; i < risks_.length; i++) {
            fileRiskGroup(risks_[i], thresholdRatios_[i], ceilingRatios_[i], rates_[i]);
        }
    }

    function fileWriteOffGroup(uint rate_, uint writeOffPercentage_, uint overdueDays_) public operator {
        navFeed.file("writeOffGroup", rate_, writeOffPercentage_, overdueDays_);
        emit FileWriteOffGroup(rate_, writeOffPercentage_, overdueDays_);
    }

    function fileWriteOffGroups(uint[] memory rates_, uint[] memory writeOffPercentages_, uint[] memory overdueDays_) public operator {
        require(rates_.length == writeOffPercentages_.length && writeOffPercentages_.length == overdueDays_.length, "non-matching-arguments");
        for (uint i = 0; i < rates_.length; i++) {
            fileWriteOffGroup(rates_[i], writeOffPercentages_[i], overdueDays_[i]);
        }
    }

    function updateNFTValue(bytes32 nftID_, uint value) public operator {
        navFeed.update(nftID_, value);
        emit UpdateNFTValue(nftID_, value);
    }

    function updateNFTValueRisk(bytes32 nftID_, uint value, uint risk_) public operator {
        navFeed.update(nftID_, value, risk_);
        emit UpdateNFTValueRisk(nftID_, value, risk_);
    }

    function updateNFTMaturityDate(bytes32 nftID_, uint maturityDate_) public operator {
        navFeed.file("maturityDate", nftID_, maturityDate_);
        emit UpdateNFTMaturityDate(nftID_, maturityDate_);
    }

    function relyManager(address usr) public operator {
        managers[usr] = 1;
        emit RelyManager(usr);
    }

    function denyManager(address usr) public operator {
        managers[usr] = 0;
        emit DenyManager(usr);
    }

    // --- High severity actions, authorized by wards ---
    event Depend(bytes32 indexed contractname, address addr);
    event File(bytes32 indexed what, bool indexed data);
    event RelyOperator(address indexed usr);
    event DenyOperator(address indexed usr);
    event RelyWard(address indexed usr);
    event DenyWard(address indexed usr);
    event FileSeniorInterestRate(uint value);
    event FileDiscountRate(uint value);
    event FileMinimumEpochTime(uint value);
    event FileChallengeTime(uint value);
    event FileMinSeniorRatio(uint value);
    event FileMaxSeniorRatio(uint value);

    function fileSeniorInterestRate(uint value) public ward {
        assessor.file("seniorInterestRate", value);
        emit FileSeniorInterestRate(value);
    }

    function fileDiscountRate(uint value) public ward {
        navFeed.file("discountRate", value);
        emit FileDiscountRate(value);
    }

    function fileMinimumEpochTime(uint value) public ward {
        coordinator.file("minimumEpochTime", value);
        emit FileMinimumEpochTime(value);
    }

    function fileChallengeTime(uint value) public ward {
        coordinator.file("challengeTime", value);
        emit FileChallengeTime(value);
    }

    function fileMinSeniorRatio(uint value) public ward {
        assessor.file("minSeniorRatio", value);
        emit FileMinSeniorRatio(value);
    }

    function fileMaxSeniorRatio(uint value) public ward {
        assessor.file("maxSeniorRatio", value);
        emit FileMaxSeniorRatio(value);
    }

    function relyOperator(address usr) public ward {
        operators[usr] = 1;
        emit RelyOperator(usr);
    }

    function denyOperator(address usr) public ward {
        operators[usr] = 0;
        emit DenyOperator(usr);
    }

    function relyWard(address usr) public ward {
        wards[usr] = 1;
        emit RelyWard(usr);
    }

    function denyWard(address usr) public ward {
        wards[usr] = 0;
        emit DenyWard(usr);
    }

    function depend(bytes32 contractName, address addr) public ward {
        if (contractName == "assessor") {
            assessor = AssessorLike(addr);
        } else if (contractName == "lending") {
            lending = LendingAdapterLike(addr);
        } else if (contractName == "seniorMemberlist") {
            seniorMemberlist = MemberlistLike(addr);
        } else if (contractName == "juniorMemberlist") {
            juniorMemberlist = MemberlistLike(addr);
        } else if (contractName == "navFeed") {
            navFeed = FeedLike(addr);
        } else if (contractName == "coordinator") {
            coordinator = CoordinatorLike(addr);
        } else revert();
        emit Depend(contractName, addr);
    }

    function file(bytes32 what, bool data) public ward {
        live = data;
        emit File(what, data);
    }

}
