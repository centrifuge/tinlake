// Copyright (C) 2019 Centrifuge

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

pragma solidity >=0.5.12;

contract Hevm {
    function warp(uint256) public;
}

contract TitleLike {
    function issue(address) public returns (uint);
    function close(uint) public;
    function ownerOf (uint) public returns (address);
}

contract PileLike {
    function debt(uint loan) public returns(uint);
    function file(uint rate, uint speed) public;
    function setRate(uint loan, uint rate) public;
}

contract TDistributorLike {
    function balance() public;
    function file(bytes32 what, bool flag) public;
}

contract ShelfLike {
    function lock(uint loan) public;
    function unlock(uint loan) public;
    function issue(address registry, uint token) public returns (uint loan);
    function close(uint loan) public;
    function borrow(uint loan, uint wad) public;
    function withdraw(uint loan, uint wad, address usr) public;
    function repay(uint loan, uint wad) public;
    function shelf(uint loan) public returns(address registry,uint256 tokenId,uint price,uint principal, uint initial);
    function file(uint loan, address registry, uint nft) public;
}

contract ERC20Like {
    function transferFrom(address, address, uint) public;
    function mint(address, uint) public;
    function approve(address usr, uint wad) public returns (bool);
    function totalSupply() public returns (uint256);
    function balanceOf(address usr) public returns (uint);
}

contract CeilingLike {
    function values(uint) public view returns(uint);
    function file(uint loan, uint principal) public;
}

contract TOperatorLike {
    TrancheLike public tranche;
    AssessorLike public assessor;
    TDistributorLike public distributor;

    function rely(address usr) public;
    function deny(address usr) public;

    function supply(uint amount) public;
    function redeem(uint amount) public;
}

contract TrancheLike {
    function balance() public returns(uint);
    function tokenSupply() public returns(uint);
}

contract AssessorLike {
    function calcTokenPrice(address tranche) public returns(uint);
}
