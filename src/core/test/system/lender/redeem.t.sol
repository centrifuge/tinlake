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

import "../system.t.sol";
import {SwitchableDistributor} from "../../../lender/distributor/switchable.sol";

contract RedeemTest is SystemTest {

    Investor juniorInvestor;
    address  juniorInvestor_;

    function setUp() public {
        baseSetup();
        WhitelistOperator juniorOperator = WhitelistOperator(lenderDeployer.juniorOperator());
        juniorInvestor = new Investor(address(juniorOperator), currency_, address(lenderDeployer.juniorERC20()));
        juniorInvestor_ = address(juniorInvestor);

        juniorOperator.relyInvestor(juniorInvestor_);
    }

    function supply(uint balance, uint amount) public {
        currency.mint(juniorInvestor_, balance);
        juniorInvestor.doSupply(amount);
    }
    
    function testRedeem() public {
        uint investorBalance = 100 ether;
        uint supplyAmount = 10 ether;
        supply(investorBalance, supplyAmount);
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance - supplyAmount);
        assertEq(lenderDeployer.juniorERC20().balanceOf(juniorInvestor_), supplyAmount);

        SwitchableDistributor switchable = SwitchableDistributor(address(lenderDeployer.distributor()));
        switchable.file("borrowFromTranches", false);
        juniorInvestor.doRedeem(supplyAmount);
        assertEq(lenderDeployer.juniorERC20().balanceOf(juniorInvestor_), 0);
        assertEq(currency.balanceOf(juniorInvestor_), investorBalance);
    }

//    function assertPreCondition(uint loanId, uint tokenId, bytes32 lookupId) public {
//        // assert: borrower owner of loan or owner of nft
//        assert(title.ownerOf(loanId) == borrower_ || collateralNFT.ownerOf(tokenId) == borrower_);
//        // assert: loan has been issued
//        assert(shelf.nftlookup(lookupId) > 0);
//        // assert: nft not locked anymore
//        assert(!shelf.nftLocked(loanId));
//        // assert: loan has no open debt
//        assert(pile.debt(loanId) == 0);
//    }
//
//    function assertPostCondition(uint loanId, uint tokenId, bytes32 lookupId) public {
//        // assert: nft + loan removed nftlookup
//        assertEq(shelf.nftlookup(lookupId), 0);
//
//        // TODO: assert: loan burned => owner = address(0)
//        // current title implementation reverts if loan owner => address(0)
//        //assertEq(title.ownerOf(loanId), address(0));
//    }
}