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

    function propose(uint loan, uint risk, uint value, uint deposit) public {
        bookrunner.propose(loan, risk, value, deposit);
    }

    function stake(uint loan, uint risk, uint value, uint stakeAmount) public {
        bookrunner.stake(loan, risk, value, stakeAmount);
    }

    function accept(uint loan, uint risk, uint value) public {
        bookrunner.accept(loan, risk, value);
    }

    function approve(address usr, uint wad) public {
        juniorToken.approve(usr, wad);
    }

    function disburseStaked() public returns (uint tokenPayout) {
        return juniorOperator.disburseStaked();
    }
    
}
