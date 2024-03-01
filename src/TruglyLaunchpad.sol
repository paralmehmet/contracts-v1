/// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {LinearVRGDA} from "@transmissions11/LinearVRGDA.sol";
import {wadDiv} from "@solmate/utils/SignedWadMath.sol";

import {Constant} from "./libraries/Constant.sol";
import {FullMath} from "./libraries/external/FullMath.sol";
import {INonfungiblePositionManager} from "./interfaces/external/INonfungiblePositionManager.sol";
import {ITruglyLaunchpad} from "./interfaces/ITruglyLaunchpad.sol";
import {IUniswapV3Factory} from "./interfaces/external/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "./interfaces/external/IUniswapV3Pool.sol";
import {ITruglyVesting} from "./interfaces/ITruglyVesting.sol";
import {MEMERC20} from "./types/MEMERC20.sol";
import {SafeCast} from "./libraries/external/SafeCast.sol";
import {SqrtPriceX96} from "./libraries/external/SqrtPriceX96.sol";

/// @title The interface for the Trugly Launchpad
/// @notice Launchpad is in charge of creating MEMERC20 and their Memeception
contract TruglyLaunchpad is ITruglyLaunchpad, Constant, Owned, LinearVRGDA {
    using FullMath for uint256;
    using SafeCast for uint256;
    using SafeTransferLib for WETH;
    using SafeTransferLib for MEMERC20;
    using SafeTransferLib for address;

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       EVENTS                      */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/

    /// @dev Emitted when a memeceptions is created
    event MemeCreated(
        address indexed memeToken,
        address indexed creator,
        uint80 cap,
        uint40 startAt,
        uint16 creatorSwapFeeBps,
        uint16 vestingAllocBps
    );

    /// @dev Emitted when a OG participates in the memeceptions
    event MemeceptionBid(address indexed memeToken, address indexed og, uint256 amountETH, uint256 amountMeme);

    /// @dev Emitted when liquidity has been added to the UniV3 Pool
    event MemeLiquidityAdded(address indexed memeToken, uint256 amount0, uint256 amount1);

    /// @dev Emitted when an OG claims their allocated Meme tokens
    event MemeClaimed(address indexed memeToken, address indexed claimer, uint256 amountMeme, uint256 refundETH);

    /// @dev Emitted when an OG exits the memeceptions
    event MemeceptionExit(address indexed memeToken, address indexed backer, uint256 amount);

    //     event CollectProtocolFees(address indexed token, address recipient, uint256 amount);

    //     event CollectLPFees(address indexed token, address recipient, uint256 amount);

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       ERRORS                      */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/

    /// @dev Thrown when the swap fee is too high
    error MemeSwapFeeTooHigh();

    /// @dev Thrown when the vesting allocation is too high
    error VestingAllocTooHigh();

    /// @dev Thrown when the Meme symbol already exists
    error MemeSymbolExist();

    /// @dev Thrown when the memeceptions startAt is invalid (too early/too late)
    error InvalidMemeceptionDate();

    /// @dev Thrown when the memeceptions ended and the Meme pool is launched
    error MemeLaunched();

    /// @dev Thrown when the Meme pool is not launche
    error MemeNotLaunched();

    /// @dev Thrown when address is address(0)
    error ZeroAddress();

    /// @dev Thrown when a OG has already participated in the memeceptions
    error DuplicateOG();

    /// @dev Thrown when the amount is 0
    error ZeroAmount();

    /// @dev Thrown when the amount is too high
    error BidAmountTooHigh();

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       STORAGE                     */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/

    /// @dev Zero bytes
    bytes internal constant ZERO_BYTES = new bytes(0);

    /// @dev Address of the UniswapV3 Factory
    IUniswapV3Factory public immutable v3Factory;

    /// @dev Address of the UniswapV3 NonfungiblePositionManager
    INonfungiblePositionManager public immutable v3PositionManager;

    /// @dev Vesting contract for MEMERC20 tokens
    ITruglyVesting public immutable vesting;

    /// @dev Address of the WETH9 contract
    WETH public immutable WETH9;

    /// @dev Mapping of memeToken => memeceptions
    mapping(address => Memeception) private memeceptions;

    /// @dev Amount bid by OGs
    mapping(address => mapping(address => Bid)) bidsOG;

    /// @dev Mapping to determine if a token symbol already exists
    mapping(string => bool) private memeSymbolExist;

    constructor(address _v3Factory, address _v3PositionManager, address _WETH9, address _vesting)
        LinearVRGDA(AUCTION_TARGET_PRICE, AUCTION_PRICE_DECAY_PCT, AUCTION_TOKEN_PER_TIME_UNIT)
        Owned(msg.sender)
    {
        if (
            _v3Factory == address(0) || _v3PositionManager == address(0) || _WETH9 == address(0)
                || _vesting == address(0)
        ) {
            revert ZeroAddress();
        }
        v3Factory = IUniswapV3Factory(_v3Factory);
        v3PositionManager = INonfungiblePositionManager(_v3PositionManager);
        WETH9 = WETH(payable(_WETH9));
        vesting = ITruglyVesting(_vesting);
    }

    /// @inheritdoc ITruglyLaunchpad
    function createMeme(MemeCreationParams calldata params) external returns (address, address) {
        _verifyCreateMeme(params);
        MEMERC20 memeToken = new MEMERC20(params.name, params.symbol);
        (address token0, address token1) = _getTokenOrder(address(memeToken));

        address pool = v3Factory.createPool(token0, token1, UNI_LP_SWAPFEE);

        memeceptions[address(memeToken)] = Memeception({
            auctionTokenSold: 0,
            startAt: params.startAt,
            pool: pool,
            creator: msg.sender,
            auctionFinalPrice: 0,
            swapFeeBps: params.swapFeeBps
        });

        memeSymbolExist[params.symbol] = true;

        if (params.vestingAllocBps > 0) {
            uint256 vestingAlloc = TOKEN_TOTAL_SUPPLY.mulDiv(params.vestingAllocBps, 1e4);
            memeToken.safeApprove(address(vesting), vestingAlloc);
            vesting.startVesting(
                address(memeToken), msg.sender, vestingAlloc, params.startAt, VESTING_DURATION, VESTING_CLIFF
            );
        }

        emit MemeCreated(
            address(memeToken), msg.sender, params.cap, params.startAt, params.swapFeeBps, params.vestingAllocBps
        );
        return (address(memeToken), pool);
    }

    /// @dev Verify the validity of the parameters for the creation of a memeception
    /// @param params List of parameters for the creation of a memeception
    /// Revert if any parameters are invalid
    function _verifyCreateMeme(MemeCreationParams calldata params) internal view {
        if (memeSymbolExist[params.symbol]) revert MemeSymbolExist();
        if (
            params.startAt < uint40(block.timestamp) + MEMECEPTION_MIN_START_AT
                || params.startAt > uint40(block.timestamp) + MEMECEPTION_MAX_START_AT
        ) revert InvalidMemeceptionDate();
        if (params.swapFeeBps > CREATOR_MAX_FEE_BPS) revert MemeSwapFeeTooHigh();
        if (params.vestingAllocBps > CREATOR_MAX_VESTED_ALLOC_BPS) revert VestingAllocTooHigh();
    }

    function bidMemeception(address memeToken) external payable {
        Memeception calldata memeception = memeceptions[memeToken];
        _verifyBid(memeception);

        int256 timeSinceStartPerTimeUnit =
            wadDiv(int256(block.timestamp - memeception.startAt), int256(AUCTION_TIME_UNIT));
        uint256 curPrice = getVRGDAPrice(timeSinceStartPerTimeUnit, memeception.auctionTokenSold);
        uint256 auctionTokenAmount = msg.value * curPrice;

        if (memeception.auctionTokenSold + auctionTokenAmount >= TOKEN_MEMECEPTION_SUPPLY) {
            auctionTokenAmount = TOKEN_MEMECEPTION_SUPPLY - memeception.auctionTokenSold;

            memeceptions[memeToken].auctionFinalPrice = curPrice.safeCastTo64();
            /// Adding liquidity to Uni V3 Pool
            _addLiquidityToUniV3Pool(
                memeToken,
                TOKEN_MEMECEPTION_SUPPLY.mulDiv(1e18, curPrice),
                MEMERC20(memeToken).balanceOf(address(this)) - TOKEN_MEMECEPTION_SUPPLY * 10 ** TOKEN_DECIMALS
            );
        }

        memeceptions[memeToken].auctionTokenSold += auctionTokenAmount.safeCastTo48();

        bidsOG[memeToken][msg.sender] =
            Bid({amountETH: msg.value.safeCastTo80(), amountMemeToken: auctionTokenAmount.safeCastTo48()});

        emit MemeceptionBid(memeToken, msg.sender, msg.value, auctionTokenAmount);
    }

    // /// @inheritdoc ITruglyLaunchpad
    // function depositMemeception(address memeToken) external payable {
    //     uint80 msgValueUint80 = msg.value.toUint80();
    //     Memeception storage memeception = memeceptions[memeToken];

    //     uint80 amount = memeception.balance + msgValueUint80 <= memeception.cap
    //         ? msgValueUint80
    //         : memeception.cap - memeception.balance;

    //     if (memeception.balance + amount == memeception.cap) {
    //         /// Cap is reached - Adding liquidity to Uni V3 Pool
    //         uint256 tokenPoolSupply = MEMERC20(memeToken).balanceOf(address(this)) - TOKEN_MEMECEPTION_SUPPLY;
    //         _addLiquidityToUniV3Pool(memeToken, memeception.cap, tokenPoolSupply);

    //         /// Refund as the Cap has been reached
    //         if (msgValueUint80 > amount) {
    //             (bool success,) = msg.sender.call{value: uint256(msgValueUint80 - amount)}("");
    //             if (!success) revert("Refund failed");
    //         }

    //         emit MemeLiquidityAdded(memeToken, memeception.cap, tokenPoolSupply);
    //     }

    //     memeception.balance += amount;
    //     bidsOG[memeToken][msg.sender] = uint256(amount);
    //     emit MemeceptionBid(memeToken, msg.sender, amount);
    // }

    /// @dev Add liquidity to the UniV3 Pool and initialize the pool
    /// @param memeToken Address of the MEMERC20
    /// @param amountETH Amount of ETH to add to the pool
    /// @param amountMemeToken Amount of MEMERC20 to add to the pool
    function _addLiquidityToUniV3Pool(address memeToken, uint256 amountETH, uint256 amountMemeToken) internal {
        (address token0, address token1) = _getTokenOrder(address(memeToken));
        uint256 amount0 = token0 == address(WETH9) ? amountETH : amountMemeToken;
        uint256 amount1 = token0 == address(WETH9) ? amountMemeToken : amountETH;

        uint160 sqrtPriceX96 = SqrtPriceX96.calcSqrtPriceX96(amount0, amount1);
        IUniswapV3Pool(memeceptions[memeToken].pool).initialize(sqrtPriceX96);

        WETH9.deposit{value: amountETH}();
        WETH9.safeApprove(address(v3PositionManager), amountETH);
        MEMERC20(memeToken).safeApprove(address(v3PositionManager), amountMemeToken);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: UNI_LP_SWAPFEE,
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            amount0Desired: amount0,
            amount1Desired: amount1,
            /// TODO: Provide a better value
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 30 minutes
        });

        v3PositionManager.mint(params);

        emit MemeLiquidityAdded(memeToken, amount0, amount1);
    }

    /// @dev Check a MEMERC20's UniV3 Pool is initialized with liquidity
    /// @param memeToken Address of the MEMERC20
    /// @return bool True if the pool is initialized with liquidity
    function _poolLaunched(Memeception calldata memeception) private view returns (bool) {
        return memeception.auctionFinalPrice > 0;
    }

    /// @dev Verify the validity of the deposit in a Memeception
    /// @param memeToken Address of the MEMERC20
    /// Revert if any parameters are invalid
    function _verifyBid(Memeception calldata memeception) internal view virtual {
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value > AUCTION_MAX_BID) revert BidAmountTooHigh();
        if (_poolLaunched(memeception)) revert MemeLaunched();
        if (block.timestamp < memeception.startAt || _auctionEnded(memeception)) revert InvalidMemeceptionDate();

        if (bidsOG[memeToken][msg.sender].amountETH > 0) revert DuplicateOG();
    }

    /// @inheritdoc ITruglyLaunchpad
    function exitMemeception(address memeToken) external {
        Memeception calldata memeception = memeceptions[memeToken];
        if (_poolLaunched(memeception)) revert MemeLaunched();
        if (!_auctionEnded(memeception)) revert InvalidMemeceptionDate();

        uint256 exitAmount = bidsOG[memeToken][msg.sender].amountETH;
        bidsOG[memeToken][msg.sender] = Bid({amountETH: 0, amountMemeToken: 0});
        msg.sender.safeTransferETH(exitAmount);

        emit MemeceptionExit(memeToken, msg.sender, exitAmount);
    }

    /// @inheritdoc ITruglyLaunchpad
    function claimMemeception(address memeToken) external {
        Memeception calldata memeception = memeceptions[memeToken];
        if (!_poolLaunched(memeception)) revert MemeNotLaunched();

        Bid memory bid = bidsOG[memeToken][msg.sender];
        if (bid.amountETH == 0 || bid.amountMemeToken == 0) revert ZeroAmount();

        uint256 refund = bid.amountETH - bid.amountMemeToken.mulDiv(1e18, memeception.auctionFinalPrice);

        MEMERC20 meme = MEMERC20(memeToken);

        bidsOG[memeToken][msg.sender] = Bid({amountETH: 0, amountMemeToken: 0});
        meme.safeTransfer(msg.sender, claimableMeme);
        if (refund > 0) msg.sender.safeTransferETH(refund);

        emit MemeClaimed(memeToken, msg.sender, claimableMeme, refund);
    }

    // function collectProtocolFees(Currency currency) external onlyOwner {
    //     uint256 amount = abi.decode(
    //         poolManager.lock(address(this), abi.encodeCall(this.lockCollectProtocolFees, (jug, currency))), (uint256)
    //     );

    //     emit CollectProtocolFees(Currency.unwrap(currency), jug, amount);
    // }

    // function collectLPFees(PoolKey[] calldata poolKeys) external onlyOwner {
    //     IPoolManager.ModifyLiquidityParams memory modifyLiqParams =
    //         IPoolManager.ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: 0});

    //     for (uint256 i = 0; i < poolKeys.length; i++) {
    //         PoolKey memory poolKey = poolKeys[i];
    //         BalanceDelta delta = abi.decode(
    //             poolManager.lock(
    //                 address(this), abi.encodeCall(this.lockModifyLiquidity, (poolKey, modifyLiqParams, jug))
    //             ),
    //             (BalanceDelta)
    //         );
    //         emit CollectLPFees(Currency.unwrap(poolKey.currency0), jug, uint256(int256(delta.amount0())));
    //         emit CollectLPFees(Currency.unwrap(poolKey.currency1), jug, uint256(int256(delta.amount1())));
    //     }
    // }

    // function lockCollectProtocolFees(address recipient, Currency currency) external returns (uint256 amount) {
    //     if (msg.sender != address(this)) revert OnlyOink();

    //     amount = poolManager.balanceOf(address(this), currency.toId());
    //     poolManager.burn(address(this), currency.toId(), amount);

    //     poolManager.take(currency, recipient, amount);
    // }

    function _auctionEnded(Memeception calldata memeception) internal returns (bool) {
        return block.timestamp >= memeception.startAt + AUCTION_DURATION || _poolLaunched(memeception);
    }

    /// @inheritdoc ITruglyLaunchpad
    function getMemeception(address memeToken) external view returns (Memeception memory) {
        return memeceptions[memeToken];
    }

    /// @inheritdoc ITruglyLaunchpad
    function getBalanceOG(address memeToken, address og) external view returns (uint256) {
        return bidsOG[memeToken][og];
    }

    /// @dev Get the order of the tokens in the UniV3 Pool by comparing their addresses
    /// @param memeToken Address of the MEMERC20
    /// @return token0 Address of the first token
    /// @return token1 Address of the second token
    function _getTokenOrder(address memeToken) internal view returns (address token0, address token1) {
        if (address(WETH9) < address(memeToken)) {
            token0 = address(WETH9);
            token1 = address(memeToken);
        } else {
            token0 = address(memeToken);
            token1 = address(WETH9);
        }
    }

    /// @notice receive native tokens
    receive() external payable {}

    /// @dev receive ERC721 tokens for Univ3 LP Positions
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
