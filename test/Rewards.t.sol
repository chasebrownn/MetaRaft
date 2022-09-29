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
            "RaftToken",                // Name of collection
            "RT"                        // Symbol of collection
        );

        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                       //USDC Address
            address(raftToken)          //NFT Address
        ); 
    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_init_state() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");
        assertEq(raftToken.totalSupply(), 10000);
        assertEq(raftToken.raftPrice(), 1 ether);

        assertEq(reward.stableCurrency(), USDC);
        assertEq(reward.nftContract(), address(raftToken));
    }
}
