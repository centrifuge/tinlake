// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;

import { Title } from "tinlake-title/title.sol";
import "../interfaces.sol";

contract Underwriter {

    BookrunnerLike bookrunner;
    ERC20Like juniorToken;
    OperatorLike juniorOperator;

    constructor(address bookrunner_, address juniorToken_, address juniorOperator_) {
        bookrunner = BookrunnerLike(bookrunner_);
        juniorToken = ERC20Like(juniorToken_);
        juniorOperator = OperatorLike(juniorOperator_);
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

    function approve(address usr, uint wad) public {
        juniorToken.approve(usr, wad);
    }

    function disburseStaked() public returns (uint minted, uint burned) {
        return juniorOperator.disburseStaked();
    }
    
}
