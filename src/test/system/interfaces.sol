// Copyright (C) 2020 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

interface NFTFeedLike {
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
    function approximatedNAV() external returns (uint);
    function currentNAV() external returns (uint);
    function calcUpdateNAV() external returns (uint);
}

interface PileLike {
    function debt(uint loan) external returns(uint);
    function file(bytes32 what, uint rate, uint speed) external;
    function setRate(uint loan, uint rate) external;
}

interface TDistributorLike {
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
    function transferFrom(address, address, uint) external;
    function mint(address, uint) external;
    function approve(address usr, uint wad) external returns (bool);
    function totalSupply() external returns (uint256);
    function balanceOf(address usr) external returns (uint);
}

interface TrancheLike {
    function balance() external returns(uint);
    function tokenSupply() external returns(uint);
}

interface CollectorLike {
    function collect(uint loan) external;
    function collect(uint loan, address buyer) external;
    function file(bytes32 what, uint loan, address buyer, uint price) external;
    function relyCollector(address user) external;
}

interface ThresholdLike {
    function set(uint, uint) external;
}

interface MemberlistLike {
    function updateMember(address usr, uint validUntil) external;
    function removeMember(address usr, uint validUntil) external;
}
