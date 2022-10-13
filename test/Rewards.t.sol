// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import {IERC20, IWETH} from "../src/interfaces/InterfacesAggregated.sol";

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
            "RT"                                // Symbol of collection.
        );

        // Initialize Rewards contract.
        reward = new Rewards(
            address(raftToken),                 // NFT Address.
            address(mlt),                       // Multi sig address.
            address(dev)                        // Dev Address.
        ); 
    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_init_state() public {
        assertEq(reward.nftContract(), address(raftToken));
        assertEq(reward.multiSig(), address(mlt));
        assertEq(reward.owner(), address(dev));

    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_mint_state() public {
        // Mint WETH
        mint("WETH", address(reward), 10 ether);

    }
    
    function test_rewards_convertToStable_restrictions() public {
        mint("WETH", address(reward), 10 ether);

        // "rwd" should not be able to call convertToStable().
        assert(!rwd.try_convertToStable(address(reward)));

        // "tkt" should not be able to call convertToStable().
        assert(!tkt.try_convertToStable(address(reward)));

        // "art" should not be able to call convertToStable().
        assert(!art.try_convertToStable(address(reward)));
    
        // "joe" should not be able to call convertToStable().
        assert(!joe.try_convertToStable(address(reward)));

        //Verify no usdc in multi sig wallet
        assertEq(IERC20(USDC).balanceOf(address(mlt)), 0);

        // "dev" should be able to call convertToStable().
        assert(dev.try_convertToStable(address(reward)));

        //Verify usdc distribution in multi sig wallet
        assert(IERC20(USDC).balanceOf(address(mlt)) > 0);

        // "dev" should not be able to convertToStable 0 tokens.
        assert(!dev.try_convertToStable(address(reward)));

    }
}
