// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "./../fixed_point.sol";
import "ds-test/test.sol";

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
/**
TODO:
- do we need a max stake threshold, to ensure there's sufficient returns?
- on shelf.close(), should we reset the risk & value in the navfeed such that a new loan against this nftID requires new staking?
 */
contract Bookrunner is Auth, Math, FixedPoint, DSTest {

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
	mapping (uint => mapping (bytes => mapping (address => uint))) public perUnderwriterStake;

	// loans which an underwriter has staked towards
	mapping (address => uint[]) public underwriterStakes;

	// Time at which the asset can be accepted for each loan
	mapping (uint => uint) public minChallengePeriodEnd;

	// Total amount that an underwriter has staked in all assets
	mapping (address => uint) public staked;

	// (risk, value) pair for each loan that was accepted
	mapping (uint => bytes) public acceptedProposals;

	// Amount repaid and written off per loan
	// TODO: look into retrieving these from the navFeed directly
	mapping (uint => uint) public repaid;
	mapping (uint => uint) public writtenOff;

	// Whether the loan has been closed
	mapping (uint => bool) public closed;

	// total amount staked (tokens held by this contract)
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

	function propose(uint loan, uint risk, uint value, uint deposit) public memberOnly {
		require(deposit >= minimumDeposit, "min-deposit-required");
		require(acceptedProposals[loan].length == 0, "asset-already-accepted");
		require(juniorToken.balanceOf(msg.sender) >= deposit, "insufficient-balance");

		bytes memory proposal = abi.encodePacked(risk, value); // TODO: this is a bit of trick, can probably be done more efficiently, or maybe even off-chain
		require(proposals[loan][proposal] == 0, "proposal-already-exists");

		// require(juniorToken.transferFrom(msg.sender, address(this), deposit), "token-transfer-failed");
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
	// TODO: rewrite to stakeAmount as new value rather than diff, to allow easy updating of stake?
	function stake(uint loan, uint risk, uint value, uint stakeAmount) public memberOnly {
		require(acceptedProposals[loan].length == 0, "asset-already-accepted");
		require(juniorToken.balanceOf(msg.sender) >= stakeAmount, "insufficient-balance");

		// TODO: check burned[loan][underwriter]

		// require(juniorToken.transferFrom(msg.sender, address(this), stakeAmount), "token-transfer-failed");
		juniorToken.transferFrom(msg.sender, address(this), stakeAmount);
		totalStaked = safeAdd(totalStaked, stakeAmount);

		bytes memory proposal = abi.encodePacked(risk, value);
		proposals[loan][proposal] = safeAdd(proposals[loan][proposal], stakeAmount);

		uint prevPerUnderwriterStake = perUnderwriterStake[loan][proposal][msg.sender];
		uint newPerUnderwriterStake = safeAdd(prevPerUnderwriterStake, stakeAmount);
		perUnderwriterStake[loan][proposal][msg.sender] = newPerUnderwriterStake;

		underwriterStakes[msg.sender].push(loan);
		staked[msg.sender] = safeAdd(staked[msg.sender], stakeAmount);
	}

	// TODO: this could be permissionless?
	function accept(uint loan, uint risk, uint value) public memberOnly {
		require(block.timestamp >= minChallengePeriodEnd[loan], "challenge-period-not-ended");
		bytes memory proposal = abi.encodePacked(risk, value);
		require(proposals[loan][proposal] >= rmul(minimumStakeThreshold.value, value), "stake-threshold-not-reached");
		
		bytes32 nftID_ = navFeed.nftID(loan);
		navFeed.update(nftID_, value, risk);
		acceptedProposals[loan] = proposal;
		
		emit Accept(loan, risk, value);
	}

	function unstake(uint loan, uint risk, uint value) public memberOnly {
		bytes memory proposal = abi.encodePacked(risk, value);
		// TODO: require(acceptedProposals[loan] != proposal, "cannot-unstake-accepted-proposal");

		uint stakeAmount = perUnderwriterStake[loan][proposal][msg.sender];
		proposals[loan][proposal] = safeSub(proposals[loan][proposal], stakeAmount);
		
		safeTransfer(msg.sender, stakeAmount);
		totalStaked = safeSub(totalStaked, stakeAmount);
		staked[msg.sender] = safeSub(staked[msg.sender], stakeAmount);

		uint i = 0;
		while (underwriterStakes[msg.sender][i] != loan) { i++; }
		delete underwriterStakes[msg.sender][i];

		perUnderwriterStake[loan][proposal][msg.sender] = 0;
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

			if (closed[loan]) {
				uint newPayout = safeSub(safeAdd(underwriterStake, newlyMinted), newlySlashed);
				tokenPayout = safeAdd(tokenPayout, newPayout);

				if (disbursing) {
					delete underwriterStakes[underwriter][i];
				}
			}
		}

		return (minted, slashed, tokenPayout);
	}

	// Called from tranche, not directly, hence the auth modifier
	// TODO: consider rewriting to disburse(address underwriter, uint loan), to avoid the for loop? same for calcStakedDisburse()
	function disburse(address underwriter) public auth returns (uint tokenPayout) {
		(,, tokenPayout) = calcStakedDisburse(underwriter, true);

		safeTransfer(underwriter, tokenPayout);
		totalStaked = safeSub(totalStaked, tokenPayout);
		staked[underwriter] = safeSub(staked[underwriter], tokenPayout);
		// TODO: perUnderwriterStake[loan][proposal][msg.sender] = 0;

		return tokenPayout;
	}

	function setRepaid(uint loan, uint amount) public auth {
		require(!closed[loan], "already-closed");
		repaid[loan] = amount;
		mint(rmul(mintProportion.value, amount));
	}

	function setWrittenOff(uint loan, uint amount) public auth {
		require(!closed[loan], "already-closed");
		writtenOff[loan] = amount;
		safeBurn(rmul(slashProportion.value, amount));

		// if writeoff = 100%, setClosed()
	}

	function setClosed(uint loan) public auth {
		closed[loan] = true;
		bytes32 nftID_ = navFeed.nftID(loan);
		navFeed.update(nftID_, 0, 0);
	}

	function currentStake(uint loan, uint risk, uint value) public view returns (uint) {
		bytes memory proposal = abi.encodePacked(risk, value);
		return proposals[loan][proposal];
	}

	function mint(uint tokenAmount) internal {
		juniorToken.mint(address(this), tokenAmount);
		emit Mint(address(this), tokenAmount);
	}

	function safeBurn(uint tokenAmount) internal {
		uint max = juniorToken.balanceOf(address(this));
		if (tokenAmount > max) {
			tokenAmount = max;
		}
		juniorToken.burn(address(this), tokenAmount);
		emit Burn(address(this), tokenAmount);
	}

	function safeTransfer(address usr, uint amount) internal returns(uint) {
		uint max = juniorToken.balanceOf(address(this));
		if (amount > max) {
			amount = max;
		}
		// require(juniorToken.transfer(usr, amount), "token-transfer-failed");
		juniorToken.transfer(usr, amount);
		return amount;
	}

}