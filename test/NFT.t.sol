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
            "RT"         // Symbol of collection
        );

        //TODO: Initialize Rewards contract
    }


    /// @notice tests intial values set in the constructor
    function test_init_state() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");
        assertEq(raftToken.totalSupply(), 10000);
        assertEq(raftToken.raftPrice(), 1 ether);
    }

    /// @notice tests that minting mints the proper quantity and ID of token
    /// @dev when using try_mintDapp pass message value with the function call and as a parameter
    function test_mintDapp_public_simple() public {
        raftToken.setPublicSaleState(true);
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assertEq(raftToken.ownerOf(1), address(joe));
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }

    function test_mintDapp_SaleActive() public{
        // Whitelsit Art
        raftToken.modifyWhitelist(address(art), true);
        // No sales are active
        assert(!raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Minting With no active sales
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(!art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Minting during whitelist
        raftToken.setWhitelistSaleState(true);
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Only whitelist account receives NFT
        assertEq(raftToken.balanceOf(address(joe)), 0);
        assertEq(raftToken.balanceOf(address(art)), 1);

        raftToken.setWhitelistSaleState(false);
        //Minting during public
        raftToken.setPublicSaleState(true);
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        //Public sale both receive NFT
        assertEq(raftToken.balanceOf(address(joe)), 1);
        assertEq(raftToken.balanceOf(address(art)), 2);
    }

    function test_mintDapp_totalSupply() public {
        raftToken.setPublicSaleState(true);

        // Mint 10_000 NFTs (max supply)
        for(uint usr = 0; usr < 500 ; usr++ ){
            Actor user = new Actor();
            assert(user.try_mintDapp{value: 20 ether}(address(raftToken), 20, 20 ether));
        }
        //Current token Id is really next token ID, (minted tokens + 1)
        assertEq(raftToken.currentTokenId(), 10_001);

        // Mint over maximum supply
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assertEq(raftToken.currentTokenId(), 10_001);

    }

    function test_mintDapp_maxRaftPurchase() public {
        raftToken.setPublicSaleState(true);
        // Mint more than max 
        assert(!joe.try_mintDapp{value: 21 ether}(address(raftToken), 21, 21 ether));
        //Mint max wallet size
        assert(joe.try_mintDapp{value: 20 ether}(address(raftToken), 20, 20 ether));
        //Increment 1 
        joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether);
    }

    function test_mintDapp_salePrice() public {
        raftToken.setPublicSaleState(true);
        assert(!joe.try_mintDapp{value: .9 ether}(address(raftToken), 1, .9 ether));
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 2, 1 ether));
    }

    function testFail_StateConflict() public{
        raftToken.setWhitelistSaleState(true);  
        raftToken.setPublicSaleState(true);
    }

    function test_setBaseURI() public {
        assertEq(raftToken.baseURI(), "");
        raftToken.setBaseURI("Arbitrary String");
        assertEq(raftToken.baseURI(), "Arbitrary String");
    }

    function test_tokenURI_Basic() public {
        //Allow mint + set baseURI
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);
        //mint token id 1
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        // Call TokenURI for id 1
        assert(joe.try_tokenURI(address(raftToken), 1));

        assertEq(raftToken.tokenURI(1), "URI/1.json");



    }

    function test_tokenURI_Update() public {
        //Set baseURI and enable public sale
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);
        //Mint Token 1
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        // Check tokenURI
        assertEq(raftToken.tokenURI(1), "URI/1.json");
        //Update BaseURI
        raftToken.setBaseURI("UpdatedURI/");
        // Check tokenURI
        assertEq(raftToken.tokenURI(1), "UpdatedURI/1.json");
    }
    
    function test_onlyOwner() public {
        //Fail calling all onlyOwner
        assert(!joe.try_setBaseURI(address(raftToken), "Arbitrary String"));
        assert(!joe.try_modifyWhitelistRoot(address(raftToken), "Arbitrary String"));
        assert(!joe.try_setRewardsAddress(address(raftToken), address(rwd)));
        assert(!joe.try_setPublicSaleState(address(raftToken), true));
        assert(!joe.try_setWhitelistSaleState(address(raftToken), true));
    }
    function test_isRewards() public {
        //Set rewards contract
        raftToken.setRewardsAddress(address(rwd));
        // Verify reward contract has been updated
        assertEq(address(rwd), raftToken.rewardsContract());
    }
    function test_rewards_limitations() public {
        //Set rewards contract as non-owner
        assert(!dev.try_setRewardsAddress(address(raftToken), address(rwd)));
        //Set Owner
        raftToken.transferOwnership(address(dev));
        //Set Rewards Contract as owner
        assert(dev.try_setRewardsAddress(address(raftToken), address(rwd)));
        
        //Set Rewards contract to address 0
         assert(!dev.try_setRewardsAddress(address(raftToken), address(0)));

        //Set Rewards contract to address same address
        assert(!dev.try_setRewardsAddress(address(raftToken), address(rwd)));

        //Set Rewards contract to NFT contract address 
        assert(!dev.try_setRewardsAddress(address(raftToken), address(raftToken)));

        // Verify reward contract has been updated
        assertEq(address(rwd), raftToken.rewardsContract());
    }

}
