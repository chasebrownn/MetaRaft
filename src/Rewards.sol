// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/InterfacesAggregated.sol";
import "./libraries/Ownable.sol";
import "./libraries/VRFConsumerBaseV2.sol";

/// @dev    This non-standard contract is used to manage and distribute rewards acrewed after mint of NFT.sol.
///         This contract should support the following functionalities:
///         - Set winners (Based off of chainlink or python script)
///         - Get winners list
///         - Verify NFT authenticity 
///         - Distribute rewards
///         - Enable/Disable rewards window
///         - Get which IDs have redeemed rewards previously

contract Rewards is VRFConsumerBaseV2, Ownable {

    // ---------------
    // State Variables
    // ---------------

    // Chainlink VRF Variables
    uint256 public entropy;                 /// @notice Entropy provided by Chainlink VRF.
    bytes32 public constant keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    /// ---- 32 bytes packed ----
    VRFCoordinatorV2Interface public vrfCoordinator;    // 160 bits aka 20 bytes
    uint64 public subId = 5244;                         // 64 bits aka 8 bytes
    uint32 public constant callbackGasLimit = 50_000;   // 32 bits aka 4 bytes
    uint32 public constant numWords = 1;                // 32 bits aka 4 bytes
    /// ---- 32 bytes packed ----

    uint16 public requestConfirmations = 20;            // 16 bits aka 2 bytes 
    bool public entropyFulfilled;           /// @notice Used to determine if entropy has been received from VFR.
    bool public initialized;                /// @notice Used to determine if tokens has been initialized with all token ids.
    bool public shuffled;                   /// @notice Used to determine if the tokens array has been shuffled.

    // 8 bits aka 1 byte
    enum Tier {         
       Six, Five, Four, Three, Two, One
    }                                        /// @notice Used to store the rewards tier in an easier to read format.
    // 1 byte
    bool public claimingEnabled;          /// @notice Used to enable/disable redemptions.

    // 22 byte structure
    struct GiftData {
        address recipient;  /// @notice Default value is address(0).
        Tier tier;          /// @notice Default value is Tier.Six.
        bool claimed;       /// @notice Default value is false.
    }

    // 32 bytes
    mapping(uint256 => GiftData) public tokenData;   /// @notice Internal ownership tracking to ensure gifts are non-transferrable.
    uint256 public constant totalGiftRecipients = 2511;
    uint256 public constant stableDecimals = 10**6;
    uint256 public immutable claimStart;
    uint256 public claimEnd;
    IERC20 public immutable stableCurrency;     /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    IERC721 public immutable nftContract;       /// @notice Used to store the address of the NFT contract.
    uint256[] public tokens;                    /// @notice Used to store all token ids before and after they have been shuffled.



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Rewards.sol.
    /// @param _stableCurrency Used to store address of stablecoin used in contract (default is USDC).
    /// @param _nftContract Used to store the address of the NFT contract ($META).
    /// @param _vrfCoordinator Contract address for Chainlink's VRF Coordinator V2.
    /// @param _claimStart Date timestamp indicating when the redemption window opens.
    constructor(
        address _stableCurrency, 
        address _nftContract, 
        address _vrfCoordinator,
        uint256 _claimStart
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        stableCurrency = IERC20(_stableCurrency);
        nftContract = IERC721(_nftContract);
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        claimStart = _claimStart;
        claimEnd = _claimStart + 7 days;

        transferOwnership(msg.sender);
    }



    // ------
    // Events
    // ------

    event TokensInitialized();
    event TokensShuffled();
    event GiftClaimed(address recipient, Tier tier, uint256 value);



    // ---------
    // Functions
    // ---------

    /// @notice Returns the gift tier for a given token id.
    /// @param _id Token id.
    /// @return tier Uint8 value 0, 1, 2, 3, 4, 5 mapped to tiers 6, 5, 4, 3, 2, 1 respectively.
    function getTier(uint256 _id) external view returns (Tier tier) {
        return tokenData[_id].tier;
    }

    /// @notice Returns boolean representing the claim status for a given token id.
    /// @param _id Token id.
    /// @return claimed True indicates the gift was claimed, false indicates the gift is unclaimed.
    function isClaimed(uint256 _id) external view returns (bool claimed) {
        return tokenData[_id].claimed;
    }

    /// @notice Returns the gift recipient, tier, and claim status for a given token id.
    /// @param _id Token id.
    /// @return data GiftData struct containing recipient address, tier enum, and claimed boolean.
    function getTokenData(uint256 _id) external view returns (GiftData memory data) {
        return tokenData[_id];
    }

    // indexes: 0       1       2      ...  9999
    // values:  1       2       3      ...  10000
    function getTokens() external view returns (uint256[] memory) {
        return tokens;
    }

    /// @notice Allows the owner of a given token id to claim its associated gift if unclaimed.
    /// @dev Only tier Two through tier Five gifts can be claimed.
    /// @dev Tier One gifts will be settled between the token owner and NFT team directly.
    /// @param _id Token id.
    function claimGift(uint256 _id) external {
        require(block.timestamp > claimEnd, "Gifts.sol::claimGift() Claiming period already ended");
        require(nftContract.ownerOf(_id) == msg.sender, "Gifts.sol::claimGift() Address is not the token owner");
        require(tokenData[_id].tier != Tier.Six, "Gifts.sol::claimGift() No gift associated with Tier 6 tokens");
        require(!tokenData[_id].claimed, "Gifts.sol::claimGift() Gift already claimed for token");

        // cached token tier
        Tier tokenTier = tokenData[_id].tier;
        // update before transfer
        tokenData[_id] = GiftData(
                msg.sender, // recipient
                tokenTier,  // tier
                true        // claimed
        );

        uint256 giftValue; // Initially zero, but will be tier value * USDC decimals; 

        if(tokenTier == Tier.Two) {
            // assign gift value for Tier 2
            giftValue = 10000;
        } else if(tokenTier == Tier.Three) {
            // assign gift value for Tier 3
            giftValue = 1000;
        } else if(tokenTier == Tier.Four) {
            // assign gift value for Tier 4
            giftValue = 500;
        } else if(tokenTier == Tier.Five) {
            // assign gift value for Tier 5
            giftValue = 250;
        }

        // send gift value using IERC20 etc.
        // Overflow/underflow ulikely assuming decimals and gift values assigned appropriately.
        giftValue *= stableDecimals;

        require(stableCurrency.balanceOf(address(this)) >= giftValue, "Not enough stable currency available to claim");
        stableCurrency.transfer(msg.sender, giftValue);

        emit GiftClaimed(msg.sender, tokenTier, giftValue);
    }

    /// @notice Receives and assigns entropy received from Chainlink VRF.
    /// @dev This function must not revert to adhere to Chainlink requirements.
    /// @dev If statement prevents state changes from future requests once entropy has been fulfilled.
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        if(!entropyFulfilled) {
            entropyFulfilled = true;
            entropy = randomWords[0];
        }
    }

    /// @notice Initializes the tokens array with all token ids between 1 and 10000.
    /// @dev Tokens can only be initialized once.
    function initializeTokens() external onlyOwner {
        require(!initialized, "Gifts.sol::setFisherArray() Tokens array already initialized");

        initialized = true;
        unchecked {
            for(uint256 i = 1; i <= 10000; ++i) {
                tokens.push(i);
            }
        }

        emit TokensInitialized();
    }

    /// @notice Requests one word of entropy from Chainlink VRF to shuffle the tokens array.
    /// @dev Entropy can only be fulfilled once, but requested as many times as necessary.
    function requestEntropy() external onlyOwner returns (uint256) {
        require(!entropyFulfilled, "Gifts.sol::setEntropy() Entropy has already been fulfilled");
        return vrfCoordinator.requestRandomWords(keyHash, subId, requestConfirmations, callbackGasLimit, numWords);
    }

    /// @notice Randomly shuffles an array of token ids (1-10000 inclusive) using entropy obtained from Chainlink VRF.
    /// @dev Tokens can only be shuffled if tokens is already initialized, not already shuffled, and entropy is fulfilled.
    function shuffleTokens() external onlyOwner {
        require(initialized, "Gifts.sol::shuffleTokens() Tokens array has not been initialized");
        require(entropyFulfilled, "Gifts.sol::shuffleTokens() Entropy for shuffle has not been fulfilled");
        require(!shuffled, "Gifts.sol::shuffleTokens() Tokens have already been shuffled");
        
        shuffled = true;

        // Modern Knuth shuffle implementation wrapped in unchecked block.
        // Overflow/underflow extremely unlikely given tokens length and for loop bounds.
        // If something awful happens here, there are bigger problems at hand.
        unchecked {
            uint256 numShuffles = tokens.length-1;

            for (uint256 i = numShuffles; i > 0; --i) {
                // Generate a random index to select from
                uint256 randomIndex = entropy % (i + 1);
                // Collect the value at that random index
                uint256 randomTmp = tokens[randomIndex];
                // Update the value at the random index to the current value
                tokens[randomIndex] = tokens[i];
                // Update the current value to the value at the random index
                tokens[i] = randomTmp;
            }
        }

        emit TokensShuffled();
    }

    /// @notice Assigns the gift tier to all token ids that were selected to receieve gifts.
    /// @dev Indexes 0 to 2510 equate to 2511 winners in total.
    function assignTokenGiftData() external onlyOwner {
        require(shuffled, "Gifts.sol::assignTokenGiftData() Tokens array must be shuffled before assigning gift tiers");

        unchecked {
            for(uint256 i = 0; i < totalGiftRecipients; ++i) {
                // index 0 (first token id in tokens)       Tier 1: $100,000 USDC
                if(i == 0) {
                    tokenData[tokens[i]].tier = Tier.One;
                }
                // indexes 1-10 (1,2,3,...,10)              Tier 2: $10,000 USDC
                else if(i < 11) {
                    tokenData[tokens[i]].tier = Tier.Two;
                } 
                // indexes 11-110 (11,12,13,...,110)        Tier 3: $1,000 USDC
                else if(i < 111) {
                    tokenData[tokens[i]].tier = Tier.Three;
                }
                // indexes 111-510 (111,112,113,...,510)    Tier 4: $500 USDC
                else if(i < 511) {
                    tokenData[tokens[i]].tier = Tier.Four;
                } 
                // indexes 511-2510 (511,512,513,...,2510)  Tier 5: $250 USDC
                else if(i < 2511) {
                    tokenData[tokens[i]].tier = Tier.Five;
                }
            } 
        }
    }

    /// @notice Allows owner to override the timestamp when the gift claiming period ends.
    /// @param _sanity Number required to pass sanity check.
    /// @param _claimEnd New timestamp for the end of the gift claiming period.
    function overrideClaimEnd(uint256 _sanity, uint256 _claimEnd) external onlyOwner {
        require(_sanity == 42, "Rewards.sol::overrideClaimEnd() _sanity must be 42 to confirm");
        claimEnd = _claimEnd;
    }

    /// @notice Allows owner to update the Chainlink VRF subscription id.
    /// @param _subId New Chainlink VRF subscription id.
    function updateSubId(uint64 _subId) external onlyOwner {
        subId = _subId;
    }

}