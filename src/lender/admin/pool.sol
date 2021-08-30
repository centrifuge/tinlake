// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

interface AssessorLike {
    function file(bytes32 name, uint256 value) external;
}

interface LendingAdapterLike {
    function raise(uint256 amount) external;
    function sink(uint256 amount) external;
    function heal() external;
    function file(bytes32 what, uint value) external;
}

interface FeedLike {
    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) external;
    function file(bytes32 name, uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_) external;
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

    mapping (address => uint256) public level1_admins;
    mapping (address => uint256) public level2_admins;
    mapping (address => uint256) public level3_admins;

    modifier level1     { require(level1_admins[msg.sender] == 1 && live); _; }
    modifier level2     { require(level2_admins[msg.sender] == 1 && live); _; }
    modifier level3     { require(level3_admins[msg.sender] == 1 && live); _; }

    event Rely(uint indexed level, address indexed usr);
    event Deny(uint indexed level, address indexed usr);

    constructor() {
        level3_admins[msg.sender] = 1;
        emit Rely(3, msg.sender);
    }

    // --- Liquidity Management, authorized by level 1 admins ---
    event SetMaxReserve(uint256 value);
    event RaiseCreditline(uint256 amount);
    event SinkCreditline(uint256 amount);
    event HealCreditline();
    event UpdateSeniorMember(address indexed usr, uint256 validUntil);
    event UpdateSeniorMembers(address[] indexed users, uint256 validUntil);
    event UpdateJuniorMember(address indexed usr, uint256 validUntil);
    event UpdateJuniorMembers(address[] indexed users, uint256 validUntil);

    // Manage max reserve
    function setMaxReserve(uint256 value) public level1 {
        assessor.file("maxReserve", value);
        emit SetMaxReserve(value);
    }

    // Manage creditline
    function raiseCreditline(uint256 amount) public level1 {
        lending.raise(amount);
        emit RaiseCreditline(amount);
    }

    function sinkCreditline(uint256 amount) public level1 {
        lending.sink(amount);
        emit SinkCreditline(amount);
    }

    function healCreditline() public level1 {
        lending.heal();
        emit HealCreditline();
    }

    function setMaxReserveAndRaiseCreditline(uint256 newMaxReserve, uint256 creditlineRaise) public level1 {
        setMaxReserve(newMaxReserve);
        raiseCreditline(creditlineRaise);
    }

    function setMaxReserveAndSinkCreditline(uint256 newMaxReserve, uint256 creditlineSink) public level1 {
        setMaxReserve(newMaxReserve);
        sinkCreditline(creditlineSink);
    }

    // Manage memberlists
    function updateSeniorMember(address usr, uint256 validUntil) public level1 {
        seniorMemberlist.updateMember(usr, validUntil);
        emit UpdateSeniorMember(usr, validUntil);
    }

    function updateSeniorMembers(address[] memory users, uint256 validUntil) public level1 {
        seniorMemberlist.updateMembers(users, validUntil);
        emit UpdateSeniorMembers(users, validUntil);
    }

    function updateJuniorMember(address usr, uint256 validUntil) public level1 {
        juniorMemberlist.updateMember(usr, validUntil);
        emit UpdateJuniorMember(usr, validUntil);
    }

    function updateJuniorMembers(address[] memory users, uint256 validUntil) public level1 {
        juniorMemberlist.updateMembers(users, validUntil);
        emit UpdateJuniorMembers(users, validUntil);
    }
    
    // --- Risk Management, authorized by level 2 admins ---
    event OverrideWriteOff(uint loan, uint writeOffGroupIndex);
    event FileRiskGroup(uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_);
    event FileRiskGroups(uint[] risks_, uint[] thresholdRatios_, uint[] ceilingRatios_, uint[] rates_);
    event FileWriteOffGroup(uint rate_, uint writeOffPercentage_, uint overdueDays_);
    event FileMatBuffer(uint value);
    event UpdateNFTValue(bytes32 nftID_, uint value);
    event UpdateNFTValueRisk(bytes32 nftID_, uint value, uint risk_);
    event UpdateNFTMaturityDate(bytes32 nftID_, uint maturityDate_);

    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) public level2 {
        navFeed.overrideWriteOff(loan, writeOffGroupIndex_);
        emit OverrideWriteOff(loan, writeOffGroupIndex_);
    }

    function fileRiskGroup(uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_, uint recoveryRatePD_) public level2 {
        navFeed.file("riskGroup", risk_, thresholdRatio_, ceilingRatio_, rate_, recoveryRatePD_);
        emit FileRiskGroup(risk_, thresholdRatio_, ceilingRatio_, rate_, recoveryRatePD_);
    }

    function fileRiskGroups(uint[] memory risks_, uint[] memory thresholdRatios_, uint[] memory ceilingRatios_, uint[] memory rates_, uint[] memory recoveryRatePDs_) public level2 {
        require(risks_.length == thresholdRatios_.length && thresholdRatios_.length == ceilingRatios_.length && ceilingRatios_.length == rates_.length, "non-matching-arguments");
        for (uint i = 0; i < risks_.length; i++) {
            fileRiskGroup(risks_[i], thresholdRatios_[i], ceilingRatios_[i], rates_[i], recoveryRatePDs_[i]);
        }
    }

    function fileWriteOffGroup(uint rate_, uint writeOffPercentage_, uint overdueDays_) public level2 {
        navFeed.file("writeOffGroup", rate_, writeOffPercentage_, overdueDays_);
        emit FileWriteOffGroup(rate_, writeOffPercentage_, overdueDays_);
    }

    function fileWriteOffGroups(uint[] memory rates_, uint[] memory writeOffPercentages_, uint[] memory overdueDays_) public level2 {
        require(rates_.length == writeOffPercentages_.length && writeOffPercentages_.length == overdueDays_.length, "non-matching-arguments");
        for (uint i = 0; i < rates_.length; i++) {
            fileWriteOffGroup(rates_[i], writeOffPercentages_[i], overdueDays_[i]);
        }
    }

    function fileMatBuffer(uint value) public level3 {
        lending.file("buffer", value);
        emit FileMatBuffer(value);
    }

    function updateNFTValue(bytes32 nftID_, uint value) public level2 {
        navFeed.update(nftID_, value);
        emit UpdateNFTValue(nftID_, value);
    }

    function updateNFTValueRisk(bytes32 nftID_, uint value, uint risk_) public level2 {
        navFeed.update(nftID_, value, risk_);
        emit UpdateNFTValueRisk(nftID_, value, risk_);
    }

    function updateNFTMaturityDate(bytes32 nftID_, uint maturityDate_) public level2 {
        navFeed.file("maturityDate", nftID_, maturityDate_);
        emit UpdateNFTMaturityDate(nftID_, maturityDate_);
    }

    function relyLevel1(address usr) public level2 {
        level1_admins[usr] = 1;
        emit Rely(1, usr);
    }

    function denyLevel1(address usr) public level2 {
        level1_admins[usr] = 0;
        emit Deny(1, usr);
    }

    // --- Pool Governance, authorized by level 3 admins ---
    event Depend(bytes32 indexed contractname, address addr);
    event File(bytes32 indexed what, bool indexed data);
    event FileSeniorInterestRate(uint value);
    event FileDiscountRate(uint value);
    event FileMinimumEpochTime(uint value);
    event FileChallengeTime(uint value);
    event FileMinSeniorRatio(uint value);
    event FileMaxSeniorRatio(uint value);
    event FileEpochScoringWeights(uint weightSeniorRedeem, uint weightJuniorRedeem, uint weightJuniorSupply, uint weightSeniorSupply);

    function fileSeniorInterestRate(uint value) public level3 {
        assessor.file("seniorInterestRate", value);
        emit FileSeniorInterestRate(value);
    }

    function fileDiscountRate(uint value) public level3 {
        navFeed.file("discountRate", value);
        emit FileDiscountRate(value);
    }

    function fileMinimumEpochTime(uint value) public level3 {
        coordinator.file("minimumEpochTime", value);
        emit FileMinimumEpochTime(value);
    }

    function fileChallengeTime(uint value) public level3 {
        coordinator.file("challengeTime", value);
        emit FileChallengeTime(value);
    }

    function fileMinSeniorRatio(uint value) public level3 {
        assessor.file("minSeniorRatio", value);
        emit FileMinSeniorRatio(value);
    }

    function fileMaxSeniorRatio(uint value) public level3 {
        assessor.file("maxSeniorRatio", value);
        emit FileMaxSeniorRatio(value);
    }

    function fileEpochScoringWeights(uint weightSeniorRedeem, uint weightJuniorRedeem, uint weightJuniorSupply, uint weightSeniorSupply) public level3 {
        coordinator.file("weightSeniorRedeem", weightSeniorRedeem);
        coordinator.file("weightJuniorRedeem", weightJuniorRedeem);
        coordinator.file("weightJuniorSupply", weightJuniorSupply);
        coordinator.file("weightSeniorSupply", weightSeniorSupply);
        emit FileEpochScoringWeights(weightSeniorRedeem, weightJuniorRedeem, weightJuniorSupply, weightSeniorSupply);
    }

    function relyLevel2(address usr) public level3 {
        level2_admins[usr] = 1;
        emit Rely(2, usr);
    }

    function denyLevel2(address usr) public level3 {
        level2_admins[usr] = 0;
        emit Deny(2, usr);
    }

    function relyLevel3(address usr) public level3 {
        level3_admins[usr] = 1;
        emit Rely(3, usr);
    }

    function denyLevel3(address usr) public level3 {
        level3_admins[usr] = 0;
        emit Deny(3, usr);
    }

    function depend(bytes32 contractName, address addr) public level3 {
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

    function file(bytes32 what, bool data) public level3 {
        live = data;
        emit File(what, data);
    }

}
