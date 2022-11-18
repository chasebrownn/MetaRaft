// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC20.sol";
import "./libraries/Ownable.sol";
import "./libraries/VRFConsumerBaseV2.sol";

contract Gifts is VRFConsumerBaseV2, Ownable {

    // ---------------
    // State Variables
    // ---------------

    // ---- CHAINLINK AND SHUFFLE STATE ----

    /// @notice Entropy provided by Chainlink VRF.
    uint256 public entropy;
    /// @notice KeyHash required by Chainlink VRF.
    bytes32 public constant KEY_HASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // 32 bytes packed {
    /// @notice VRFCoodinatorV2 reference to make Chainlink VRF requests.
    VRFCoordinatorV2Interface public immutable vrfCoordinatorV2;
    /// @notice Chainlink VRF subscription id.
    uint64 public subId = 5244;
    /// @notice Callback gas limit for VRF request, ideal for one word of entropy.
    uint32 public constant CALLBACK_GAS_LIMIT = 50_000;
    /// @notice Number of random 256 bit words to be requested from VRF.
    uint32 public constant NUM_WORDS = 1;
    // }

    // 28 bytes packed {
    /// @notice Number of block confirmations before Chainlink VRF fulfills request.
    uint16 public constant REQUEST_CONFIRMATIONS = 20;
    /// @notice Used to determine if entropy has been received from VRF.
    bool public fulfilled;
    /// @notice Used to determine if tokens has been initialized with all token ids.
    bool public initialized;
    /// @notice Used to determine if the tokens array has been shuffled.
    bool public shuffled;

    // ---- GIFT DATA AND CLAIM STATE ----

    /// @notice Used to store the gift tier in a readable format.
    enum Tier {         
       Six, One, Two, Three, Four, Five
    }

    /// @notice Struct holding gift data for each token id.
    struct GiftData {
        // Gift recipient address, default value is address(0)
        address recipient;
        // Gift tier, default value is Tier.Six or uint8(0)
        Tier tier;
        // Whether the gift has been claimed or not, default value is false
        bool claimed;
    }
    // }

    /// @notice Internal ownership tracking to ensure gifts are non-transferrable.
    /// @dev Returns the gift recipient, tier, and claim status for a given token id.
    mapping(uint256 => GiftData) public tokenData;
    /// @notice Number of gift recipients and gifts available.
    uint256 public constant TOTAL_RECIPIENTS = 2511;
    /// @notice Used to track the start of the claiming period.
    uint256 public immutable claimStart;
    /// @notice Used to track the end of the claiming period.
    uint256 public claimEnd;

    // ---- CONTRACT AND TOKENS STATE ----

    /// @notice Decimals for USDC ERC20 implementation for proper gift values.
    uint256 public constant STABLE_DECIMALS = 10**6;
    /// @notice Address of stablecoin used as the gift currency.
    IERC20 public immutable stableCurrency;
    /// @notice Address of multi-signature wallet for ERC20 deposits.
    address payable public multiSig;
    /// @notice Address of Circle account for depositing leftover stablecoin.
    address payable public circleAccount;
    /// @notice Used to store the address of the NFT contract.
    IERC721 public immutable nftContract;
    /// @notice Used to store all token ids before and after shuffling.
    uint256[] public tokens;


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Gifts.sol.
    /// @param _claimStart Timestamp indicating when the redemption window opens.
    /// @param _nftContract Contract address of the NFT contract.
    /// @param _vrfCoordinator Contract address for Chainlink's VRF Coordinator V2.
    /// @param _stableCurrency Contract address of the stablecoin used for gifts (default is USDC).
    /// @param _circleAccount Address of Circle account.
    constructor(
        uint256 _claimStart,
        address _nftContract, 
        address _vrfCoordinator,
        address _stableCurrency, 
        address _circleAccount
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        claimStart = _claimStart;
        claimEnd = _claimStart + 7 days;
        nftContract = IERC721(_nftContract);
        vrfCoordinatorV2 = VRFCoordinatorV2Interface(_vrfCoordinator);
        stableCurrency = IERC20(_stableCurrency);
        circleAccount = payable(_circleAccount);
    }


    // ------
    // Events
    // ------

    event TokensInitialized();
    event TokensShuffled();
    event GiftDataSet();
    event GiftClaimed(
        address indexed recipient, 
        uint256 indexed id, 
        Tier tier, 
        uint256 gift
    );
    event ArrayValue(uint256 indexed val, uint256 indexed idx);

    // ------------------
    // External Functions
    // ------------------

    /// @notice Returns the gift tier for a given token id.
    /// @param _tokenId Token id.
    /// @return tier Uint8 value 0, 1, 2, 3, 4, 5 mapped to tiers 6, 5, 4, 3, 2, 1 respectively.
    function getTier(uint256 _tokenId) external view returns (Tier tier) {
        return tokenData[_tokenId].tier;
    }

    /// @notice Returns a boolean representing the claim status for a given token id.
    /// @param _tokenId Token id.
    /// @return claimed True indicates the gift was claimed, false indicates the gift is unclaimed.
    function isClaimed(uint256 _tokenId) external view returns (bool claimed) {
        return tokenData[_tokenId].claimed;
    }

    /// @notice Getter function that returns the entire tokens array.
    function getTokens() external view returns (uint256[] memory) {
        return tokens;
    }

    /// @notice Allows the owner of a given token id to claim its associated gift if unclaimed.
    /// @dev Only Tier Two through Tier Five gifts have gifts to be claim.
    /// @dev Tier One gifts will be settled between the token owner and NFT team directly.
    /// @param _tokenId Token id.
    /// @return claimed True indicates the claim was successful, false indicates the claim was unsuccessful.
    function claimGift(uint256 _tokenId) external returns (bool claimed) {
        require(block.timestamp > claimStart, "Gifts.sol::claimGift() Claiming period has not started");
        require(block.timestamp < claimEnd, "Gifts.sol::claimGift() Claiming period has already ended");
        require(tokenData[_tokenId].tier > Tier.One, "Gifts.sol::claimGift() No gift available for the token");
        require(!tokenData[_tokenId].claimed, "Gifts.sol::claimGift() Gift already claimed for the token");
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Gifts.sol::claimGift() Address is not the token owner");

        // Cached token tier
        Tier tokenTier = tokenData[_tokenId].tier;
        // Update before transfer
        tokenData[_tokenId].recipient = msg.sender;
        tokenData[_tokenId].claimed = true;

        // Will be updated to tier value * USDC decimals below
        uint256 gift = 0;

        if(tokenTier == Tier.Two) {
            // Assign gift value for Tier 2
            gift = 10000;
        } else if(tokenTier == Tier.Three) {
            // Assign gift value for Tier 3
            gift = 1000;
        } else if(tokenTier == Tier.Four) {
            // Assign gift value for Tier 4
            gift = 500;
        } else if(tokenTier == Tier.Five) {
            // Assign gift value for Tier 5
            gift = 250;
        }

        // Overflow/underflow unlikely assuming decimals and gift value assigned appropriately.
        gift = gift * STABLE_DECIMALS;

        // Send gift value using IERC20 etc.
        require(stableCurrency.balanceOf(address(this)) >= gift, "Gifts.sol::claimGift() Insufficient stable currency balance for claim");
        bool success = stableCurrency.transfer(msg.sender, gift);
        require(success, "Gifts.sol::claimGift() Transfer failed on stable currency");

        emit GiftClaimed(
            msg.sender, 
            _tokenId, 
            tokenTier, 
            gift
        );

        return true;
    }

    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Receives and assigns entropy received from Chainlink VRF.
    /// @dev This function must not revert to adhere to Chainlink requirements.
    /// @dev If statement prevents state changes from future requests once entropy has been fulfilled.
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        if(!fulfilled) {
            fulfilled = true;
            entropy = randomWords[0];
        }
    }

    /// @notice Requests one word of entropy from Chainlink VRF to shuffle the tokens array.
    /// @dev Entropy can only be fulfilled once, but requested as many times as necessary.
    function requestEntropy() external onlyOwner returns (uint256) {
        require(!fulfilled, "Gifts.sol::requestEntropy() Entropy has already been fulfilled");
        return vrfCoordinatorV2.requestRandomWords(KEY_HASH, subId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS);
    }

    /// @notice Initializes the tokens array with all token ids between 1 and 10000.
    /// @dev Tokens can only be initialized once.
    /// @dev Projected average gas cost of ~223876242 gwei.
    function initializeTokens() external onlyOwner {
        require(!initialized, "Gifts.sol::initializeTokens() Tokens array already initialized");

        initialized = true;
        unchecked {
            for(uint256 i = 1; i <= 10000; ++i) {
                tokens.push(i);
            }
        }
        emit TokensInitialized();
    }

    /// @notice Randomly shuffles an array of token ids (1-10000 inclusive) using entropy obtained from Chainlink VRF.
    /// @dev Tokens can only be shuffled if tokens is already initialized, not already shuffled, and entropy is fulfilled.
    /// @dev Projected average gas cost of ~13430437 gwei.
    function shuffleTokens() external onlyOwner {
        require(initialized, "Gifts.sol::shuffleTokens() Tokens array has not been initialized");
        require(fulfilled, "Gifts.sol::shuffleTokens() Entropy for shuffle has not been fulfilled");
        require(!shuffled, "Gifts.sol::shuffleTokens() Tokens have already been shuffled");

        shuffled = true;

        // Modern Knuth shuffle implementation wrapped in unchecked block
        // Overflow/underflow extremely unlikely given tokens length and for loop bounds
        // If something awful happens here, there are bigger problems at hand
        unchecked {
            uint256 numShuffles = tokens.length-1;

            for (uint256 i = numShuffles; i > 0; --i) {
                // Generate a random index to select from, where i+1 = 10000, 9999, etc
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

    /// @notice Assigns the gift tier to all token ids that will receieve gifts.
    /// @dev Indexes 0 to 2510 equate to 2511 winners in total.
    function setTokenGiftData() external onlyOwner {
        require(shuffled, "Gifts.sol::setTokenGiftData() Tokens array must be shuffled before assigning gift tiers");

        unchecked {
            for(uint256 i = 0; i < TOTAL_RECIPIENTS; ++i) {

                uint256 tokenId = tokens[i];

                // Index 0 (first token id in tokens)       Tier 1: $100,000 USDC
                if(i == 0) {
                    tokenData[tokenId].tier = Tier.One;
                }
                // Indexes 1-10 (1,2,3,...,10)              Tier 2: $10,000 USDC
                else if(i < 11) {
                    tokenData[tokenId].tier = Tier.Two;
                } 
                // Indexes 11-110 (11,12,13,...,110)        Tier 3: $1,000 USDC
                else if(i < 111) {
                    tokenData[tokenId].tier = Tier.Three;
                }
                // Indexes 111-510 (111,112,113,...,510)    Tier 4: $500 USDC
                else if(i < 511) {
                    tokenData[tokenId].tier = Tier.Four;
                } 
                // Indexes 511-2510 (511,512,513,...,2510)  Tier 5: $250 USDC
                else if(i < 2511) {
                    tokenData[tokenId].tier = Tier.Five;
                }
            } 
        }

        emit GiftDataSet();
    }

    /// @notice Allows owner to override the timestamp when the gift claiming period ends.
    /// @param _claimEnd New timestamp for the end of the gift claiming period.
    function overrideClaimEnd(uint256 _claimEnd) external onlyOwner {
        claimEnd = _claimEnd;
    }

    /// @notice Allows owner to update the Chainlink VRF subscription id.
    /// @param _subId New Chainlink VRF subscription id.
    function updateSubId(uint64 _subId) external onlyOwner {
        subId = _subId;
    }

    /// @notice Updates the address of the Circle account to withdraw leftover stablecoin to. 
    /// @param _circleAccount Address of the Circle account.
    function updateCircleAccount(address _circleAccount) external onlyOwner {
        require(_circleAccount != address(0), "Gifts.sol::updateCircleAccount() Address cannot be zero address");
        circleAccount = payable(_circleAccount);
    }

    /// @notice Updates the address of the multi-signature wallet to safe withdraw ERC20 tokens. 
    /// @param _multiSig Address of the multi-signature wallet.
    function updateMultiSig(address _multiSig) external onlyOwner {
        require(_multiSig != address(0), "NFT.sol::updateMultiSig() Address cannot be zero address");
        multiSig = payable(_multiSig);
    }

    /// @notice Withdraws leftover stablecoin balance of this contract into the Circle account.
    function withdrawStable() external onlyOwner {
        uint256 balance = stableCurrency.balanceOf(address(this));
        require(balance > 0, "Gift.sol::withdrawStable() Insufficient token balance");

        bool success = stableCurrency.transfer(circleAccount, balance);
        require(success, "Gift.sol::withdrawStable() Transfer failed on ERC20 contract");
    }

    /// @notice Withdraws any ERC20 token balance of this contract into the Circle account.
    function withdrawERC20(address _contract) external onlyOwner {
        require(_contract != address(0), "Gift.sol::withdrawERC20() Contract address cannot be zero address");

        uint256 balance = IERC20(_contract).balanceOf(address(this));
        require(balance > 0, "Gift.sol::withdrawERC20() Insufficient token balance");

        bool success = IERC20(_contract).transfer(multiSig, balance);
        require(success, "Gift.sol::withdrawERC20() Transfer failed on ERC20 contract");
    }
}