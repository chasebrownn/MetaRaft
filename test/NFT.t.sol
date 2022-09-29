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

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection.
            "RT"                                // Symbol of collection.
        );

        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                               // USDC Address.
            address(raftToken)                  // NFT Address.
        ); 
    }

    /// @notice tests intial values set in the constructor.
    function test_nft_init_state() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");
        assertEq(raftToken.totalSupply(), 10000);
        assertEq(raftToken.raftPrice(), 1 ether);
    }

    /// @notice tests that minting mints the proper quantity and ID of token.
    /// @dev when using try_mintDapp pass message value with the function call and as a parameter.
    function test_nft_mintDapp_public_simple() public {
        // Owner enables public sale
        raftToken.setPublicSaleState(true);
        // Joe can mint himself an NFT
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        // Joe owns NFT ID #1
        assertEq(raftToken.ownerOf(1), address(joe));
        // Joe has a balance of 1 NFTs
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }

    /// @notice tests active sale restrictions for minting
    function test_nft_mintDapp_NoSaleActive() public{
        // Owner Whitelsits Art
        raftToken.modifyWhitelist(address(art), true);

        // Pre-State Check
        assert(!raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Joe and Art cannot mint with no active sales
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(!art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
    }

    /// @notice tests public  sale restrictions for minting
    function test_nft_mintDapp_PublicSaleActive() public{
        // Owner Whitelsits Art
        raftToken.modifyWhitelist(address(art), true);

        // Owner activates publoc sale
        raftToken.setPublicSaleState(true);

        // Pre-State Check
        assert(raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Joe and Art can both mint with public sale active
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        
        //Post-state check
        assertEq(raftToken.balanceOf(address(joe)), 1);
        assertEq(raftToken.balanceOf(address(art)), 1);
    }

        /// @notice tests active sale restrictions for minting
    function test_nft_mintDapp_WhitelistSaleActive() public{
        // Owner whitelsits Art
        raftToken.modifyWhitelist(address(art), true);
        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Pre-state check
        assert(!raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        // Joe cannot mint with no active public sale
        // Art can mint with active Whitelist sale
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        //Post-state check
        assertEq(raftToken.balanceOf(address(joe)), 0);
        assertEq(raftToken.balanceOf(address(art)), 1);
    }
    
     /// @notice tests active sale restrictions for minting
    function test_nft_mintDapp_BothSaleActive() public{
        // Owner whitelsits Art
        raftToken.modifyWhitelist(address(art), true);
        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);
        raftToken.setPublicSaleState(true);
        
        // Pre-state check
        assert(raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        //Joe and Art can mint NFTs
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(art.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        //Post-state check
        assertEq(raftToken.balanceOf(address(joe)), 1);
        assertEq(raftToken.balanceOf(address(art)), 1);
    }

    /// @notice tests total supply limitations
    function test_nft_mintDapp_totalSupply() public {
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

    /// @notice tests maximum mint amount estrictions
    function test_nft_mintDapp_maxRaftPurchase() public {
        //Owner sets public sale active
        raftToken.setPublicSaleState(true);

        // Joe cannot mint more than 20 NFTs
        assert(!joe.try_mintDapp{value: 21 ether}(address(raftToken), 21, 21 ether));

        //Joe can mint 20 NFTS, max wallet size
        assert(joe.try_mintDapp{value: 20 ether}(address(raftToken), 20, 20 ether));
        
        //Joe cannot surpass 20 NFTs minted
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));
    }

    /// @notice tests minimum sale price restriction
    function test_nft_mintDapp_salePrice() public {
        raftToken.setPublicSaleState(true);
        assert(!joe.try_mintDapp{value: .9 ether}(address(raftToken), 1, .9 ether));
        assert(!joe.try_mintDapp{value: 1 ether}(address(raftToken), 2, 1 ether));
    }

    /// @notice tests updating metadata URI
    function test_nft_setBaseURI() public {
        //Pre-state check
        assertEq(raftToken.baseURI(), "");

        //Owner sets new baseURI
        raftToken.setBaseURI("Arbitrary String");

        //Post-state check
        assertEq(raftToken.baseURI(), "Arbitrary String");
    }

    /// @notice tests calling tokenURI for a specific NFT
    function test_nft_tokenURI_Basic() public {
        //Owner enables public mint and sets BaseURI
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        //Joe mints token id 1
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Joe can callcCall TokenURI for id 1
        assert(joe.try_tokenURI(address(raftToken), 1));

        //Post-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");
    }

    /// @notice tests calling tokenURI for a specific NFT after updated base URI
    function test_nft_tokenURI_Update() public {
        //Set baseURI and enable public sale
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        //Joe can Mint Token 1
        assert(joe.try_mintDapp{value: 1 ether}(address(raftToken), 1, 1 ether));

        //Pre-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");

        //Update BaseURI
        raftToken.setBaseURI("UpdatedURI/");

        //Post-state check
        assertEq(raftToken.tokenURI(1), "UpdatedURI/1.json");
    }

    /// @notice tests the onlyOwner modifier
    function test_nft_onlyOwner() public {
        raftToken.transferOwnership(address(dev));
        //Joe cannot call functinos with onlyOwner modifier
        assert(!joe.try_setBaseURI(address(raftToken), "Arbitrary String"));
        assert(!joe.try_modifyWhitelistRoot(address(raftToken), "Arbitrary String"));
        assert(!joe.try_setRewardsAddress(address(raftToken), address(rwd)));
        assert(!joe.try_setPublicSaleState(address(raftToken), true));
        assert(!joe.try_setWhitelistSaleState(address(raftToken), true));
        
        //dev can call functinos with onlyOwner modifier
        assert(dev.try_setBaseURI(address(raftToken), "Arbitrary String"));
        assert(dev.try_modifyWhitelistRoot(address(raftToken), "Arbitrary String"));
        assert(dev.try_setRewardsAddress(address(raftToken), address(rwd)));
        assert(dev.try_setPublicSaleState(address(raftToken), true));
        assert(dev.try_setWhitelistSaleState(address(raftToken), true));
    }

    /// @notice tests the isRewards modifier, which determines if the caller is Rewards.sol
    function test_nft_isRewards() public {
        //Set rewards contract
        raftToken.setRewardsAddress(address(rwd));
        //Verify reward contract has been updated
        assertEq(address(rwd), raftToken.rewardsContract());
    }

    /// @notice tests restrictions on updating reward contract address
    function test_nft_rewards_limitations() public {
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
