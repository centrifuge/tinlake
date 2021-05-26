// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import "tinlake-erc20/erc20.sol";

interface MemberlistLike {
    function hasMember(address) external view returns (bool);
    function member(address) external;
}

// Only mebmber with a valid (not expired) membership should be allowed to receive tokens
contract RestrictedToken is ERC20 {

    MemberlistLike public memberlist; 
    modifier checkMember(address usr) { memberlist.member(usr); _; }
    
    function hasMember(address usr) public view returns (bool) {
        return memberlist.hasMember(usr);
    }

    constructor(string memory symbol_, string memory name_) public ERC20(symbol_, name_) {}

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "memberlist") { memberlist = MemberlistLike(addr); }
        else revert();
    }

    function transferFrom(address from, address to, uint wad) checkMember(to) public override returns (bool) {
        return super.transferFrom(from, to, wad);
    }
}

