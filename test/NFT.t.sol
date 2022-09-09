// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import {IWETH} from "../src/interfaces/InterfacesAggregated.sol";

contract NFTTest is Test, Utility {
    // State variable for contract.
    NFT raftToken;
    Rewards reward;

    function setUp() public {
        createActors();
        setUpTokens();

        // nft constructor
        raftToken = new NFT(
            "RaftToken", // Name of collection
            "RT" // Symbol of collection
        );

        //TODO: Initialize Rewards contract
    }


    /// @notice tests intial values set in the constructor
    function test_init_state() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");
    }

    /// @notice tests that minting mints the proper quantity and ID of token
    /// @dev when using try_mintDapp pass message value with the function call and as a parameter
    function test_mintDapp_public_simple() public {
        raftToken.setPublicSaleState(true);
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assertEq(raftToken.ownerOf(1), address(joe));
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }
}
