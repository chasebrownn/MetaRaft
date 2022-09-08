// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";

contract NFTTest is Test, Utility {
    // State variable for contract.
    NFT raftToken;
    Rewards reward;

    function setUp() public {
        createActors();
        // nft constructor
        raftToken = new NFT(
            "RaftToken", // Name of collection
            "RT" // Symbol of collection
        );

        //TODO: Initialize Rewards contract
    }
}
