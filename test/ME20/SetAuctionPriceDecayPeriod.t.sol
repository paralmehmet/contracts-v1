/// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {DeployersME20} from "../utils/DeployersME20.sol";
import {Constant} from "../../src/libraries/Constant.sol";

contract SetAuctionPriceDecayPeriod is DeployersME20 {
    error InvalidAuctionDuration();
    /// @dev Emited when the treasury is updated

    /// @dev Emited when the auction duration is updated
    event AuctionDurationUpdated(uint256 oldDuration, uint256 newDuration);

    function test_setAuctionPriceDecayPeriod_success() public {
        vm.expectEmit(true, true, false, true);
        emit AuctionDurationUpdated(memeception.auctionPriceDecayPeriod(), Constant.MIN_AUCTION_PRICE_DECAY_PERIOD);
        memeceptionBaseTest.setAuctionPriceDecayPeriod(Constant.MIN_AUCTION_PRICE_DECAY_PERIOD);
    }

    function test_setAuctionPriceDecayPeriod_success_max() public {
        vm.expectEmit(true, true, false, true);
        emit AuctionDurationUpdated(memeception.auctionPriceDecayPeriod(), Constant.MAX_AUCTION_PRICE_DECAY_PERIOD);
        memeceptionBaseTest.setAuctionPriceDecayPeriod(Constant.MAX_AUCTION_PRICE_DECAY_PERIOD);
    }

    function test_setAuctionPriceDecayPeriod_fail_not_owner() public {
        vm.expectRevert("UNAUTHORIZED");
        hoax(makeAddr("alice"));
        memeception.setAuctionPriceDecayPeriod(Constant.MIN_AUCTION_PRICE_DECAY_PERIOD);
    }

    function test_setAuctionPriceDecayPeriod_fail_zero() public {
        vm.expectRevert(InvalidAuctionDuration.selector);
        memeceptionBaseTest.setAuctionPriceDecayPeriod(0);
    }

    function test_setAuctionPriceDecayPeriod_fail_below_min() public {
        vm.expectRevert(InvalidAuctionDuration.selector);
        memeceptionBaseTest.setAuctionPriceDecayPeriod(Constant.MIN_AUCTION_PRICE_DECAY_PERIOD - 1);
    }

    function test_setAuctionPriceDecayPeriod_fail_above_max() public {
        vm.expectRevert(InvalidAuctionDuration.selector);
        memeceptionBaseTest.setAuctionPriceDecayPeriod(Constant.MAX_AUCTION_PRICE_DECAY_PERIOD + 1);
    }
}
