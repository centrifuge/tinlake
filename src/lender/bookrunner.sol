// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";
import "./../fixed_point.sol";
import "ds-test/test.sol";

interface NAVFeedLike {
    function update(bytes32 nftID_, uint value) external;
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

abstract contract AssessorLike is FixedPoint {
    function calcJuniorTokenPrice() public virtual returns(Fixed27 memory tokenPrice);
}

contract Bookrunner is Auth, Math, FixedPoint, DSTest {

    // --- Dependencies ---
    NAVFeedLike     public navFeed;
    ERC20Like       public juniorToken;
    MemberlistLike  public memberlist; 
    AssessorLike    public assessor; 

    // --- Data ---
    uint    public minimumDeposit   = 10 ether;                     // Absolute min TIN required to propose a new asset
    Fixed27 public minimumStake     = Fixed27(0.10 * 10**27);       // The stake threshold required relative to the NFT value
    Fixed27 public rewardRate       = Fixed27(0.01 * 10**27);       //  % of the repaid amount that is minted in TIN tokens for the underwriters

    uint                                                            public totalStaked;         // Total amount staked (tokens held by this contract)
    mapping (uint => mapping (bytes => uint))                       public proposals;           // Total amount that is staked for each <loan, <risk, value>> tuple
    mapping (uint => uint)                                          public largestStake;        // Largest stake to any proposal for a loan
    mapping (uint => bytes)                                         public acceptedProposals;   // <risk, value> pair for each loan that was accepted
    mapping (address => uint[])                                     public underwriterStakes;   // List of loans which an underwriter has staked towards
    mapping (uint => mapping (bytes => mapping (address => uint)))  public perUnderwriterStake; // Amount that is staked for each <loan, <risk, value>, underwriter> tuple
    mapping (uint => uint)                                          public repaid;              // Amount repaid per loan
    mapping (uint => uint)                                          public writtenOff;          // Amount written off per loan
    mapping (uint => bool)                                          public closed;              // Whether the loan has been closed

    // --- Events ---
    event Propose(uint indexed loan, uint risk, uint value, uint deposit);
    event Stake(uint indexed loan, uint risk, uint value, uint stakeAmount);
    event Unstake(uint indexed loan, uint risk, uint value);
    event Accept(uint indexed loan, uint risk, uint value);
    event Mint(address indexed usr, uint amount);
    event Burn(address indexed usr, uint amount);

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

     // --- Administration ---
    function file(bytes32 name, uint value) public auth {
        if (name == "minimumDeposit") {
            minimumDeposit = value;
        } else if (name == "minimumStake") {
            minimumStake = Fixed27(value);
        } else if (name == "rewardRate") {
            rewardRate = Fixed27(value);
        } else { revert("unknown-name");}
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "juniorToken") { juniorToken = ERC20Like(addr); }
        else if (contractName == "navFeed") { navFeed = NAVFeedLike(addr); }
        else if (contractName == "memberlist") { memberlist = MemberlistLike(addr); }
        else if (contractName == "assessor") { assessor = AssessorLike(addr); }
        else revert();
    }

     // --- Staking ---
    function propose(uint loan, uint risk, uint value, uint deposit) public {
        require(deposit >= minimumDeposit, "min-deposit-required"); // TODO: minimumDeposit should be in currency?
        require(acceptedProposals[loan].length == 0, "asset-already-accepted");
        require(juniorToken.balanceOf(msg.sender) >= deposit, "insufficient-balance");

        bytes memory proposal = abi.encodePacked(risk, value);
        require(proposals[loan][proposal] == 0, "proposal-already-exists");

        juniorToken.transferFrom(msg.sender, address(this), deposit);
        totalStaked = safeAdd(totalStaked, deposit);

        proposals[loan][proposal] = deposit;
        perUnderwriterStake[loan][proposal][msg.sender] = deposit;
        underwriterStakes[msg.sender].push(loan);

        emit Propose(loan, risk, value, deposit);
    }

