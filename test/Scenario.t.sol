// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "../src/Deposit.sol";
// import "../src/BNFT.sol";
// import "../src/TNFT.sol";
// import "../src/Auction.sol";

// contract ScenarioTest is Test {
//     Deposit public depositInstance;
//     BNFT public TestBNFTInstance;
//     TNFT public TestTNFTInstance;
//     Auction public auctionInstance;

//     address owner = vm.addr(1);
//     address alice = vm.addr(2);

//     function setUp() public {
//         vm.startPrank(owner);
//         auctionInstance = new Auction();
//         depositInstance = new Deposit(address(auctionInstance));
//         TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
//         TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
//         vm.stopPrank();
//     }

//     function testOneBidderWithOneStake() public {
//         startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.1 ether}();

//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//             ),
//             0
//         );
//         assertEq(address(auctionInstance).balance, 0.1 ether);
//         assertEq(address(depositInstance).balance, 0);

//         (
//             uint256 winningBidId,
//             uint256 numberOfBids,
//             ,
//             ,
//             bool isActive
//         ) = auctionInstance.auctions(auctionInstance.numberOfAuctions() - 1);
//         (uint256 amount, , address bidderAddress) = auctionInstance.bids(
//             auctionInstance.numberOfAuctions() - 1,
//             winningBidId
//         );

//         assertEq(winningBidId, 0);
//         assertEq(numberOfBids, 1);
//         assertEq(amount, 0.1 ether);
//         assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         assertEq(isActive, true);

//         depositInstance.deposit{value: 0.1 ether}();
//         assertEq(
//             TestBNFTInstance.ownerOf(0),
//             0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//         );
//         assertEq(
//             TestTNFTInstance.ownerOf(0),
//             0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//         );
//         assertEq(address(depositInstance).balance, 0.1 ether);

//         (, , , , bool isActive2) = auctionInstance.auctions(
//             auctionInstance.numberOfAuctions() - 1
//         );
//         assertEq(isActive2, false);
//     }

//     function testTwoBidderWithOneStakeAndRefundForLosingBidder() public {
//         //Bid 1
//         startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.1 ether}();

//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//             ),
//             0
//         );
//         assertEq(address(auctionInstance).balance, 0.1 ether);
//         assertEq(address(depositInstance).balance, 0);

//         (
//             uint256 winningBidIdAfterBid1,
//             uint256 numberOfBidsAfterBid1,
//             ,
//             ,
//             bool isActiveAfterBid1
//         ) = auctionInstance.auctions(auctionInstance.numberOfAuctions() - 1);
//         (
//             uint256 amountOfBid1,
//             ,
//             address bidderAddressAfterBid1
//         ) = auctionInstance.bids(
//                 auctionInstance.numberOfAuctions() - 1,
//                 winningBidIdAfterBid1
//             );

//         assertEq(winningBidIdAfterBid1, 0);
//         assertEq(numberOfBidsAfterBid1, 1);
//         assertEq(amountOfBid1, 0.1 ether);
//         assertEq(
//             bidderAddressAfterBid1,
//             0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//         );
//         assertEq(isActiveAfterBid1, true);

//         vm.stopPrank();

//         //Bid 2
//         startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
//         auctionInstance.bidOnStake{value: 0.4 ether}();

//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//             ),
//             0.1 ether
//         );
//         assertEq(address(auctionInstance).balance, 0.5 ether);
//         assertEq(address(depositInstance).balance, 0);

//         (
//             uint256 winningBidIdAfterBid2,
//             uint256 numberOfBidsAfterBid2,
//             ,
//             ,
//             bool isActiveAfterBid2
//         ) = auctionInstance.auctions(auctionInstance.numberOfAuctions() - 1);
//         (
//             uint256 amountOfBid2,
//             ,
//             address bidderAddressAfterBid2
//         ) = auctionInstance.bids(
//                 auctionInstance.numberOfAuctions() - 1,
//                 winningBidIdAfterBid2
//             );

//         assertEq(winningBidIdAfterBid2, 1);
//         assertEq(numberOfBidsAfterBid2, 2);
//         assertEq(isActiveAfterBid2, true);
//         assertEq(amountOfBid2, 0.4 ether);
//         assertEq(
//             bidderAddressAfterBid2,
//             0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
//         );

//         depositInstance.deposit{value: 0.1 ether}();
//         assertEq(
//             TestBNFTInstance.ownerOf(0),
//             0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
//         );
//         assertEq(
//             TestTNFTInstance.ownerOf(0),
//             0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
//         );
//         assertEq(address(depositInstance).balance, 0.1 ether);
//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//             ),
//             0.1 ether
//         );

//         (, , , , bool isActiveAfterStake) = auctionInstance.auctions(
//             auctionInstance.numberOfAuctions() - 1
//         );
//         assertEq(isActiveAfterStake, false);

//         vm.stopPrank();
//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.claimRefundableBalance();
//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//             ),
//             0
//         );
//         assertEq(
//             auctionInstance.refundBalances(
//                 0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
//             ),
//             0
//         );
//         assertEq(address(depositInstance).balance, 0.1 ether);
//         assertEq(address(auctionInstance).balance, 0.4 ether);
//     }
// }
