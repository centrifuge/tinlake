// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

interface Hevm {
    function warp(uint256) external;
}

interface TitleLike {
    function issue(address) external returns (uint);
    function close(uint) external;
    function ownerOf (uint) external returns (address);
}

interface TokenLike{
    function totalSupply() external returns (uint);
    function balanceOf(address) external returns (uint);
    function transferFrom(address,address,uint) external;
    function approve(address, uint) external;
    function mint(address, uint) external;
    function burn(address, uint) external;
}

interface NAVFeedLike {
    function rely(address addr) external;
    function update(bytes32 nftID, uint value) external;
    function update(bytes32 nftID, uint value, uint risk) external;
    function ceiling(uint loan) external view returns(uint);
    function values(uint) external view returns(uint);
    function ceilingRatio(uint) external view returns(uint);
    function thresholdRatio(uint) external view returns(uint);
    function threshold(uint) external view returns (uint);
    // function file(bytes32 what, uint loan, uint currencyAmount) external;
    function borrow(uint loan, uint currencyAmount) external;
    function repay(uint loan, uint currencyAmount) external;
    function file(bytes32 what, bytes32 nftID_, uint maturityDate_) external;
    function latestNAV() external returns (uint);
    function currentNAV() external returns (uint);
    function calcUpdateNAV() external returns (uint);
    function init() external;
    function writeOff(uint loan, uint writeOffGroupIndex_) external;
    function overrideWriteOff(uint loan, uint writeOffGroupIndex_) external;
}

interface PileLike {
    function debt(uint loan) external returns(uint);
    function file(bytes32 what, uint rate, uint speed) external;
    function setRate(uint loan, uint rate) external;
}

interface TReserveLike {
    function balance() external;
    function file(bytes32 what, bool flag) external;
}

interface ShelfLike {
    function lock(uint loan) external;
    function unlock(uint loan) external;
    function issue(address registry, uint token) external returns (uint loan);
    function close(uint loan) external;
    function borrow(uint loan, uint wad) external;
    function withdraw(uint loan, uint wad, address usr) external;
    function repay(uint loan, uint wad) external;
    function shelf(uint loan) external returns(address registry,uint256 tokenId,uint price,uint principal, uint initial);
    function file(bytes32 what, uint loan, address registry, uint nft) external;
}

interface ERC20Like {
    function rely(address addr) external;
    function transferFrom(address, address, uint) external;
    function mint(address, uint) external;
    function approve(address usr, uint wad) external returns (bool);
    function totalSupply() external returns (uint256);
    function balanceOf(address usr) external returns (uint);
}

interface TrancheLike {
    function rely(address addr) external;
    function balance() external returns(uint);
    function tokenSupply() external returns(uint);
}

interface CollectorLike {
    function collect(uint loan) external;
    function collect(uint loan, address buyer) external;
    function file(bytes32 what, uint loan, address buyer, uint price) external;
    function relyCollector(address user) external;
}

interface MemberlistLike {
    function updateMember(address usr, uint validUntil) external;
    function removeMember(address usr, uint validUntil) external;
}

interface OperatorLike {
    function supplyOrder(uint currencyAmount) external;
    function redeemOrder(uint redeemAmount) external;
    function disburse() external returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
}

interface BookrunnerLike {
    function memberlist() external view returns (address);
    function propose(uint loan, uint risk, uint value, uint deposit) external;
    function stake(uint loan, uint risk, uint value, uint stakeAmount) external;
    function accept(uint loan, uint risk, uint value) external;
    function disburse() external returns (uint tokenPayout);
}
