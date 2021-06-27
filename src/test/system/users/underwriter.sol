// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Underwriter {

    BookrunnerLike bookrunner;

    constructor(address bookrunner_) {
        bookrunner = BookrunnerLike(bookrunner_);
    }

    function propose(bytes32 nftID, uint risk, uint value, uint deposit) public {
        bookrunner.propose(nftID, risk, value, deposit);
    }

    function addStake(bytes32 nftID, uint risk, uint value, uint stakeAmount) public {
        bookrunner.addStake(nftID, risk, value, stakeAmount);
    }

    function accept(bytes32 nftID, uint risk, uint value) public {
        bookrunner.accept(nftID, risk, value);
    }
    
}
