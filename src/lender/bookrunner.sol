// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "./../fixed_point.sol";

interface NAVFeedLike {
	function update(bytes32 nftID_, uint value, uint risk_) external;
	function nftID(uint loan) external view returns (bytes32);
}

interface ERC20Like {
	function balanceOf(address) external view returns (uint);
	function transferFrom(address, address, uint) external;
	function transfer(address, uint) external;
	function mint(address, uint) external;
	function burn(address, uint) external;
}

interface MemberlistLike {
	function hasMember(address) external view returns (bool);
	function member(address) external;
}

contract Bookrunner is Auth, Math, FixedPoint {

	NAVFeedLike public navFeed;
	ERC20Like public juniorToken;
	MemberlistLike public memberlist; 

	// Absolute min TIN required to propose a new asset
	uint public minimumDeposit = 10 ether;

	// Stake threshold required relative to the NFT value
	Fixed27 public minimumStakeThreshold = Fixed27(0.10 * 10**27);

	// % of the repaid/written off amount that is minted/burned in TIN tokens for the underwriters
	Fixed27 public mintProportion = Fixed27(0.01 * 10**27);
	Fixed27 public slashProportion = Fixed27(0.01 * 10**27); 

	// Time from proposal until it can be accepted
	uint public challengeTime = 30 minutes;

	// Total amount that is staked for each (loan, (risk, value)) tuple
	mapping (uint => mapping (bytes => uint)) public proposals;

	// Amount that is staked for each (loan, (risk, value), underwriter) tuple
	// This isn't unset if a proposal is unstaked or paid out after being closed,
	// as this keeps the history of which proposal which underwriter staked towards
	mapping (uint => mapping (bytes => mapping (address => uint))) public perUnderwriterStake;

	// Loans which an underwriter has staked towards
	mapping (address => uint[]) public underwriterStakes;

	// Time at which the asset can be accepted for each loan
	mapping (uint => uint) public minChallengePeriodEnd;

	// Total amount that an underwriter has staked in all assets
	mapping (address => uint) public staked;

	// (risk, value) pair for each loan that was accepted
	mapping (uint => bytes) public acceptedProposals;

	// Amount repaid and written off per loan
	mapping (uint => uint) public repaid;
	mapping (uint => uint) public writtenOff;

	// Whether the loan has been closed
	mapping (uint => bool) public closed;

	// Total amount staked (tokens held by this contract)
	uint public totalStaked;

	event Propose(uint indexed loan, uint risk, uint value, uint deposit);
	event Accept(uint indexed loan, uint risk, uint value);
	event Mint(address indexed usr, uint amount);
	event Burn(address indexed usr, uint amount);

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

	function propose(uint loan, uint risk, uint value, uint deposit) public {
		require(deposit >= minimumDeposit, "min-deposit-required");
		require(acceptedProposals[loan].length == 0, "asset-already-accepted");
		require(juniorToken.balanceOf(msg.sender) >= deposit, "insufficient-balance");

		bytes memory proposal = abi.encodePacked(risk, value); // TODO: this is a bit of trick, can probably be done more efficiently, or maybe even off-chain
		require(proposals[loan][proposal] == 0, "proposal-already-exists");

		juniorToken.transferFrom(msg.sender, address(this), deposit);
		totalStaked = safeAdd(totalStaked, deposit);

		proposals[loan][proposal] = deposit;
		perUnderwriterStake[loan][proposal][msg.sender] = deposit;
		underwriterStakes[msg.sender].push(loan);
		minChallengePeriodEnd[loan] = block.timestamp + challengeTime;
		staked[msg.sender] = safeAdd(staked[msg.sender], deposit);

		emit Propose(loan, risk, value, deposit);
	}

	// Staking in opposition of an asset can be done by staking with a value of 0.
	function stake(uint loan, uint risk, uint value, uint stakeAmount) public memberOnly {
		require(acceptedProposals[loan].length == 0, "asset-already-accepted");

		bytes memory proposal = abi.encodePacked(risk, value);
		uint prevPerUnderwriterStake = perUnderwriterStake[loan][proposal][msg.sender];
		require(stakeAmount <= prevPerUnderwriterStake || juniorToken.balanceOf(msg.sender) >= safeSub(stakeAmount, prevPerUnderwriterStake), "insufficient-balance");
		require(stakeAmount > 0, "requires-unstaking"); // unstake() should be called for setting the stake to 0

		if (stakeAmount > prevPerUnderwriterStake) {
			uint increase = safeSub(stakeAmount, prevPerUnderwriterStake);
			juniorToken.transferFrom(msg.sender, address(this), increase);

			totalStaked = safeAdd(totalStaked, increase);
			proposals[loan][proposal] = safeAdd(proposals[loan][proposal], increase);
			perUnderwriterStake[loan][proposal][msg.sender] = safeAdd(prevPerUnderwriterStake, increase);
			staked[msg.sender] = safeAdd(staked[msg.sender], increase);
		} else if (stakeAmount < prevPerUnderwriterStake) {
			uint decrease = safeSub(prevPerUnderwriterStake, stakeAmount);
			juniorToken.transfer(msg.sender, decrease);

			totalStaked = safeSub(totalStaked, decrease);
			proposals[loan][proposal] = safeSub(proposals[loan][proposal], decrease);
			perUnderwriterStake[loan][proposal][msg.sender] = safeSub(prevPerUnderwriterStake, decrease);
			staked[msg.sender] = safeSub(staked[msg.sender], decrease);
		}

		if (prevPerUnderwriterStake == 0) {
			underwriterStakes[msg.sender].push(loan);
		}
	}

	function accept(uint loan, uint risk, uint value) public {
		require(block.timestamp >= minChallengePeriodEnd[loan], "challenge-period-not-ended");
		bytes memory proposal = abi.encodePacked(risk, value);
		require(proposals[loan][proposal] >= rmul(minimumStakeThreshold.value, value), "stake-threshold-not-reached");

		// TODO: if there are multiple proposals which pass the minimumStakeThreshold, only accept the one with the largest stake
		// store proposalWithLargestStake[loan], update on stake(), check here if proposals[loan][proposal] == proposalWithLargestStake[loan]

		// TODO: If there are more assets that qualify than liquidity to finance them, only those with the largest stake get financed in that time period.
		// + preference to finance assets with highest stake without no votes
		
		bytes32 nftID_ = navFeed.nftID(loan);
		navFeed.update(nftID_, value, risk);
		acceptedProposals[loan] = proposal;
		
		emit Accept(loan, risk, value);
	}

	function unstake(uint loan, uint risk, uint value) public memberOnly {
		bytes memory proposal = abi.encodePacked(risk, value);
		require(keccak256(acceptedProposals[loan]) != keccak256(proposal), "cannot-unstake-accepted-proposal");

		uint stakeAmount = perUnderwriterStake[loan][proposal][msg.sender];
		proposals[loan][proposal] = safeSub(proposals[loan][proposal], stakeAmount);
		
		safeTransfer(msg.sender, stakeAmount);
		totalStaked = safeSub(totalStaked, stakeAmount);
		staked[msg.sender] = safeSub(staked[msg.sender], stakeAmount);

		uint i = 0;
		while (underwriterStakes[msg.sender][i] != loan) { i++; }
		delete underwriterStakes[msg.sender][i];
	}

	function assetWasAccepted(uint loan) public view returns (bool) {
		return acceptedProposals[loan].length != 0;
	}

	function calcStakedDisburse(address underwriter, bool disbursing) public returns (uint minted, uint slashed, uint tokenPayout) {
		uint[] memory loans = underwriterStakes[underwriter];

		for (uint i = 0; i < loans.length; i++) {
			uint loan = loans[i];
			bytes memory acceptedProposal = acceptedProposals[loan];
			uint underwriterStake = perUnderwriterStake[loan][acceptedProposal][underwriter];
			uint256 relativeStake = rdiv(underwriterStake, proposals[loan][acceptedProposal]);

			// (mint proportion * (relative stake * repaid amount))
			uint newlyMinted = rmul(mintProportion.value, rmul(relativeStake, repaid[loan]));
			minted = safeAdd(minted, newlyMinted);

			// (slash proportion * (relative stake * written off amount))
			uint newlySlashed = rmul(slashProportion.value, rmul(relativeStake, writtenOff[loan]));
			slashed = safeAdd(slashed, newlySlashed);

			// TODO: if an asset is defaulting and there was a vote against, part of the slash is going to this vote
			// => store votesAgainst[loan] for any stakes with value = 0

			if (closed[loan]) {
				uint newPayout = safeSub(safeAdd(underwriterStake, newlyMinted), newlySlashed);
				tokenPayout = safeAdd(tokenPayout, newPayout);

				// TODO: rewrite s.t. this can be in disburse, then make calcStakedDisburse a view method
				if (disbursing) {
					delete underwriterStakes[underwriter][i];
				}
			}
		}

		return (minted, slashed, tokenPayout);
	}

	// Called from tranche, not directly, hence the auth modifier
	function disburse(address underwriter) public auth returns (uint) {
		(,, uint tokenPayout) = calcStakedDisburse(underwriter, true);

		safeTransfer(underwriter, tokenPayout);
		totalStaked = safeSub(totalStaked, tokenPayout);
		staked[underwriter] = safeSub(staked[underwriter], min(tokenPayout, staked[underwriter]));

		return tokenPayout;
	}

	function setRepaid(uint loan, uint amount) public auth {
		require(!closed[loan], "already-closed");
		repaid[loan] = amount;
		mint(rmul(mintProportion.value, amount));
	}

	// TODO: if loss exceeds the amount staked, all of TIN takes a hit
	function setWrittenOff(uint loan, uint writeoffPercentage, uint amount) public auth {
		require(!closed[loan], "already-closed");
		writtenOff[loan] = amount;
		safeBurn(rmul(slashProportion.value, amount));

		if (writeoffPercentage == 10**27) {
			setClosed(loan);
		}
	}

	function setClosed(uint loan) public auth {
		closed[loan] = true;
		// bytes32 nftID_ = navFeed.nftID(loan);
		// TODO: navFeed.update(nftID_, 0, 0);
	}

	function currentStake(uint loan, uint risk, uint value) public view returns (uint) {
		bytes memory proposal = abi.encodePacked(risk, value);
		return proposals[loan][proposal];
	}

	function mint(uint amount) internal {
		juniorToken.mint(address(this), amount);
		emit Mint(address(this), amount);
	}

	function safeBurn(uint amount) internal {
		juniorToken.burn(address(this), min(amount, juniorToken.balanceOf(address(this))));
		emit Burn(address(this), amount);
	}

	function safeTransfer(address usr, uint amount) internal returns(uint) {
		juniorToken.transfer(usr, min(amount, juniorToken.balanceOf(address(this))));
		return amount;
	}

	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}


}