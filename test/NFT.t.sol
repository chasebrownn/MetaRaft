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

    /// @notice Test constants as well as values set in the constructor.
    function test_nft_init_state() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");

        assertEq(raftToken.totalSupply(), 10000);
        assertEq(raftToken.raftPrice(), 1 ether);
        assertEq(raftToken.maxRaftPurchase(), 20);

        assertEq(raftToken.currentTokenId(), 0);
        assertEq(raftToken.publicSaleActive(), false);
        assertEq(raftToken.publicSaleActive(), false);
    }

    /// @notice Test whitelist and public sale mint restrictions.
    function test_nft_mintDapp_NoSaleActive() public {

        // Pre-State Check
        assert(!raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Joe and Art cannot mint with no active sales
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
        assert(!art.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    }

    // /// tests public  sale restrictions for minting
    // function test_nft_mintDapp_PublicSaleActive() public{
    //     // Owner Whitelsits Art
    //     raftToken.modifyWhitelist(address(art), true);

    //     // Owner activates publoc sale
    //     raftToken.setPublicSaleState(true);

    //     // Pre-State Check
    //     assert(raftToken.publicSaleActive());
    //     assert(!raftToken.whitelistSaleActive());

    //     // Joe and Art can both mint with public sale active
    //     assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    //     assert(art.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
        
    //     //Post-state check
    //     assertEq(raftToken.balanceOf(address(joe)), 1);
    //     assertEq(raftToken.balanceOf(address(art)), 1);
    // }

    // /// tests active sale restrictions for minting
    // function test_nft_mintDapp_WhitelistSaleActive() public{
    //     // Owner whitelsits Art
    //     raftToken.modifyWhitelist(address(art), true);
    //     // Owner activates whitelist sale
    //     raftToken.setWhitelistSaleState(true);

    //     // Pre-state check
    //     assert(!raftToken.publicSaleActive());
    //     assert(raftToken.whitelistSaleActive());

    //     // Joe cannot mint with no active public sale
    //     // Art can mint with active Whitelist sale
    //     assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    //     assert(art.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

    //     //Post-state check
    //     assertEq(raftToken.balanceOf(address(joe)), 0);
    //     assertEq(raftToken.balanceOf(address(art)), 1);
    // }
    
    // /// tests active sale restrictions for minting
    // function test_nft_mintDapp_BothSaleActive() public{
    //     // Owner whitelsits Art
    //     raftToken.modifyWhitelist(address(art), true);
    //     // Owner activates whitelist sale
    //     raftToken.setWhitelistSaleState(true);
    //     raftToken.setPublicSaleState(true);
        
    //     // Pre-state check
    //     assert(raftToken.publicSaleActive());
    //     assert(raftToken.whitelistSaleActive());

    //     //Joe and Art can mint NFTs
    //     assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    //     assert(art.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

    //     //Post-state check
    //     assertEq(raftToken.balanceOf(address(joe)), 1);
    //     assertEq(raftToken.balanceOf(address(art)), 1);
    // }

    /// @notice Test that minting yields the proper quantity and ids of tokens.
    /// @dev When using try_mint pass message value with the function call and as a parameter.
    function test_nft_mint_public_Basic() public {
        // Owner enables public sale
        raftToken.setPublicSaleState(true);

        // Ensure currentTokenId starts at 0
        assertEq(raftToken.currentTokenId(), 0);

        // Joe can mint himself an NFT
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // After mint currentTokenId is incremented to 1 since this is the
        // most recently minted token id.
        assertEq(raftToken.currentTokenId(), 1);
        // Joe owns token with id 1
        assertEq(raftToken.ownerOf(1), address(joe));
        // Joe has a balance of 1 token
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }

    //address(raftToken).call{value: amount * 1e18}(abi.encodeWithSignature("mint(uint256)", 21));
    /// @notice Test the mint function with uint256 max value as amount to demonstrate automatic revert.
    function test_nft_mint_public_MaxUint() public {
        // Assign amount of tokens to maximum value of parameter type.
        uint256 amount = type(uint256).max;

        // Ensure that the current token id begins at 0.
        assertEq(raftToken.currentTokenId(), 0);
        // Ensure that the current token id after reserving 90 tokens is 90.
        raftToken.reserveAmount(90);
        assertEq(raftToken.currentTokenId(), 90);

        // Set public sale state to true so Joe can attempt to mint tokens.
        raftToken.setPublicSaleState(true);

        // Provide Joe with 10 eth to ensure there is plenty of funds.
        vm.deal(address(joe), 10 ether);
        
        // Make the next call appear to come from the address of Joe.
        vm.prank(address(joe));
        // Assume the next call will result in an arithmetic over/underflow error.
        vm.expectRevert(stdError.arithmeticError);
        raftToken.mint{value: 1 * 1e18}(amount);
    }

    /// @notice Test total supply restrictions.
    function test_nft_mint_totalSupply() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Mint 10_000 tokens aka the total supply.
        for(uint usr = 0; usr < 500 ; usr++ ){
            Actor user = new Actor();
            assert(user.try_mint{value: 20 ether}(address(raftToken), 20, 20 ether));
        }
        // Verify that current token id is equal to total supply.
        assertEq(raftToken.currentTokenId(), raftToken.totalSupply());

        // Attempt to mint more than total supply.
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Verify that the current token id is unchanged after failed mint.
        assertEq(raftToken.currentTokenId(), raftToken.totalSupply());
    }

    /// Test maximum token mint per address restrictions.
    function test_nft_mint_maxRaftPurchase() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Joe cannot mint more than 20 NFTs
        assert(!joe.try_mint{value: 21 ether}(address(raftToken), 21, 21 ether));

        //Joe can mint 20 NFTS, max wallet size
        assert(joe.try_mint{value: 20 ether}(address(raftToken), 20, 20 ether));
        
        //Joe cannot surpass 20 NFTs minted
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    }

    /// Test minimum sale price restrictions
    function test_nft_mint_salePrice() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Provide Joe with 10 ether.
        vm.deal(address(joe), 10 ether);

        // Joe cannot mint for less than the token price
        assert(!joe.try_mint{value: .9 ether}(address(raftToken), 1, .9 ether));
        assertEq(raftToken.balanceOf(address(joe)), 0);

        // Joe cannot mint multiple tokens for less than the token price * number of tokens
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 2, 1 ether));
        assertEq(raftToken.balanceOf(address(joe)), 0);

        assert(joe.try_mint{value: 5 ether}(address(raftToken), 4, 5 ether));
    }

    function test_nft_ownedTokens_Fuzzing(uint256 mintAmount, uint256 startingId) public {
        mintAmount = bound(mintAmount, 1, 20);
        startingId = bound(startingId, 1, raftToken.totalSupply()-mintAmount);

        // Mint all tokens before the random starting token id.
        raftToken.setPublicSaleState(true);
        raftToken.reserveAmount(startingId);

        // The first token id that Joe will mint, currentTokenId is the most recently minted token id.
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe.
        joe.try_mint{value: 20 ether}(address(raftToken), mintAmount, 20 ether);
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // the last token id that Joe will mint, Joe mints up to the currentTokenId inclusive.
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId.
        uint256 j = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[j++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }
        emit log_array(tokens);
    }

    function test_nft_ownedTokens_Sequential_Low() public {
        // Initialize static variables.
        uint256 startingId = 700;
        uint256 mintAmount = 17;

        // Set public sale state to true.
        raftToken.setPublicSaleState(true);
        // Mint all tokens up to the starting token id.
        raftToken.reserveAmount(startingId);

        // The first token id that Joe will mint.
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe.
        assert(joe.try_mint{value: 20 ether}(address(raftToken), mintAmount, 20 ether));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id that Joe will mint, Joe mints up to the currentTokenId inclusive.
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId.
        uint256 j = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[j++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokens);
    }

    function test_nft_ownedTokens_Sequential_High() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Initialize static variables.
        uint256 mintAmount = 17;
        // for loop is equivalent to startingId = 9000;
        for(uint i = 0; i < 100; i++) {
            raftToken.reserveAmount(90);
        }

        // The first token id that Joe will mint.
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe.
        assert(joe.try_mint{value: 20 ether}(address(raftToken), mintAmount, 20 ether));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id that Joe will mint, Joe mints up to the currentTokenId inclusive.
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId.
        uint256 j = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[j++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokens);
    }

    function test_nft_ownedTokens_sporadic() public {
        // Set the public sale state to be true.
        raftToken.setPublicSaleState(true);

        // Array of "randomized" token ids that a user could potentially own over time.
        uint16[12] memory ownedIds = [37, 100, 101, 102, 1000, 5000, 5001, 5002, 5003, 5004, 9000, 9987];

        uint256 index = 0;
        for(uint256 id = 1; id <= raftToken.totalSupply(); id++) {
            // Ensure we don't go beyond the number of owned token ids
            if(index < ownedIds.length) {
                // If the current id is equal to the owned id at index, mint the current id to Joe
                if(id == ownedIds[index]) {
                    joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether);
                    index++;
                } else {
                    raftToken.reserveAmount(1);
                }
            }
        }

        // Verify that the number of tokens Joe minted is equal to the length of owned tokens array.
        assertEq(raftToken.balanceOf(address(joe)), ownedIds.length);

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 j = 0; j < ownedIds.length; j++) {
            assertEq(tokenIds[j], ownedIds[j]);
            assertEq(raftToken.ownerOf(ownedIds[j]), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokenIds);
    }


    /// tests updating metadata URI
    function test_nft_setBaseURI() public {
        //Pre-state check
        assertEq(raftToken.baseURI(), "");

        //Owner sets new baseURI
        raftToken.setBaseURI("Arbitrary String");

        //Post-state check
        assertEq(raftToken.baseURI(), "Arbitrary String");
    }

    /// tests calling tokenURI for a specific NFT
    function test_nft_tokenURI_Basic() public {
        //Owner enables public mint and sets BaseURI
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        //Joe mints token id 1
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Joe can callcCall TokenURI for id 1
        assert(joe.try_tokenURI(address(raftToken), 1));

        //Post-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");
    }

    /// tests calling tokenURI for a specific NFT after updated base URI
    function test_nft_tokenURI_Update() public {
        //Set baseURI and enable public sale
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        //Joe can Mint Token 1
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        //Pre-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");

        //Update BaseURI
        raftToken.setBaseURI("UpdatedURI/");

        //Post-state check
        assertEq(raftToken.tokenURI(1), "UpdatedURI/1.json");
    }

    // /// tests the onlyOwner modifier
    // function test_nft_onlyOwner() public {
    //     raftToken.transferOwnership(address(dev));
    //     //Joe cannot call function with onlyOwner modifier
    //     assert(!joe.try_setBaseURI(address(raftToken), "Arbitrary String"));
    //     assert(!joe.try_modifyWhitelistRoot(address(raftToken), "Arbitrary String"));
    //     assert(!joe.try_setRewardsAddress(address(raftToken), address(rwd)));
    //     assert(!joe.try_setPublicSaleState(address(raftToken), true));
    //     assert(!joe.try_setWhitelistSaleState(address(raftToken), true));
        
    //     //dev can call function with onlyOwner modifier
    //     assert(dev.try_setBaseURI(address(raftToken), "Arbitrary String"));
    //     assert(dev.try_modifyWhitelistRoot(address(raftToken), "Arbitrary String"));
    //     assert(dev.try_setRewardsAddress(address(raftToken), address(rwd)));
    //     assert(dev.try_setPublicSaleState(address(raftToken), true));
    //     assert(dev.try_setWhitelistSaleState(address(raftToken), true));
    // }

    /// tests the isRewards modifier, which determines if the caller is Rewards.sol
    function test_nft_isRewards() public {
        //Set rewards contract
        raftToken.setRewardsAddress(address(rwd));
        //Verify reward contract has been updated
        assertEq(address(rwd), raftToken.rewardsContract());
    }

    /// tests restrictions on updating reward contract address
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
