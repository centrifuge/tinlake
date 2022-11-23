// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "tinlake-erc20/erc20.sol";

interface MemberlistLike {
    function hasMember(address) external view returns (bool);
    function member(address) external;
}

/// @notice RestrictedERC20 token only member with a valid (not expired) membership should be allowed to receive tokens
contract RestrictedToken is ERC20 {
    MemberlistLike public memberlist;

    modifier checkMember(address usr) {
        memberlist.member(usr);
        _;
    }

    /// @notice returns true if an address is a member
    /// @param usr the address of the user which should be a member
    /// @return isMember true if the user is a member
    function hasMember(address usr) public view returns (bool isMember) {
        return memberlist.hasMember(usr);
    }

    constructor(string memory symbol_, string memory name_) ERC20(symbol_, name_) {}

    /// @notice sets the dependency to another contract
    /// @param contractName the name of the dependency contract
    /// @param addr the address of the dependency contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "memberlist") memberlist = MemberlistLike(addr);
        else revert();
    }

    /// @notice transferFrom is only possible if receiver is a member
    /// @param from the address of the sender
    /// @param to the address of the receiver
    /// @param amount the amount of tokens to transfer
    function transferFrom(address from, address to, uint256 amount) public override checkMember(to) returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
