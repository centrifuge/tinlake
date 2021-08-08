// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.6.12;
// pragma experimental ABIEncoderV2;

// import "../base_system.sol";

// contract WriteOffTest is BaseSystemTest {

//     function setUp() public {
//         baseSetup();
//         createTestUsers();
//         hevm = Hevm(HEVM_ADDRESS);
//         hevm.warp(1234567);
//     }

//     function fundTranches(uint amount) public {
//         defaultInvest(amount);
//         hevm.warp(block.timestamp + 1 days);
//         coordinator.closeEpoch();
//     }

//     function borrow(uint loanId, uint tokenId, uint amount, uint fixedFee) public {
//         uint initialTotalBalance = shelf.balance();
//         uint initialLoanBalance = shelf.balances(loanId);
//         uint initialLoanDebt = pile.debt(loanId);
//         uint initialCeiling = nftFeed.ceiling(loanId);

//         fundTranches(amount);
//         borrower.borrow(loanId, amount);
//     }

//     function testDefaultWriteOffSchedule() public {
//         uint nftPrice = 500 ether;
//         uint riskGroup = 0;

//         (uint tokenId, uint loanId) = issueNFTAndCreateLoan(borrower_);
//         // price nft
//         priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
//         uint ceiling = computeCeiling(riskGroup, nftPrice);
//         // lock nft for borrower
//         lockNFT(loanId, borrower_);
//         // set ceiling based tokenPrice & riskgroup

//         assertPreCondition(loanId, tokenId, ceiling);
//         borrow(loanId, tokenId, ceiling, 0);


//     }

// }
