// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";

import { SafeERC20 } from "./interfaces/SafeERC20.sol";
import { IERC20, IWETH, ITreasury, curve3PoolStableSwap, curveTriCrypto2StableSwap } from "./interfaces/InterfacesAggregated.sol";
import { IERC20 } from "./interfaces/InterfacesAggregated.sol";

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

    using SafeERC20 for IERC20;

    address public multiSig;                /// @notice Used to store address of the metaraft official multi-sig wallet.
    address public stableCurrency;          /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    address public nftContract;             /// @notice Used to store the address of the NFT contract.
    address public pythonScript;            /// @notice Used to store the address of the python script.
    bool public redemptionEnabled;          /// @notice Used to enable/disable redemptions.

    enum rewardTiers {                       
        TIER_ONE, TIER_TWO, TIER_THREE, TIER_FOUR, TIER_FIVE, TIER_SIX
    }                                        /// @notice Used to store the rewards tier in an easier to read format.

    // contract addresses
    address constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT  = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // curve swap addresses
    address constant _3POOL_SWAP_ADDRESS = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address constant _TRICRYPTO2_SWAP_ADDRESS = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;


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

    /// @notice Used to determine if an NFT has already been redeemed. 
    /// @param _id NFT id that is atempting to be redeemed.
    function isRedeemed(uint256 _id) public onlyOwner() {

    }

    /// @notice Used to set the python script address.
    /// @param _pythonScript The address the python script is using.
    function setPythonScript(address _pythonScript) public onlyOwner() {
        require(_pythonScript != pythonScript, "Rewards.sol pythonScript is already set to this address");
        pythonScript = _pythonScript;

    }

    /// @notice Calls the Curve API to swap all ETH assets to USDC and transfers to MultiSig Wallet.
    function convertToStable() public onlyOwner(){
        uint256 _amount = address(this).balance;

        require(_amount > 0, "Rewards.sol::convertToStable() Amount must be greater than 0");

        uint256 min_dy = 1;

        assert(IERC20(WETH).approve(_TRICRYPTO2_SWAP_ADDRESS, _amount));
        curveTriCrypto2StableSwap(_TRICRYPTO2_SWAP_ADDRESS).exchange(uint256(2), uint256(0), _amount, min_dy);

        IERC20(USDT).safeApprove(_3POOL_SWAP_ADDRESS, uint256(IERC20(USDT).balanceOf(address(this))));
        curve3PoolStableSwap(_3POOL_SWAP_ADDRESS).exchange(int128(2), int128(1), uint256(IERC20(USDT).balanceOf(address(this))), min_dy);

        // Transfer swapped asset to MultiSig Wallet.
        uint256 amountUSDC = IERC20(USDC).balanceOf(address(this));
        assert(IERC20(USDC).transfer(multiSig, amountUSDC));
    }

}