    // Staking in opposition of an asset can be done by staking with a value of 0.
    function stake(uint loan, uint risk, uint value, uint stakeAmount) public memberOnly {
        require(acceptedProposals[loan].length == 0, "asset-already-accepted");

        bytes memory proposal = abi.encodePacked(risk, value);
        uint prevPerUnderwriterStake = perUnderwriterStake[loan][proposal][msg.sender];
        require(stakeAmount <= prevPerUnderwriterStake || juniorToken.balanceOf(msg.sender) >= safeSub(stakeAmount, prevPerUnderwriterStake), "insufficient-balance");
        require(stakeAmount > 0, "requires-unstaking"); // unstake() should be called for setting the stake to 0

        uint newStake;
        if (stakeAmount > prevPerUnderwriterStake) {
            uint increase = safeSub(stakeAmount, prevPerUnderwriterStake);
            juniorToken.transferFrom(msg.sender, address(this), increase);

            totalStaked = safeAdd(totalStaked, increase);
            newStake = safeAdd(proposals[loan][proposal], increase);
            perUnderwriterStake[loan][proposal][msg.sender] = safeAdd(prevPerUnderwriterStake, increase);
        } else if (stakeAmount < prevPerUnderwriterStake) {
            uint decrease = safeSub(prevPerUnderwriterStake, stakeAmount);
            juniorToken.transfer(msg.sender, decrease);

            totalStaked = safeSub(totalStaked, decrease);
            newStake = safeSub(proposals[loan][proposal], decrease);
            perUnderwriterStake[loan][proposal][msg.sender] = safeSub(prevPerUnderwriterStake, decrease);
        }

        if (prevPerUnderwriterStake == 0) {
            underwriterStakes[msg.sender].push(loan);
        }

        proposals[loan][proposal] = newStake;
        if (newStake > largestStake[loan]) {
            largestStake[loan] = newStake;
        }

        emit Stake(loan, risk, value, stakeAmount);
    }

    function unstake(uint loan, uint risk, uint value) public memberOnly {
        bytes memory proposal = abi.encodePacked(risk, value);
        require(keccak256(acceptedProposals[loan]) != keccak256(proposal), "cannot-unstake-accepted-proposal");

        uint stakeAmount = perUnderwriterStake[loan][proposal][msg.sender];
        proposals[loan][proposal] = safeSub(proposals[loan][proposal], stakeAmount);
        
        safeTransfer(msg.sender, stakeAmount);
        totalStaked = safeSub(totalStaked, stakeAmount);

        uint i = 0;
        while (underwriterStakes[msg.sender][i] != loan) { i++; }
        delete underwriterStakes[msg.sender][i];

        emit Unstake(loan, risk, value);
    }

    function accept(uint loan, uint risk, uint value) public {
        bytes memory proposal = abi.encodePacked(risk, value);
        require(proposals[loan][proposal] == largestStake[loan], "not-largest-stake");

        Fixed27 memory juniorTokenPrice = assessor.calcJuniorTokenPrice();
        require(rmul(proposals[loan][proposal], juniorTokenPrice.value) >= rmul(minimumStake.value, value), "stake-threshold-not-reached");

        // TODO: If there are more assets that qualify than liquidity to finance them, only those with the largest stake get financed in that time period.
        // + preference to finance assets with highest stake without no votes

        // Set the risk group and value in the NAV feed
        bytes32 nftID_ = navFeed.nftID(loan);
        navFeed.update(nftID_, value, risk);

        acceptedProposals[loan] = proposal;
        emit Accept(loan, risk, value);
    }

    // --- Utils ---
    modifier memberOnly { require(memberlist.hasMember(msg.sender), "not-allowed-to-underwrite"); _; }

    function assetWasAccepted(uint loan) public view returns (bool) {
        return acceptedProposals[loan].length != 0;
    }

