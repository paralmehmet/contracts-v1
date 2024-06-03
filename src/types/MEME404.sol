/// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.23;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {ERC1155TokenReceiver} from "@solmate/tokens/ERC1155.sol";
import {ERC721TokenReceiver} from "@solmate/tokens/ERC721.sol";
import {ITruglyFactoryNFT} from "../interfaces/ITruglyFactoryNFT.sol";

import {MEME20} from "./MEME20.sol";
import {IMEME404} from "../interfaces/IMEME404.sol";
import {IMEME1155} from "../interfaces/IMEME1155.sol";
import {IMEME721} from "../interfaces/IMEME721.sol";
import {MEME20Constant} from "../libraries/MEME20Constant.sol";

/// @title Trugly's MEME404
/// @notice Contract automatically generated by https://www.trugly.meme
contract MEME404 is IMEME404, MEME20 {
    using FixedPointMathLib for uint256;
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       EVENTS                      */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       ERRORS                      */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/

    /// @dev No _tiers are provided
    error NoTiers();
    /// @dev Too many _tiers are provided
    error MaxTiers();
    /// @dev When a fungible sequence has upperId that is not equal to lowerId
    error FungibleThreshold();
    /// @dev When a prev tier has a higher amount threshold than the current tier
    error AmountThreshold();
    /// @dev When a non-fungible sequence has incorrect upperId and lowerId
    error NonFungibleIds();
    /// @dev tokenId is 0
    error INvalidTierParamsZeroId();
    /// @dev Only NFT collection can call this function
    error OnlyNFT();
    /// @dev When the contract is already initialized
    error TiersAlreadyInitialized();
    /// @dev When there's not enough NFTS based on amount threshold
    error NotEnoughNFTs();
    /// @dev When a NFT sequence is followed by a fungible one
    error FungibleAfterNonFungible();
    /// @dev When a NFT sequence has nftId that is less than the previous one or is the same but isFungible is different
    error IncorrectOrder();

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       STORAGE                     */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /// @dev A uint32 map in storage.
    struct Uint32Map {
        uint256 spacer;
    }

    struct Tier {
        string baseURL;
        uint256 lowerId;
        uint256 upperId;
        uint256 amountThreshold;
        bool isFungible;
        address nft;
        uint256 nextUnmintedId;
        Uint32Map burnIds;
        uint256 burnLength;
        uint256 tierId;
    }

    /// @dev NFT ID to NFT address mapping
    mapping(uint256 => address) public nftIdToAddress;

    /// @dev Tier ID to Tier mapping
    mapping(uint256 => Tier) internal _tiers;

    mapping(address => bool) internal _exemptNFTMint;

    uint256 internal _tierCount;

    bool internal _initialized;

    address internal factory;

    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    /*                       IMPLEMENTATION              */
    /* ¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯¯\_(ツ)_/¯*/
    constructor(string memory _name, string memory _symbol, address _memeception, address _creator, address _factoryNFT)
        MEME20(_name, _symbol, _memeception, _creator)
    {
        factory = _factoryNFT;
    }

    /// @dev Initialize the _tiers
    /// @dev Is called automatically by the Memeception contract
    function initializeTiers(IMEME404.TierCreateParam[] memory _tierParams, address[] memory _exempt) external {
        if (_initialized) revert TiersAlreadyInitialized();
        _initialized = true;

        if (_tierParams.length == 0) revert NoTiers();
        if (_tierParams.length > 9) revert MaxTiers();

        for (uint256 i = 0; i < _tierParams.length; i++) {
            if (_tierParams[i].lowerId == 0) revert INvalidTierParamsZeroId();
            if (_tierParams[i].amountThreshold == 0 || _tierParams[i].amountThreshold > totalSupply) {
                revert AmountThreshold();
            }
            if (_tierParams[i].isFungible) {
                if (_tierParams[i].lowerId != _tierParams[i].upperId) revert FungibleThreshold();
            } else {
                if (_tierParams[i].lowerId >= _tierParams[i].upperId) revert NonFungibleIds();

                uint256 maxNFT = totalSupply.rawDiv(_tierParams[i].amountThreshold);
                if ((_tierParams[i].upperId - _tierParams[i].lowerId + 1) < maxNFT) {
                    revert NotEnoughNFTs();
                }
            }

            address existingNFTAddr = nftIdToAddress[_tierParams[i].nftId];
            Tier memory tier = Tier({
                baseURL: _tierParams[i].baseURL,
                lowerId: _tierParams[i].lowerId,
                upperId: _tierParams[i].upperId,
                amountThreshold: _tierParams[i].amountThreshold,
                isFungible: _tierParams[i].isFungible,
                nft: address(0),
                nextUnmintedId: _tierParams[i].isFungible ? 0 : _tierParams[i].lowerId,
                burnIds: Uint32Map(0),
                burnLength: 0,
                tierId: i + 1
            });
            if (i > 0) {
                Tier memory previousTier = _tiers[i];
                if (_tierParams[i - 1].nftId > _tierParams[i].nftId) revert IncorrectOrder();
                if (
                    _tierParams[i - 1].nftId == _tierParams[i].nftId
                        && _tierParams[i - 1].isFungible != _tierParams[i].isFungible
                ) revert IncorrectOrder();
                if (previousTier.amountThreshold >= tier.amountThreshold) revert AmountThreshold();
                if (!previousTier.isFungible && tier.isFungible) revert FungibleAfterNonFungible();
                if (existingNFTAddr != address(0) && previousTier.upperId >= tier.lowerId) {
                    revert NonFungibleIds();
                }
            }
            tier.nft = existingNFTAddr != address(0) ? existingNFTAddr : _createNewNFT(creator, _tierParams[i]);
            _tiers[i + 1] = tier;
        }

        for (uint256 i = 0; i < _exempt.length; i++) {
            _exemptNFTMint[_exempt[i]] = true;
        }

        _tierCount = _tierParams.length;
    }

    /// @dev Transfer of memecoins
    /// @dev If balance of sender or recipient changes tier, mint or burn NFTs accordingly
    function transfer(address to, uint256 amount) public override returns (bool) {
        _TierEligibility memory beforeTierFrom = _getTierEligibility(msg.sender);
        _TierEligibility memory beforeTierTo = _getTierEligibility(to);

        bool success = super.transfer(to, amount);

        _TierEligibility memory afterTierFrom = _getTierEligibility(msg.sender);
        _TierEligibility memory afterTierTo = _getTierEligibility(to);

        // handle burn
        _burnTier(msg.sender, beforeTierFrom, afterTierFrom, 0);
        _burnTier(to, beforeTierTo, afterTierTo, 0);
        // handle mint
        _mintTier(msg.sender, afterTierFrom);
        _mintTier(to, afterTierTo);

        return success;
    }

    /// @dev Transfer of memecoins
    /// @dev If balance of sender or recipient changes tier, mint or burn NFTs accordingly
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _TierEligibility memory beforeTierFrom = _getTierEligibility(from);
        _TierEligibility memory beforeTierTo = _getTierEligibility(to);

        bool success = super.transferFrom(from, to, amount);

        _TierEligibility memory afterTierFrom = _getTierEligibility(from);
        _TierEligibility memory afterTierTo = _getTierEligibility(to);

        _burnTier(from, beforeTierFrom, afterTierFrom, 0);
        _burnTier(to, beforeTierTo, afterTierTo, 0);
        _mintTier(from, afterTierFrom);
        _mintTier(to, afterTierTo);

        return success;
    }

    /// @dev Create a new NFT collection
    /// @notice ERC1155 if fungible, ERC721 if non-fungible
    function _createNewNFT(address _creator, IMEME404.TierCreateParam memory _tier)
        internal
        virtual
        returns (address)
    {
        if (_tier.isFungible) {
            address nft = ITruglyFactoryNFT(factory).createMeme1155(
                _tier.nftName, _tier.nftSymbol, address(this), _creator, _tier.baseURL
            );
            nftIdToAddress[_tier.nftId] = nft;
        } else {
            address nft = ITruglyFactoryNFT(factory).createMeme721(
                _tier.nftName, _tier.nftSymbol, address(this), _creator, _tier.baseURL
            );
            nftIdToAddress[_tier.nftId] = nft;
        }

        return nftIdToAddress[_tier.nftId];
    }

    /// @notice Can only be called by NFT collection
    /// @dev Raw transfer of memecoins
    /// @dev This function bypasses the NFT mint/burn, approval and any fees
    function transferFromNFT(address from, address to, uint256 nftTokenId) public returns (bool) {
        Tier memory tier = _getTierFromNftTokenId(msg.sender, nftTokenId);
        if (tier.nft == address(0)) revert OnlyNFT();

        _TierEligibility memory beforeTierTo = _getTierEligibility(to);

        balanceOf[from] -= tier.amountThreshold;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += tier.amountThreshold;
        }

        _TierEligibility memory afterTierFrom = _getTierEligibility(from);
        _TierEligibility memory afterTierTo = _getTierEligibility(to);

        /// @dev NFT has already been transferred
        /// Need to check if the user has decreased in tier and mint the NFTs
        _mintTier(from, afterTierFrom);

        if (afterTierTo.tierId > 0 && tier.tierId != uint256(afterTierTo.tierId)) {
            if (tier.isFungible) {
                IMEME1155(tier.nft).burn(to, nftTokenId, 1);
            } else {
                IMEME721(tier.nft).burn(nftTokenId);
                Tier storage _tierStorage = _tiers[tier.tierId];
                _set(_tierStorage.burnIds, ++_tierStorage.burnLength, uint32(nftTokenId));
            }
        }

        if (afterTierTo.tierId != beforeTierTo.tierId) {
            if (tier.nft == afterTierTo.nft) {
                _burnTier(to, beforeTierTo, afterTierTo, 1);
            } else {
                _burnTier(to, beforeTierTo, afterTierTo, 0);
            }
            _mintTier(to, afterTierTo);
        }

        emit Transfer(from, to, tier.amountThreshold);

        return true;
    }

    /// @dev Mint NFTs once a user reaches a new tier
    /// @param _owner Address of the user
    /// @param _afterTierEligibility Current Tier + NFT balance
    function _mintTier(address _owner, _TierEligibility memory _afterTierEligibility) internal {
        if (_afterTierEligibility.tierId < 0 || _owner == address(0) || _exemptNFTMint[_owner]) return;

        Tier storage tier = _tiers[uint256(_afterTierEligibility.tierId)];
        if (tier.isFungible) {
            if ((_owner.code.length != 0) && !_checkERC1155Received(_owner, msg.sender, address(0), tier.lowerId, 1)) {
                return;
            }
            IMEME1155 nft = IMEME1155(tier.nft);
            if (nft.balanceOf(_owner, tier.lowerId) >= 1) return;
            nft.mint(_owner, tier.lowerId, 1, "");
        } else {
            if ((_owner.code.length != 0) && !_checkERC721Received(_owner, msg.sender, address(0), tier.lowerId, "")) {
                return;
            }

            IMEME721 nft = IMEME721(tier.nft);

            uint256 numToMint = _afterTierEligibility.expectedNFTBal > nft.balanceOf(_owner)
                ? _afterTierEligibility.expectedNFTBal - nft.balanceOf(_owner)
                : 0;

            for (uint256 i = 0; i < numToMint; i++) {
                uint256 nftIdToMint;
                if (tier.nextUnmintedId <= tier.upperId) {
                    nftIdToMint = tier.nextUnmintedId++;
                } else {
                    /// @dev this should never happen but in case it does
                    /// @dev we wouldn't want to mint any NFT and let the coins be transferred
                    if (tier.burnLength == 0) return;

                    nftIdToMint = _get(tier.burnIds, tier.burnLength--);
                }

                nft.mint(_owner, nftIdToMint);
            }
        }
    }

    /// @dev Burn NFTs once a user reaches a new tier (either going up or down)
    /// @param _owner Address of the user
    /// @param _beforeTierEligibility Before Transfer: Tier + NFT balance
    /// @param _afterTierEligibility Current Tier + NFT balance
    function _burnTier(
        address _owner,
        _TierEligibility memory _beforeTierEligibility,
        _TierEligibility memory _afterTierEligibility,
        uint256 _incrementFromNFTTransfer
    ) internal {
        if (_beforeTierEligibility.tierId < 0 || _owner == address(0)) return;

        Tier storage tier = _tiers[uint256(_beforeTierEligibility.tierId)];
        if (tier.isFungible) {
            IMEME1155 nft = IMEME1155(tier.nft);
            if (
                (nft.balanceOf(_owner, tier.lowerId) == 0)
                    || _beforeTierEligibility.tierId == _afterTierEligibility.tierId
            ) return;
            nft.burn(_owner, tier.lowerId, nft.balanceOf(_owner, tier.lowerId));
        } else {
            IMEME721 nft = IMEME721(tier.nft);

            uint256 numToBurn = _beforeTierEligibility.tierId != _afterTierEligibility.tierId
                ? _beforeTierEligibility.currentNFTBal > _incrementFromNFTTransfer
                    ? _beforeTierEligibility.currentNFTBal - _incrementFromNFTTransfer
                    : 0
                : _afterTierEligibility.currentNFTBal > _afterTierEligibility.expectedNFTBal
                    ? _afterTierEligibility.currentNFTBal - _afterTierEligibility.expectedNFTBal
                    : 0;

            for (uint256 i = 0; i < numToBurn; i++) {
                uint256 nftIdToburn = nft.nextOwnedTokenId(_owner);
                nft.burn(nftIdToburn);
                _set(tier.burnIds, ++tier.burnLength, uint32(nftIdToburn));
            }
        }
    }

    /// @dev Get the tier eligibility of a user based on their memecoin balance
    /// @param _owner Address of the user
    /// @return _TierEligibility
    function _getTierEligibility(address _owner) internal view returns (_TierEligibility memory) {
        if (_owner != address(0)) {
            uint256 balance = balanceOf[_owner];
            for (uint256 i = _tierCount; i > 0; i--) {
                if (balance >= _tiers[i].amountThreshold) {
                    return _TierEligibility({
                        tierId: int256(_tiers[i].tierId),
                        expectedNFTBal: balance.rawDiv(_tiers[i].amountThreshold),
                        nft: _tiers[i].nft,
                        currentNFTBal: _tiers[i].isFungible
                            ? IMEME1155(_tiers[i].nft).balanceOf(_owner, _tiers[i].lowerId)
                            : IMEME721(_tiers[i].nft).balanceOf(_owner)
                    });
                }
            }
        }
        return _TierEligibility({tierId: -1, expectedNFTBal: 0, nft: address(0), currentNFTBal: 0});
    }

    /// @dev Get the tier by ID
    /// @param tierId Tier ID
    /// @return Tier
    function getTier(uint256 tierId) public view returns (Tier memory) {
        return _tiers[tierId];
    }

    /// @dev Get the tier by NFT token ID
    /// @param nft NFT address
    /// @param tokenId NFT token ID
    /// @return Tier
    function _getTierFromNftTokenId(address nft, uint256 tokenId) internal view returns (Tier memory) {
        for (uint256 i = 1; i <= _tierCount; i++) {
            Tier memory tier = _tiers[i];
            if (tier.nft != nft) continue;

            if (tier.isFungible) {
                if (tier.lowerId == tokenId) {
                    return tier;
                }
            } else {
                if (tokenId >= tier.lowerId && tokenId <= tier.upperId) {
                    return tier;
                }
            }
        }
        return Tier({
            baseURL: "",
            lowerId: 0,
            upperId: 0,
            amountThreshold: 0,
            isFungible: false,
            nft: address(0),
            nextUnmintedId: 0,
            burnIds: Uint32Map(0),
            burnLength: 0,
            tierId: 0
        });
    }

    function _checkERC1155Received(address _contract, address _operator, address _from, uint256 _id, uint256 _value)
        internal
        returns (bool)
    {
        bytes memory callData = abi.encodeWithSelector(
            ERC1155TokenReceiver(_contract).onERC1155Received.selector, _operator, _from, _id, _value, ""
        );

        (bool success, bytes memory returnData) = _contract.call(callData);

        // Check both call success and return value
        if (success && returnData.length >= 32) {
            // Make sure there is enough data to cover a `bytes4` return
            bytes4 returned = abi.decode(returnData, (bytes4));
            return returned == ERC1155TokenReceiver.onERC1155Received.selector;
        }

        return false;
    }

    function _checkERC721Received(address _contract, address _operator, address _from, uint256 _id, bytes memory _data)
        internal
        returns (bool)
    {
        bytes memory callData = abi.encodeWithSelector(
            ERC721TokenReceiver(_contract).onERC721Received.selector, _operator, _from, _id, _data
        );

        (bool success, bytes memory returnData) = _contract.call(callData);

        // Check both call success and return value
        if (success && returnData.length >= 32) {
            // Make sure there is enough data to cover a `bytes4` return
            bytes4 returned = abi.decode(returnData, (bytes4));
            return returned == ERC721TokenReceiver.onERC721Received.selector;
        }

        return false;
    }

    /// @dev Returns the uint32 value at `index` in `map`.
    function _get(Uint32Map storage map, uint256 index) internal view returns (uint32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := add(shl(96, map.slot), shr(3, index)) // Storage slot.
            result := and(0xffffffff, shr(shl(5, and(index, 7)), sload(s)))
        }
    }

    /// @dev Updates the uint32 value at `index` in `map`.
    function _set(Uint32Map storage map, uint256 index, uint32 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let s := add(shl(96, map.slot), shr(3, index)) // Storage slot.
            let o := shl(5, and(index, 7)) // Storage slot offset (bits).
            let v := sload(s) // Storage slot value.
            sstore(s, xor(v, shl(o, and(0xffffffff, xor(value, shr(o, v))))))
        }
    }

    struct _TierEligibility {
        int256 tierId;
        uint256 expectedNFTBal;
        address nft;
        uint256 currentNFTBal;
    }
}
