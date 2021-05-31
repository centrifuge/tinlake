// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "./../fixed_point.sol";

interface NAVFeedLike {
    function update(bytes32 nftID_, uint value, uint risk_) external;
}

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
}

contract Bookrunner is Auth, Math, FixedPoint {

    NAVFeedLike navFeed;
    ERC20Like juniorToken;

    // Absolute min TIN required to propose a new asset
    uint minimumDeposit = 10 ether;

    // Stake threshold required relative to the NFT value
    Fixed27 minimumStakeThreshold = Fixed27(0.05 * 10**27);

    // Time from proposal until it can be accepted
    uint challengeTime = 12 hours;

    // Total amount that is staked for each (nftId, (risk, value)) tuple
    mapping (bytes32 => mapping (bytes => uint)) public proposals;

    // Amount that is staked for each (nftId, (risk, value), underwriter) tuple
    mapping (bytes32 => mapping (bytes => mapping (address => uint))) public perUnderwriterStake;

    // Time at which the asset can be accepted for each nftId
    mapping (bytes32 => uint) public minChallengePeriodEnd;

    // Total amount that an underwriter has staked in all assets
    mapping (address => uint) public staked;

    // (risk, value) pair for each nftId that was accepted
    mapping (bytes32 => bytes) public acceptedProposals;

    constructor() public {
        wards[msg.sender] = 1;
    }

    function file(bytes32 name, uint value) public auth {
        if (name == "challengeTime") {
            challengeTime = value;
        } else if (name == "minimumDeposit") {
            minimumDeposit = value;
        } else if (name == "minimumStakeThreshold") {
            minimumStakeThreshold = Fixed27(value);
          } else { revert("unkown-name");}
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "juniorToken") { juniorToken = ERC20Like(addr); }
        if (contractName == "navFeed") { navFeed = NAVFeedLike(addr); }
        else revert();
    }

    function assetWasAccepted(bytes32 nftId) public view returns (bool) {
      return acceptedProposals[nftId].length != 0;
    }

    function propose(bytes32 nftId, uint risk, uint value, uint deposit) public {
      require(deposit >= minimumDeposit, "min-deposit-required");
      require(acceptedProposals[nftId].length == 0, "asset-already-accepted");

      uint senderStake = staked[msg.sender];
      require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= deposit);

      bytes memory proposal = abi.encodePacked(risk, value);
      require(proposals[nftId][proposal] == 0, "proposal-already-exists");

      proposals[nftId][proposal] = deposit;
      perUnderwriterStake[nftId][proposal][msg.sender] = deposit;
      minChallengePeriodEnd[nftId] = block.timestamp + challengeTime;
      staked[msg.sender] = safeAdd(senderStake, deposit);
    }

    function accept(bytes32 nftId, uint risk, uint value) public {
      bytes memory proposal = abi.encodePacked(risk, value);
      require(minChallengePeriodEnd[nftId] >= block.timestamp, "challenge-period-not-ended");
      require(rmul(minimumStakeThreshold.value, proposals[nftId][proposal]) >= value, "stake-threshold-not-reached");
      
      acceptedProposals[nftId] = proposal;
      navFeed.update(nftId, risk, value);
    }

    function stake(bytes32 nftId, uint risk, uint value, uint stakeAmount) public {
      require(acceptedProposals[nftId].length == 0, "asset-already-accepted");
      
      uint senderStake = staked[msg.sender];
      require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= stakeAmount);

      bytes memory proposal = abi.encodePacked(risk, value);
      uint prevStake = perUnderwriterStake[nftId][proposal][msg.sender];
      uint newStake = safeAdd(prevStake, stakeAmount);

      proposals[nftId][proposal] = newStake;
      perUnderwriterStake[nftId][proposal][msg.sender] = newStake;
      staked[msg.sender] = safeAdd(senderStake, stakeAmount);
    }

    // For gas efficiency, stake isn't automatically removed from an asset when another proposal is accepted. Instead,
    // the underwriter can move their stake to a new asset
    function moveStake(uint fromNftId, uint fromRisk, uint fromValue, uint toNftId, uint toRisk, uint toValue, uint stakeAmount) public {
      // require proposal wasnt already accepted
      // remove staked from old proposal
      // add staked to new proposal 
    }

    // TODO: function cancelStake()

}