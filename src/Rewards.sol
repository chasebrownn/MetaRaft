// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Rewards is Ownable {
    // ---------------
    // State Variables
    // ---------------

    address public stableCurrency; /// @notice Used to store address of coin used to deposit/payout from Rewards.sol.
    address public nftContract; /// @notice Used to store the address of the NFT contract.
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

}
