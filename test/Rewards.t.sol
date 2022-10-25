// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import {IWETH} from "../src/interfaces/InterfacesAggregated.sol";

contract RewardsTest is Test, Utility {
    // State variable for contract.
    NFT raftToken;
    Rewards reward;

    function setUp() public {
        createActors();
        setUpTokens();

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection.
            "RT",                               // Symbol of collection.
            address(crc),
            address(sig)
        );

        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                               // USDC Address.
            address(raftToken),                 // NFT Address.
            address(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D)     // VRF Goerli Testnet Coordinator Address.
        ); 
    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_init_state() public {
        assertEq(reward.stableCurrency(), USDC);
        assertEq(reward.nftContract(), address(raftToken));
        //emit log_array(reward.getFisherArray());

        reward.buildFisherArray(10_000);
        uint256[] memory array = reward.getFisherArray();
        assertEq(array.length, 10_000);
        //emit log_array(array);
    }

}
