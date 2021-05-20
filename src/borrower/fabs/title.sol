// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Title } from "tinlake-title/title.sol";

contract TitleFab {
    function newTitle(string memory name, string memory symbol) public returns (address) {
        Title title = new Title(name, symbol);
        title.rely(msg.sender);
        title.deny(address(this));
        return address(title);
    }
}
