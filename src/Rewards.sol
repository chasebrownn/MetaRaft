// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/VRFCoordinatorV2Interface.sol";
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
    uint256 public entropyId;               /// @notice Entropy request id provided by Chainlink VRF requestRandomWords().
    bytes32 public constant keyhash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    /// ---- 32 bytes packed ----
    VRFCoordinatorV2Interface public vrfCoordinator;    // 160 bits aka 20 bytes
    uint64 public subscriptionId = 5244;                // 64 bits aka 8 bytes
    uint32 public callbackGasLimit = 50_000;            // 32 bits aka 4 bytes
    uint32 public numWords = 1;                         // 32 bits aka 4 bytes
    /// ---- 32 bytes packed ----

    uint16 public requestConfirmations = 20;            // 16 bits aka 2 bytes 
    bool public entropySet;                 /// @notice Used to determine if entropy has been received from VFR.

    // 8 bits aka 1 byte
    enum Tier {         
        Unset, One, Two, Three, Four, Five, Six
    }                                        /// @notice Used to store the rewards tier in an easier to read format.
    // 1 byte
    bool public redemptionEnabled;          /// @notice Used to enable/disable redemptions.

    // 22 byte structure
    struct GiftData {
        address recipient;  /// @notice Default value is address(0).
        Tier tier;          /// @notice Default value is Tier.Unset.
        bool claimed;       /// @notice Default value is false.
    }

    // 32 bytes
    mapping(uint256 => GiftData) public currentOwner;   /// @notice Internal ownership tracking to ensure gifts are non-transferrable.
    uint256 public constant totalGiftRecipients = 2511;
    address public stableCurrency;          /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    address public nftContract;             /// @notice Used to store the address of the NFT contract.
    uint256[] public fisherArray;


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Rewards.sol.
    /// @param _stableCurrency Used to store address of stablecoin used in contract (default is USDC).
    /// @param _nftContract Used to store the address of the NFT contract ($META).
    /// @param _vrfCoordinator Contract address for Chainlink's VRF Coordinator V2.
    constructor(address _stableCurrency, address _nftContract, address _vrfCoordinator) 
    VRFConsumerBaseV2(_vrfCoordinator) {
        stableCurrency = _stableCurrency;
        nftContract = _nftContract;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);

        transferOwnership(msg.sender);
    }



    // ---------
    // Modifiers
    // ---------

    /// @notice Only authorized NFT contract can call functions with this modifier.
    modifier isNFTContract() {
        require(address(msg.sender) == nftContract, "Rewards.sol::isNFTContract() Caller is not the NFT contract");
        _;
    }



    // ---------
    // Functions
    // ---------

    function setFisherArray() external onlyOwner {
        unchecked {
            for(uint i = 10000; i > 0; --i) {
                fisherArray.push(i);
            }
        }
    }

    function getFisherArray() public view returns (uint256[] memory) {
        return fisherArray;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        require(entropyId == requestId, "Gifts.sol::fulfillRandomWords() Request id does not match expected entropy id");
        require(!entropySet, "Gifts.sol::fulfillRandomWords() Entropy has already been fulfilled");

        entropySet = true;
        entropy = randomWords[0];
    }

    function setEntropy() external onlyOwner returns (uint256) {
        require(!entropySet, "Gifts.sol::setEntropy() Entropy has already been fulfilled");
        
        entropyId = vrfCoordinator.requestRandomWords(keyhash, subscriptionId, requestConfirmations, callbackGasLimit, numWords);
        return entropyId;
    }

    function shuffle() external onlyOwner {
        // require(time > end)
        require(entropySet, "Gifts.sol::shuffle() Entropy for shuffle has not been fulfilled");

        // Run Fisher-Yates shuffle for AVAILABLE_SUPPLY
        uint256 numShuffles = fisherArray.length;
        for (uint256 i = 0; i < numShuffles; ++i) {
            // Generate a random index to select from
            uint256 randomIndex = i + entropy % (numShuffles - i);
            // Collect the value at that random index
            uint256 randomTmp = fisherArray[randomIndex];
            // Update the value at the random index to the current value
            fisherArray[randomIndex] = fisherArray[i];
            // Update the current value to the value at the random index
            fisherArray[i] = randomTmp;
        }

    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }

    /// @notice Allows owner to enable redeeming of rewards by users.
    /// @param _sanity Uint256 to verify sanity.
    function openRedeemWindow(uint256 _sanity) external onlyOwner {
        require(_sanity == 42, "Rewards.sol::openRedeemWindow() _sanity must be 42 to confirm");
        require(redemptionEnabled == false, "Rewards.sol::openRedeemWindow() redemption window is already active");

        redemptionEnabled = true;
    }

    /// @notice Allows owner to disable redeeming of rewards by users.
    /// @param _sanity Uint256 to verify sanity.
    function closeRedeemWindow(uint256 _sanity) external onlyOwner() {
        require(_sanity == 42, "Rewards.sol::closeRedeemWindow() _sanity must be 42 to confirm");
        require(redemptionEnabled == true, "Rewards.sol::closeRedeemWindow() redemption window is already inactive");
        
        redemptionEnabled = false;

    }   

    /// @notice Used to retrieve all winning IDs.
    function getWinners() external onlyOwner {

    }

    /// @notice Used to determine if an NFT is above tier one. 
    /// @param _id NFT id that is atempting to be redeemed.
    function getResults(uint256 _id) public onlyOwner {

    }

    /// @notice Used to determine if an NFT has already been redeemed. 
    /// @param _id NFT id that is atempting to be redeemed.
    function isRedeemed(uint256 _id) public onlyOwner {

    }

}