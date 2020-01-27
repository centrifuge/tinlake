// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

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

pragma solidity >=0.5.3;

import "tinlake-math/math.sol";
import "tinlake-auth/auth.sol";

contract SimpleToken is Auth, Math {

    // --- ERC20 Data ---
    uint8   public decimals = 18;
    string  public name;
    string  public symbol;
    string  public version;
    uint256 public totalSupply;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;
    mapping (address => uint)                      public nonces;

    event Approval(address indexed src, address indexed usr, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)"
    );

    constructor(string memory symbol_, string memory name_, string memory version_, uint256 chainId_) public {
        symbol = symbol_;
        name = name_;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Dai Semi-Automated Permit Office"),
            keccak256(bytes(version_)),
            chainId_,
            address(this)
        ));
    }

    // --- Token ---
    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad)
        public returns (bool)
    {
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            allowance[src][msg.sender] = safeSub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = safeSub(balanceOf[src], wad);
        balanceOf[dst] = safeAdd(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }
    function mint(address usr, uint wad) public {
        balanceOf[usr] = safeAdd(balanceOf[usr], wad);
        totalSupply    = safeAdd(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }
    function burn(address usr, uint wad) public {
        if (usr != msg.sender && allowance[usr][msg.sender] != uint(-1)) {
            allowance[usr][msg.sender] = safeSub(allowance[usr][msg.sender], wad);
        }
        balanceOf[usr] = safeSub(balanceOf[usr], wad);
        totalSupply    = safeSub(totalSupply, wad);
        emit Transfer(usr, address(0), wad);
    }
    function approve(address usr, uint wad) public returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    // --- Alias ---
    function push(address usr, uint wad) public {
        transferFrom(msg.sender, usr, wad);
    }
    function pull(address usr, uint wad) public {
        transferFrom(usr, msg.sender, wad);
    }
    function move(address src, address dst, uint wad) public {
        transferFrom(src, dst, wad);
    }
}
