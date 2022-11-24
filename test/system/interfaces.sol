// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

interface Hevm {
    function warp(uint256) external;
}

interface TitleLike {
    function issue(address) external returns (uint256);
    function close(uint256) external;
    function ownerOf(uint256) external returns (address);
}

interface TokenLike {
    function totalSupply() external returns (uint256);
    function balanceOf(address) external returns (uint256);
    function transferFrom(address, address, uint256) external;
    function approve(address, uint256) external;
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

interface NAVFeedLike {
    function update(bytes32 nftID, uint256 value) external;
    function update(bytes32 nftID, uint256 value, uint256 risk) external;
    function ceiling(uint256 loan) external view returns (uint256);
    function values(uint256) external view returns (uint256);
    function ceilingRatio(uint256) external view returns (uint256);
    function thresholdRatio(uint256) external view returns (uint256);
    function threshold(uint256) external view returns (uint256);
    // function file(bytes32 what, uint loan, uint currencyAmount) external;
    function borrow(uint256 loan, uint256 currencyAmount) external;
    function repay(uint256 loan, uint256 currencyAmount) external;
    function file(bytes32 what, bytes32 nftID_, uint256 maturityDate_) external;
    function file(bytes32 name, uint256 risk_, uint256 thresholdRatio_, uint256 ceilingRatio_, uint256 rate_)
        external;
    function latestNAV() external returns (uint256);
    function currentNAV() external returns (uint256);
    function calcUpdateNAV() external returns (uint256);
    function init() external;
    function writeOff(uint256 loan, uint256 writeOffGroupIndex_) external;
    function overrideWriteOff(uint256 loan, uint256 writeOffGroupIndex_) external;
}

interface PileLike {
    function debt(uint256 loan) external returns (uint256);
    function file(bytes32 what, uint256 rate, uint256 speed) external;
    function setRate(uint256 loan, uint256 rate) external;
}

interface TReserveLike {
    function balance() external;
    function file(bytes32 what, bool flag) external;
}

interface ShelfLike {
    function lock(uint256 loan) external;
    function unlock(uint256 loan) external;
    function issue(address registry, uint256 token) external returns (uint256 loan);
    function close(uint256 loan) external;
    function borrow(uint256 loan, uint256 wad) external;
    function withdraw(uint256 loan, uint256 wad, address usr) external;
    function repay(uint256 loan, uint256 wad) external;
    function shelf(uint256 loan)
        external
        returns (address registry, uint256 tokenId, uint256 price, uint256 principal, uint256 initial);
    function file(bytes32 what, uint256 loan, address registry, uint256 nft) external;
}

interface ERC20Like {
    function transferFrom(address, address, uint256) external;
    function mint(address, uint256) external;
    function approve(address usr, uint256 wad) external returns (bool);
    function totalSupply() external returns (uint256);
    function balanceOf(address usr) external returns (uint256);
}

interface TrancheLike {
    function balance() external returns (uint256);
    function tokenSupply() external returns (uint256);
}

interface MemberlistLike {
    function updateMember(address usr, uint256 validUntil) external;
    function removeMember(address usr, uint256 validUntil) external;
}