    // TODO: rewrite to calcDisburse and calcMintedSlashed?
    function calcStakedDisburse(address underwriter, bool disbursing) public view returns (uint minted, uint slashed, uint tokenPayout) {
        uint[] memory loans = underwriterStakes[underwriter];

        for (uint i = 0; i < loans.length; i++) {
            uint loan = loans[i];
            bytes memory acceptedProposal = acceptedProposals[loan];
            uint underwriterStake = perUnderwriterStake[loan][acceptedProposal][underwriter];
            uint proposalStake = proposals[loan][acceptedProposal];
            uint256 relativeStake = rdiv(underwriterStake, proposalStake);

            // (mint proportion * (relative stake * repaid amount))
            uint newlyMinted = rmul(rewardRate.value, rmul(relativeStake, repaid[loan]));
            minted = safeAdd(minted, newlyMinted);

            // relative stake * written off amount
            uint newlySlashed = rmul(relativeStake, min(writtenOff[loan], proposalStake));
            slashed = safeAdd(slashed, newlySlashed);

            // TODO: if an asset is defaulting and there was a vote against, part of the slash is going to this vote
            // => store votesAgainst[loan] for any stakes with value = 0

            if (closed[loan]) {
                uint newPayout = safeSub(safeAdd(underwriterStake, newlyMinted), newlySlashed);
                tokenPayout = safeAdd(tokenPayout, newPayout);

                // TODO: rewrite s.t. this can be in disburse, then make calcStakedDisburse a view method
                // if (disbursing) {
                //     delete underwriterStakes[underwriter][i];
                // }
            }
        }

        return (minted, slashed, tokenPayout);
    }

    // Called from tranche, not directly, hence the auth modifier
    function disburse(address underwriter) public auth returns (uint) {
        (,, uint tokenPayout) = calcStakedDisburse(underwriter, true);

        safeTransfer(underwriter, tokenPayout);
        totalStaked = safeSub(totalStaked, tokenPayout);

        return tokenPayout;
    }

    function setRepaid(uint loan, uint amount) public auth {
        require(!closed[loan], "already-closed");
        
        // TODO: repaid amount should be converted from currency into tokens, since if the TIN price has dropped, more tokens should be minted?

        repaid[loan] = amount;
        mint(rmul(rewardRate.value, amount));
    }

    // Write-off the loan, and burn the associated stake. If the writeoff amount is less than the stake,
    // then the TIN price will stay constant (as NAV drop == TIN supply decrease). If the writeoff amount
    // is more than the stake, then the TIN price will start going down.
    function setWrittenOff(uint loan, uint writeoffPercentage, uint amount) public auth {
        require(!closed[loan], "already-closed");

        // TODO: amount should be converted from currency into tokens, since if the TIN price has dropped, more tokens should be burned?
        // maybe repaid[] and writtenOff[] should be stored in currency, since if the price changes between the repay and disburse(),
        // the new price should be used for the conversion?

        bytes memory acceptedProposal = acceptedProposals[loan];
        uint alreadyWrittenOff = writtenOff[loan];
        uint newlyWrittenOff = safeSub(amount, alreadyWrittenOff);

        uint stakeToBurn = 0;
        if (proposals[loan][acceptedProposal] > alreadyWrittenOff) {
            stakeToBurn = safeSub(proposals[loan][acceptedProposal], alreadyWrittenOff); 
        }
        
        safeBurn(min(newlyWrittenOff, stakeToBurn));
        writtenOff[loan] = amount;

        // Close if 100% written off
        if (writeoffPercentage == 10**27) {
            setClosed(loan);
        }
    }

    function setClosed(uint loan) public auth {
        closed[loan] = true;

        // Set value to 0 so no new loan can be opened against this NFT until it has gone through underwriting again
        bytes32 nftID_ = navFeed.nftID(loan);
        navFeed.update(nftID_, 0);
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