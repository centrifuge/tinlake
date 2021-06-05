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

	// Total amount that is staked for each (nftID, (risk, value)) tuple
	mapping (bytes32 => mapping (bytes => uint)) public proposals;

	// Amount that is staked for each (nftID, (risk, value), underwriter) tuple
	mapping (bytes32 => mapping (bytes => mapping (address => uint))) public perUnderwriterStake;

	// nftIDs which an underwriter has staked towards
	mapping (address => bytes32[]) public underwriterStakes;

	// Time at which the asset can be accepted for each nftID
	mapping (bytes32 => uint) public minChallengePeriodEnd;

	// Total amount that an underwriter has staked in all assets
	mapping (address => uint) public staked;

	// (risk, value) pair for each nftID that was accepted
	mapping (bytes32 => bytes) public acceptedProposals;

	// % repaid and % written off per nftID
	mapping (bytes32 => Fixed27) public repaid;
	mapping (bytes32 => Fixed27) public writtenOff;

	constructor() {
		wards[msg.sender] = 1;
		emit Rely(msg.sender);
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
		else if (contractName == "navFeed") { navFeed = NAVFeedLike(addr); }
		else revert();
	}

	function assetWasAccepted(bytes32 nftID) public view returns (bool) {
		return acceptedProposals[nftID].length != 0;
	}

	function stakerCalcDisburse(address staker) public view returns (uint, uint) {
		bytes32[] memory nftIDs = underwriterStakes[staker];
		uint tokensToBeMinted = 0;
		uint tokensToBeBurned = 0;

		for (uint i = 0; i < nftIDs.length; i++) {
			bytes32 nftID = nftIDs[i];
			bytes memory acceptedProposal = acceptedProposals[nftID];
			uint256 relativeStake = rdiv(perUnderwriterStake[nftID][acceptedProposal][msg.sender], proposals[nftID][acceptedProposal]);
			tokensToBeMinted = safeAdd(tokensToBeMinted, rmul(relativeStake, repaid[nftID].value));
			tokensToBeMinted = safeAdd(tokensToBeMinted, rmul(relativeStake, writtenOff[nftID].value));
		}

		// TODO: how to store that tokens were already minted/burned

		return (tokensToBeMinted, tokensToBeBurned);
	}

	function propose(bytes32 nftID, uint risk, uint value, uint deposit) public {
		require(deposit >= minimumDeposit, "min-deposit-required");
		require(acceptedProposals[nftID].length == 0, "asset-already-accepted");

		uint senderStake = staked[msg.sender];
		require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= deposit, "insufficient-balance");

		bytes memory proposal = abi.encodePacked(risk, value);
		require(proposals[nftID][proposal] == 0, "proposal-already-exists");

		proposals[nftID][proposal] = deposit;
		perUnderwriterStake[nftID][proposal][msg.sender] = deposit;
		underwriterStakes[msg.sender].push(nftID);
		minChallengePeriodEnd[nftID] = block.timestamp + challengeTime;
		staked[msg.sender] = safeAdd(senderStake, deposit);
	}

	function accept(bytes32 nftID, uint risk, uint value) public {
		bytes memory proposal = abi.encodePacked(risk, value);
		require(minChallengePeriodEnd[nftID] >= block.timestamp, "challenge-period-not-ended");
		require(rmul(minimumStakeThreshold.value, proposals[nftID][proposal]) >= value, "stake-threshold-not-reached");
		
		acceptedProposals[nftID] = proposal;
		navFeed.update(nftID, risk, value);
	}

	function stake(bytes32 nftID, uint risk, uint value, uint stakeAmount) public {
		require(acceptedProposals[nftID].length == 0, "asset-already-accepted");
		
		uint senderStake = staked[msg.sender];
		require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= stakeAmount, "insufficient-balance");

		bytes memory proposal = abi.encodePacked(risk, value);
		uint prevStake = perUnderwriterStake[nftID][proposal][msg.sender];
		uint newStake = safeAdd(prevStake, stakeAmount);

		proposals[nftID][proposal] = newStake;
		perUnderwriterStake[nftID][proposal][msg.sender] = newStake;
		underwriterStakes[msg.sender].push(nftID);
		staked[msg.sender] = safeAdd(senderStake, stakeAmount);
	}

	// For gas efficiency, stake isn't automatically removed from an asset when another proposal is accepted.
	// Instead, the underwriter can move their stake to a new asset.
	function moveStake(uint fromNftId, uint fromRisk, uint fromValue, bytes32 toNftId, uint toRisk, uint toValue, uint stakeAmount) public {
		require(acceptedProposals[toNftId].length == 0, "asset-already-accepted");
		// TODO: how to handle stake that was supposed to be burned? Maybe not allow move if writtenOff[formNftID] > 0?

		// remove staked from old proposal
		// add staked to new proposal 
		
	}

	// TODO: function cancelStake()

}