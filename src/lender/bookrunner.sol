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

interface MemberlistLike {
    function hasMember(address) external view returns (bool);
    function member(address) external;
}
/**
TODO:
- do we need a max stake threshold, to ensure there's sufficient returns?
 */
contract Bookrunner is Auth, Math, FixedPoint {

	NAVFeedLike public navFeed;
	ERC20Like public juniorToken;
	MemberlistLike public memberlist; 

	// Absolute min TIN required to propose a new asset
	uint minimumDeposit = 10 ether;

	// Stake threshold required relative to the NFT value
	Fixed27 minimumStakeThreshold = Fixed27(0.10 * 10**27);

	// % of the repaid/written off amount that is minted/burned in TIN tokens for the underwriters
	Fixed27 mintProportion = Fixed27(0.01 * 10**27);
	Fixed27 slashProportion = Fixed27(0.01 * 10**27); 

	// Time from proposal until it can be accepted
	uint challengeTime = 30 minutes;

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

	// Amount repaid and written off per nftID
	// TODO: can't we just retrieve these from the navFeed directly?
	mapping (bytes32 => Fixed27) public repaid;
	mapping (bytes32 => Fixed27) public writtenOff;

	// minted/burned amount per (nftID, underwriter) tuple
	mapping (bytes32 => mapping (address => uint)) public minted;
	mapping (bytes32 => mapping (address => uint)) public burned;

	modifier memberOnly { require(memberlist.hasMember(msg.sender), "not-allowed-to-underwrite"); _; }

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
		} else if (name == "mintProportion") {
			mintProportion = Fixed27(value);
		} else if (name == "slashProportion") {
			slashProportion = Fixed27(value);
		} else { revert("unknown-name");}
	}

	function depend(bytes32 contractName, address addr) public auth {
		if (contractName == "juniorToken") { juniorToken = ERC20Like(addr); }
		else if (contractName == "navFeed") { navFeed = NAVFeedLike(addr); }
  	else if (contractName == "memberlist") { memberlist = MemberlistLike(addr); }
		else revert();
	}

	function propose(bytes32 nftID, uint risk, uint value, uint deposit) public memberOnly {
		require(deposit >= minimumDeposit, "min-deposit-required");
		require(acceptedProposals[nftID].length == 0, "asset-already-accepted");

		uint senderStake = staked[msg.sender];
		require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= deposit, "insufficient-balance");

		bytes memory proposal = abi.encodePacked(risk, value); // TODO: this is a bit of trick, can probably be done more efficiently, or maybe even off-chain
		require(proposals[nftID][proposal] == 0, "proposal-already-exists");

		proposals[nftID][proposal] = deposit;
		perUnderwriterStake[nftID][proposal][msg.sender] = deposit;
		underwriterStakes[msg.sender].push(nftID);
		minChallengePeriodEnd[nftID] = block.timestamp + challengeTime;
		staked[msg.sender] = safeAdd(senderStake, deposit);
	}

	function accept(bytes32 nftID, uint risk, uint value) public memberOnly {
		bytes memory proposal = abi.encodePacked(risk, value);
		require(minChallengePeriodEnd[nftID] >= block.timestamp, "challenge-period-not-ended");
		require(rmul(minimumStakeThreshold.value, proposals[nftID][proposal]) >= value, "stake-threshold-not-reached");
		
		acceptedProposals[nftID] = proposal;
		navFeed.update(nftID, risk, value);
	}

	// Staking against can be done by staking with a value of 0.
	function addStake(bytes32 nftID, uint risk, uint value, uint stakeAmount) public memberOnly {
		require(acceptedProposals[nftID].length == 0, "asset-already-accepted");
		
		uint senderStake = staked[msg.sender];
		require(safeSub(juniorToken.balanceOf(msg.sender), senderStake) >= stakeAmount, "insufficient-balance");

		// TODO: check burned[nftID][underwriter]

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
	function moveStake(uint fromNftId, uint fromRisk, uint fromValue, bytes32 toNftId, uint toRisk, uint toValue, uint stakeAmount) public memberOnly {
		require(acceptedProposals[toNftId].length == 0, "asset-already-accepted");
		// TODO: check burned[nftID][underwriter]
		// TODO: how to handle stake that was supposed to be burned? Maybe not allow move if writtenOff[formNftID] > 0?

		// remove staked from old proposal
		// add staked to new proposal 

		// if full stake is moved, underwriterStakes[msg.sender].remove(nftID) (only if fully minted/burned)
		
	}

	// TODO: function cancelStake() public memberOnly
	// TODO: check burned[nftID][underwriter]
	// if full stake is cancelled, underwriterStakes[msg.sender].remove(nftID)(only if fully minted/burned)

	function assetWasAccepted(bytes32 nftID) public view returns (bool) {
		return acceptedProposals[nftID].length != 0;
	}

	function calcStakedDisburse(address underwriter) public view returns (uint, uint) {
		bytes32[] memory nftIDs = underwriterStakes[underwriter];
		uint tokensToBeMinted = 0;
		uint tokensToBeBurned = 0;

		for (uint i = 0; i < nftIDs.length; i++) {
			bytes32 nftID = nftIDs[i];
			bytes memory acceptedProposal = acceptedProposals[nftID];
			uint256 relativeStake = rdiv(perUnderwriterStake[nftID][acceptedProposal][msg.sender], proposals[nftID][acceptedProposal]);
			tokensToBeMinted = safeAdd(tokensToBeMinted, rmul(mintProportion.value, rmul(relativeStake, repaid[nftID].value)));
			tokensToBeBurned = safeAdd(tokensToBeBurned, rmul(slashProportion.value, rmul(relativeStake, writtenOff[nftID].value)));

			// TODO: if an asset is defaulting and there was a vote against, part of the slash is going to this vote
		}

		return (tokensToBeMinted, tokensToBeBurned);
	}

	// Called from tranche, not directly, hence the auth modifier
	// TODO: this is duplicating calcStakedDisburse partially
	function disburse(address underwriter) public auth returns (uint, uint) {
		bytes32[] memory nftIDs = underwriterStakes[underwriter];

		uint tokensToBeMinted = 0;
		uint tokensToBeBurned = 0;
		for (uint i = 0; i < nftIDs.length; i++) {
			bytes32 nftID = nftIDs[i];
			bytes memory acceptedProposal = acceptedProposals[nftID];
			uint256 relativeStake = rdiv(perUnderwriterStake[nftID][acceptedProposal][msg.sender], proposals[nftID][acceptedProposal]);

			uint newlyMinted = rmul(mintProportion.value, rmul(relativeStake, repaid[nftID].value));
			uint newlyBurned = rmul(slashProportion.value, rmul(relativeStake, writtenOff[nftID].value));
			minted[nftID][underwriter] = newlyMinted;
			burned[nftID][underwriter] = newlyBurned;

			tokensToBeMinted = safeAdd(tokensToBeMinted, newlyMinted);
			tokensToBeBurned = safeAdd(tokensToBeMinted, newlyBurned);
		}

		return (tokensToBeMinted, tokensToBeBurned);
	}

}