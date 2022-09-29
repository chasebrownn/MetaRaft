// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";

contract Rewards is Ownable {
    // ---------------
    // State Variables
    // ---------------

    address public stableCurrency;          /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    address public nftContract;             /// @notice Used to store the address of the NFT contract.
    address public pythonScript;            /// @notice Used to store the address of the python script.
    bool public redemptionEnabled;          /// @notice Used to enable/disable redemptions.

    enum rewardTiers {                       
        TIER_ONE, TIER_TWO, TIER_THREE, TIER_FOUR, TIER_FIVE, TIER_SIX
    }                                        /// @notice Used to store the rewards tier in an easier to read format.



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Rewards.sol
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



    // ---------
    // Functions
    // ---------

    /// @notice Allows NFT contract to deposit mint USDC.
    /// @notice Allows user to invest ETH into the REIT.
    /// @dev ETH is not ERC20, needs to be wrapped using the WETH contract.
    function depositETH() external payable isNFTContract() {

    }

    /// @notice Allows owner to enable redeeming of rewards by users.
    /// @param _sanity Uint256 to verify sanity.
    function openRedeemWindow(uint256 _sanity) external onlyOwner() {
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

    /// @notice Used to recieve the list of winning IDs from the python bot.
    function setWinners() external isPythonScript() {

    }

    /// @notice Used to retrieve all winning IDs.
    function getWinners() external onlyOwner() {

    }

    /// @notice Used to determine if an NFT is above tier one. 
    /// @param _id NFT id that is atempting to be redeemed.
    function getResults(uint256 _id) public onlyOwner() {

    }

}
