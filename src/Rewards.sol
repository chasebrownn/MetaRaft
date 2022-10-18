// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";

/// @dev    This non-standard contract is used to manage and distribute rewards acrewed after mint of NFT.sol.
///         This contract should support the following functionalities:
///         - Set winners (Based off of chainlink or python script)
///         - Get winners list
///         - Verify NFT authenticity 
///         - Distribute rewards
///         - Enable/Disable rewards window
///         - Get which IDs have redeemed rewards previously

contract Rewards is Ownable {

    // ---------------
    // State Variables
    // ---------------

    // Contract Interactions
    address public stableCurrency;          /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    address public nftContract;             /// @notice Used to store the address of the NFT contract.
    address public pythonScript;            /// @notice Used to store the address of the python script.
   
    // Rewards
    bool public redemptionEnabled;              /// @notice Used to enable/disable redemptions.
    uint public redeemWindowOpen;               /// @notice Used to store the block time of the redeem window open.
    uint public constant redeemPeriod = 1;      /// @notice Used to store the minimum redemption window for NFT rewards.
    mapping(uint => rewardsData) redeemState;   /// @notice Used to track NFT reward state data.

    enum rewardTiers {                       
        TIER_ONE, TIER_TWO, TIER_THREE, TIER_FOUR, TIER_FIVE, TIER_SIX
    }                                        /// @notice Used to store the rewards tier in an easier to read format.

    struct rewardsData{
        bool isWinner;
        bool isRedeemed;
        rewardTiers tier;
    }

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Rewards.sol.
    /// @param _stableCurrency Used to store address of stablecoin used in contract (default is USDC).
    /// @param _nftContract Used to store the address of the NFT contract ($META).
    constructor(address _stableCurrency, address _nftContract) {
        stableCurrency = _stableCurrency;
        nftContract = _nftContract;
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

    /// @notice Only authorized NFT contract can call functions with this modifier.
    modifier isPythonScript() {
        require(address(msg.sender) == pythonScript, "Rewards.sol::isPythonScript() Caller is not the python script");
        _;
    }

    // ------
    // Events
    // ------

    /// @dev Emitted when the redemption window is opened via openRedeemWindow()
    event RedemptionOpened(address indexed nftContract, uint redeemWindowOpen, uint minimumRedeemPeriod);

    /// @dev Emitted when the redemption window is opened via closeRedeemWindow()
    event RedemptionClosed(address indexed nftContract, uint redeemWindowOpen, uint realRedeemPeriod, uint redeemWindowClose);

    event RewardsSet(address indexed nftContract, string randomNumberSource, uint randomNumberVerificationHash);

    // ---------
    // Functions
    // ---------

    /// @notice Allows NFT contract to deposit mint USDC.
    /// @notice Allows user to invest ETH into the REIT.
    /// @dev ETH is not ERC20, needs to be wrapped using the WETH contract.
    function depositETH() external payable isNFTContract {

    }

    /// @notice Allows owner to enable redeeming of rewards by users.
    /// @param _sanity Uint256 to verify sanity.
    /// TODO Add a call to NFT contract to verify there is no active sale
    function openRedeemWindow(uint256 _sanity) external onlyOwner {
        require(_sanity == 42, "Rewards.sol::openRedeemWindow() _sanity must be 42 to confirm");
        require(redemptionEnabled == false, "Rewards.sol::openRedeemWindow() redemption window is already active");

        redemptionEnabled = true;
        redeemWindowOpened = block.timestamp;

        emit  RedemptionOpened(nftContract, redeemWindowOpened, redeemPeriod);

    }

    /// @notice Allows owner to disable redeeming of rewards by users.
    /// @param _sanity Uint256 to verify sanity.
    function closeRedeemWindow(uint256 _sanity) external onlyOwner {
        require(_sanity == 42, "Rewards.sol::closeRedeemWindow() _sanity must be 42 to confirm");
        require(redemptionEnabled == true, "Rewards.sol::closeRedeemWindow() redemption window is already inactive");
        require((block.timestamp - redeemWindowOpened) >= redeemPeriod,"Rewards.sol::closeRedeemWindow() redemption window cannot before redemption period is over");

        redemptionEnabled = false;

        emit RedemptionClosed(nftContract, redeemWindowOpened, (redeemWindowOpened-block.timestamp), block.timestamp);

    }   

    /// @notice Used to recieve the list of winning IDs from the python bot.
    function setWinners() external isPythonScript() {

    }

    /// @notice Used to retrieve all winning IDs.
    function getWinners() external onlyOwner {

    }

    /// @notice Used to determine if an NFT is above tier one. 
    /// @param _id NFT id that is atempting to be redeemed.
    /// TODO Should not be onlyOwner, all users of the dapp must call this for the dapp to load properly
    function getResults(uint256 _id) public onlyOwner returns(bool){
        return(rewardsData[_id].isWinner);
    }

    /// @notice Used to determine if an NFT has already been redeemed. 
    /// @param _id NFT id that is atempting to be redeemed.
    /// TODO Should not be onlyOwner, all users of the dapp must call this for the dapp to load properly
    function isRedeemed(uint256 _id) public onlyOwner returns(bool){
        return(rewardsData[_id].isRedeemed);
    }

    /// @notice Used to set the python script address.
    /// @param _pythonScript The address the python script is using.
    function setPythonScript(address _pythonScript) public onlyOwner {
        require(_pythonScript != pythonScript, "Rewards.sol pythonScript is already set to this address");
        pythonScript = _pythonScript;

    }

}
