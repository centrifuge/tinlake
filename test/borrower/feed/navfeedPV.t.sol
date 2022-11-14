// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity >=0.7.6;

// import "ds-test/test.sol";
// import "tinlake-math/interest.sol";
// import "./../../test/mock/shelf.sol";
// import "./../../test/mock/pile.sol";
// import "../navfeedPV.sol";

// contract NFTFeedTest is DSTest, Math {
//     NAVFeedPV public feed;
//     ShelfMock shelf;
//     PileMock pile;

//     uint256 defaultRate;
//     uint256 defaultThresholdRatio;
//     uint256 defaultCeilingRatio;

//     function setUp() public {
//         // default values
//         defaultThresholdRatio = 8 * 10 ** 26; // 80% threshold
//         defaultCeilingRatio = 6 * 10 ** 26; // 60% ceiling
//         defaultRate = uint256(1000000564701133626865910626); // 5 % day

//         feed = new NAVFeedPV();
//         pile = new PileMock();
//         shelf = new ShelfMock();
//         feed.depend("shelf", address(shelf));
//         feed.depend("pile", address(pile));

//         feed.file(
//             "riskGroup",
//             0, // riskGroup:       0
//             8 * 10 ** 26, // thresholdRatio   80%
//             6 * 10 ** 26, // ceilingRatio     60%
//             ONE // interestRate     1.0
//         );
//     }

//     function testNFTValues() public {
//         bytes32 nftID = feed.nftID(address(1), 1);
//         uint256 value = 100 ether;
//         feed.update(nftID, value);

//         uint256 loan = 1;
//         shelf.setReturn("shelf", address(1), 1);

//         assertEq(feed.nftValues(nftID), 100 ether);
//         assertEq(feed.threshold(loan), 80 ether);
//         assertEq(feed.ceiling(loan), 60 ether);
//     }
// }
