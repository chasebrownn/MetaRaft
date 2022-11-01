// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import "./utils/Merkle.sol";

contract NFTTest is Test, Utility {
    // State variable for contract.
    NFT raftToken;
    Rewards reward;
    Merkle merkle;

    function setUp() public {
        createActors();
        setUpTokens();

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection.
            "RT",                               // Symbol of collection.
            address(crc),                       // Circle Account.
            address(sig)                        // Multi-signature wallet.
        );

        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                               // USDC Address.
            address(raftToken),                 // NFT Address.
            address(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D)     // VRF Goerli Testnet Coordinator Address.
        ); 

        // Initialize Merkle contract for constructing Merkle tree roots and proofs.
        merkle = new Merkle();
    }

    /// @notice Test constants and values assigned in the constructor once deployed.
    function test_nft_DeployedState() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");

        assertEq(raftToken.totalSupply(), 10000);
        assertEq(raftToken.raftPrice(), 1 ether);
        assertEq(raftToken.maxRaftPurchase(), 20);

        assertEq(raftToken.currentTokenId(), 0);
        assertEq(raftToken.publicSaleActive(), false);
        assertEq(raftToken.publicSaleActive(), false);
    }

    /// @notice Test that minting while whitelist and public sale not active reverts.
    function test_nft_mint_NoActiveSales() public {
        // Pre-State Check
        assert(!raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Joe annot mint with no active sales
        bytes32[] memory proof;
        vm.startPrank(address(joe));

        // Joe cannot mint via public mint
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        raftToken.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint
        vm.expectRevert(bytes("NFT.sol::mint() Whitelist sale is not currently active"));
        raftToken.mintWhitelist{value: 1 ether}(1, proof);
    }

    /// @notice Test that minting while whitelist sale active reverts
    function test_nft_mint_AddressNotWhitelisted() public {
        bytes32[] memory invalidProof;

        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Pre-State Check
        assert(!raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        // Joe cannot mint via public mint 
        vm.startPrank(address(joe));
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        raftToken.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint either
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Address not whitelisted"));
        raftToken.mintWhitelist{value: 1 ether}(1, invalidProof);
        vm.stopPrank();
    }

    function test_nft_mint_AddressIsWhitelisted() public {
        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);

        (address[] memory whitelist, bytes32[] memory tree) = createWhitelist(2);
        bytes32 root = merkle.getRoot(tree);
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        raftToken.updateWhitelistRoot(root);

        vm.prank(address(whitelist[0]));
        raftToken.mintWhitelist{value: 1 ether}(1, validProof);

        assertEq(raftToken.currentTokenId(), 1);
        assertEq(raftToken.balanceOf(address(whitelist[0])), 1);
        assertEq(raftToken.ownerOf(1), address(whitelist[0]));
    }

    function test_nft_mint_whitelistProof() public {
        // Generate array of 20 whitelisted addresses and 20 bytes32 encoded addresses to construct merkle tree.
        (address[] memory whitelist, bytes32[] memory tree) = createWhitelist(20);
        bytes32 root = merkle.getRoot(tree);

        // Owner assigns whitelist Merkle root
        raftToken.updateWhitelistRoot(root);
        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Pre-state check
        assert(!raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        // Mint every whitelisted user 20 tokens and verify proofs are valid. (20 * 20 = 400 tokens total)
        for(uint j = 0; j < 20; ++j) {
            bytes32[] memory validProof = merkle.getProof(tree, j);
            vm.prank(whitelist[j]);
            raftToken.mintWhitelist{value: 20 * 1e18}(20, validProof);
            assertEq(raftToken.balanceOf(whitelist[j]), 20);
        }

        // Joe cannot mint with no active public sale
        vm.prank(address(joe));
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        raftToken.mint{value: 20 * 1e18}(20);
        
        // Joe cannot mint during active whitelist sale with valid proof
        bytes32[] memory invalidProof = merkle.getProof(tree, 0);
        vm.prank(address(joe));
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Address not whitelisted"));
        raftToken.mintWhitelist{value: 20 * 1e18}(20, invalidProof);
        
        // //Post-state check
        assertEq(raftToken.balanceOf(address(joe)), 0);
        assertEq(raftToken.currentTokenId(), 20 * 20);
    }
    
    /// tests active sale restrictions for minting
    function test_nft_mint_BothSalesActive() public{
        // Owner whitelsits Art


        // Owner activates whitelist sale
        raftToken.setWhitelistSaleState(true);
        raftToken.setPublicSaleState(true);
        
        // Pre-state check
        assert(raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        //Joe and Art can mint NFTs
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        //Post-state check
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }

    /// @notice Test that minting yields the proper token quantity and token ids.
    /// @dev When using try_mint pass message value with the function call and as a parameter.
    function test_nft_mint_public_basic() public {
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
    /// @notice Test the mint function with uint256 max value as amount to demonstrate revert.
    function test_nft_mint_amountRestriction() public {
        // Assign amount of tokens to maximum value of parameter type.
        uint256 amount = type(uint256).max;

        // Ensure that the current token id begins at 0.
        assertEq(raftToken.currentTokenId(), 0);
        // Ensure that the current token id after reserving 90 tokens is 90.
        raftToken.reserveTokens(90);
        assertEq(raftToken.currentTokenId(), 90);

        // Set public sale state to true so Joe can attempt to mint tokens.
        raftToken.setPublicSaleState(true);
        
        // Make the next call appear to come from the address of Joe.
        vm.prank(address(joe));
        vm.deal(address(joe), 1 ether);
        // Assume the next call will not pass amount restriction
        vm.expectRevert(bytes("NFT.sol::mint() Amount requested exceeds maximum purchase (20)"));
        raftToken.mint{value: 1 * 1e18}(amount);
    }

    /// @notice Test that an attempt to mint more than the total supply reverts.
    function test_nft_mint_totalSupply() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Mint total supply worth of tokens.
        uint256 price = raftToken.maxRaftPurchase() * raftToken.raftPrice();
        uint256 totalBuys = raftToken.totalSupply() / raftToken.maxRaftPurchase();
        for(uint i = 0; i < totalBuys; i++) {
            Actor user = new Actor();
            assert(user.try_mint{value: price}(address(raftToken), 20, price));
        }
        // Verify that current token id is equal to total supply.
        assertEq(raftToken.currentTokenId(), raftToken.totalSupply());

        // Attempt to mint more than total supply.
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Verify that the current token id is unchanged after failed mint.
        assertEq(raftToken.currentTokenId(), raftToken.totalSupply());
    }

    /// @notice Test that minting more tokens than the maximum purchase reverts.
    function test_nft_mint_maxRaftPurchase() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Joe cannot mint more than 20 tokens
        assert(!joe.try_mint{value: 21 ether}(address(raftToken), 21, 21 ether));

        //Joe can mint 20 tokens, max wallet size
        assert(joe.try_mint{value: 20 ether}(address(raftToken), 20, 20 ether));
        
        //Joe cannot surpass 20 tokens minted
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));
    }

    /// @notice Test that minting with insufficient value reverts.
    function test_nft_mint_salePrice() public {
        // Set public sale state to true
        raftToken.setPublicSaleState(true);

        // Joe cannot mint for less than the token price
        assert(!joe.try_mint{value: .9 ether}(address(raftToken), 1, .9 ether));
        assertEq(raftToken.balanceOf(address(joe)), 0);

        // Joe cannot mint multiple tokens for less than the token price * number of tokens
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 2, 1 ether));
        assertEq(raftToken.balanceOf(address(joe)), 0);

        assert(joe.try_mint{value: 5 ether}(address(raftToken), 4, 5 ether));
    }

    /// @notice Test to estimate gas costs for ownedTokens view function for a wallet that owns
    /// random number of sequential token ids at random in the range of possible token ids
    function test_nft_ownedTokens_Fuzzing(uint256 mintAmount, uint256 startingId) public {
        mintAmount = bound(mintAmount, 1, 20);
        startingId = bound(startingId, 1, raftToken.totalSupply()-mintAmount);

        // Mint all tokens before the random starting token id.
        raftToken.setPublicSaleState(true);
        raftToken.reserveTokens(startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted.
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
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }
        emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet
    /// that owns sequential token ids at the start of the range of possible token ids.
    function test_nft_ownedTokens_sequentialLow() public {
        // Initialize static variables.
        uint256 startingId = 700;
        uint256 mintAmount = 17;

        // Set public sale state to true.
        raftToken.setPublicSaleState(true);
        // Mint all tokens up to the starting token id.
        raftToken.reserveTokens(startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted.
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe.
        assert(joe.try_mint{value: 17 ether}(address(raftToken), mintAmount, 17 ether));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive.
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId.
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet
    /// that owns sequential token ids at the height of the range of possible token ids.
    function test_nft_ownedTokens_sequentialHigh() public {
        // Set public sale state to true.
        raftToken.setPublicSaleState(true);

        // Initialize static variables.
        uint256 mintAmount = 17;
        // For loop is equivalent to startingId = 9000;
        for(uint i = 0; i < 100; i++) {
            raftToken.reserveTokens(90);
        }

        // The first token id Joe mints, currentTokenId is the token id most recently minted.
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe.
        assert(joe.try_mint{value: 17 ether}(address(raftToken), mintAmount, 17 ether));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive.
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId.
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 0.5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_sporadicSmall() public {
        // Set the public sale state to be true.
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own.
        uint16[50] memory ownedIds = [268, 435, 656, 767, 1186, 1197, 1229, 1655, 1673, 1897, 1950, 2230, 2332, 2489, 2497, 2981, 3069, 3524, 3603, 3644, 3876, 4075, 4124, 4144, 4375, 4393, 4587, 4857, 5274, 5436, 5565, 5663, 6206, 6497, 6552, 7150, 7197, 7321, 7348, 7697, 7736, 8236, 8496, 8563, 8586, 8601, 9311, 9324, 9458, 9846];

        uint256 index = 0;
        uint256 total = raftToken.totalSupply(); 
        for(uint256 id = 1; id <= total; id++) {
            // Ensure we don't go beyond the number of owned token ids
            if(index < ownedIds.length) {
                raftToken.reserveTokens(1);
                
                // If the current id is equal to the owned id at index, transfer the token to Joe
                if(id == ownedIds[index]) {
                    raftToken.transferFrom(address(this), address(joe), id);
                    index++;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned.
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokenIds);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 2% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_sporadicMedium() public {
        // Set the public sale state to be true.
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own.
        uint16[200] memory ownedIds = [46, 214, 248, 258, 260, 273, 287, 344, 412, 617, 620, 691, 696, 758, 777, 901, 1020, 1021, 1093, 1114, 1144, 1151, 1165, 1191, 1225, 1257, 1288, 1312, 1397, 1409, 1430, 1444, 1447, 1614, 1627, 1718, 1940, 2166, 2232, 2313, 2321, 2371, 2374, 2380, 2382, 2407, 2446, 2500, 2524, 2584, 2615, 2647, 2662, 2751, 2816, 2943, 2973, 2977, 3041, 3048, 3132, 3141, 3147, 3357, 3397, 3405, 3480, 3485, 3587, 3632, 3743, 3748, 3766, 3824, 4068, 4157, 4197, 4227, 4255, 4295, 4305, 4309, 4464, 4538, 4564, 4576, 4577, 4603, 4610, 4657, 4659, 4695, 4722, 4732, 4760, 4803, 4854, 4889, 4900, 4949, 5033, 5067, 5074, 5087, 5179, 5247, 5305, 5411, 5420, 5625, 5737, 5741, 5745, 5753, 5778, 5839, 5959, 6027, 6029, 6258, 6281, 6445, 6523, 6563, 6633, 6686, 6796, 6824, 6840, 6989, 7026, 7032, 7104, 7151, 7171, 7204, 7320, 7325, 7335, 7411, 7412, 7435, 7485, 7557, 7588, 7654, 7655, 7667, 7668, 7689, 7758, 7762, 7773, 7774, 7786, 7831, 7924, 7948, 7975, 7991, 8194, 8215, 8218, 8222, 8239, 8252, 8279, 8335, 8344, 8359, 8429, 8444, 8453, 8458, 8684, 8742, 8785, 8789, 8827, 8897, 9022, 9221, 9246, 9249, 9300, 9338, 9347, 9370, 9437, 9509, 9536, 9629, 9648, 9664, 9679, 9693, 9756, 9797, 9876, 9961];
        uint256 index = 0;
        uint256 total = raftToken.totalSupply();

        for(uint256 id = 1; id <= total; id++) {
            // Ensure we don't go beyond the number of owned token ids
            if(index < ownedIds.length) {
                raftToken.reserveTokens(1);

                // If the current id is equal to the owned id at index, transfer the token to Joe
                if(id == ownedIds[index]) {
                    raftToken.transferFrom(address(this), address(joe), id);
                    index++;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned.
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokenIds);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_sporadicLarge() public {
        // Set the public sale state to be true.
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own.
        uint16[500] memory ownedIds = [12, 15, 29, 37, 43, 50, 88, 94, 100, 107, 109, 137, 164, 177, 186, 213, 281, 295, 296, 350, 352, 361, 379, 389, 420, 441, 443, 461, 506, 516, 551, 579, 584, 625, 633, 643, 653, 668, 682, 702, 708, 728, 763, 777, 783, 794, 836, 882, 890, 897, 906, 920, 922, 933, 945, 975, 1004, 1016, 1018, 1030, 1037, 1042, 1053, 1084, 1085, 1090, 1094, 1122, 1146, 1154, 1160, 1190, 1201, 1204, 1212, 1221, 1224, 1231, 1269, 1280, 1284, 1317, 1330, 1363, 1379, 1384, 1390, 1400, 1418, 1468, 1475, 1477, 1478, 1485, 1504, 1514, 1541, 1551, 1568, 1599, 1603, 1606, 1620, 1628, 1651, 1652, 1663, 1715, 1721, 1744, 1759, 1776, 1797, 1837, 1847, 1875, 1879, 1891, 1917, 1919, 1957, 1973, 2015, 2048, 2052, 2065, 2069, 2074, 2076, 2102, 2104, 2112, 2114, 2118, 2151, 2183, 2194, 2205, 2209, 2219, 2251, 2262, 2279, 2288, 2307, 2369, 2380, 2383, 2434, 2451, 2499, 2572, 2581, 2586, 2616, 2617, 2628, 2642, 2643, 2649, 2651, 2659, 2666, 2722, 2731, 2733, 2748, 2762, 2792, 2797, 2807, 2814, 2848, 2878, 2894, 2914, 2924, 2929, 2933, 2965, 2977, 2978, 2986, 3107, 3117, 3147, 3158, 3175, 3206, 3213, 3229, 3259, 3309, 3331, 3349, 3407, 3418, 3439, 3445, 3455, 3469, 3483, 3488, 3525, 3530, 3594, 3607, 3628, 3663, 3687, 3699, 3705, 3721, 3742, 3767, 3769, 3775, 3790, 3839, 3861, 3866, 3906, 3911, 3933, 3957, 3981, 3988, 4008, 4016, 4045, 4057, 4100, 4128, 4147, 4149, 4172, 4188, 4211, 4214, 4228, 4261, 4291, 4311, 4336, 4340, 4356, 4366, 4371, 4398, 4407, 4412, 4429, 4436, 4454, 4456, 4462, 4521, 4592, 4609, 4610, 4614, 4648, 4650, 4663, 4730, 4744, 4785, 4787, 4794, 4823, 4827, 4831, 4853, 4891, 4894, 4895, 4897, 4914, 4933, 4969, 4983, 5001, 5005, 5016, 5034, 5073, 5081, 5100, 5109, 5111, 5114, 5117, 5132, 5221, 5258, 5265, 5272, 5286, 5314, 5316, 5373, 5376, 5381, 5389, 5393, 5397, 5500, 5502, 5551, 5587, 5589, 5611, 5618, 5623, 5634, 5643, 5677, 5700, 5732, 5779, 5784, 5809, 5833, 5843, 5862, 5887, 5905, 5951, 5972, 5991, 6016, 6110, 6122, 6126, 6132, 6147, 6152, 6154, 6177, 6184, 6201, 6202, 6228, 6266, 6267, 6283, 6285, 6298, 6324, 6329, 6344, 6360, 6376, 6404, 6423, 6529, 6547, 6550, 6587, 6588, 6649, 6650, 6675, 6728, 6730, 6731, 6742, 6748, 6766, 6782, 6784, 6890, 6893, 6900, 6902, 6927, 6938, 6944, 6972, 6989, 7019, 7031, 7042, 7072, 7100, 7110, 7126, 7149, 7163, 7174, 7196, 7203, 7214, 7239, 7282, 7299, 7315, 7320, 7330, 7346, 7369, 7441, 7444, 7459, 7465, 7515, 7517, 7539, 7553, 7608, 7631, 7640, 7647, 7657, 7664, 7769, 7801, 7815, 7838, 7848, 7855, 7871, 7874, 7918, 7977, 8013, 8038, 8076, 8077, 8127, 8133, 8204, 8288, 8294, 8300, 8321, 8346, 8348, 8360, 8401, 8443, 8484, 8485, 8535, 8554, 8582, 8584, 8599, 8601, 8649, 8721, 8736, 8754, 8801, 8913, 8958, 8968, 8980, 8982, 8987, 8992, 8994, 9002, 9040, 9145, 9188, 9190, 9201, 9238, 9253, 9254, 9271, 9313, 9356, 9380, 9424, 9450, 9542, 9550, 9560, 9592, 9596, 9598, 9657, 9663, 9716, 9731, 9797, 9809, 9850, 9852, 9861, 9890, 9893, 9910, 9919, 9933, 9937, 9985, 9993];
        uint256 index = 0;
        uint256 total = raftToken.totalSupply(); 

        for(uint256 id = 1; id <= total; id++) {
            // Ensure we don't go beyond the number of owned token ids
            if(index < ownedIds.length) {
                raftToken.reserveTokens(1);
                
                // If the current id is equal to the owned id at index, transfer the token to Joe.
                if(id == ownedIds[index]) {
                    raftToken.transferFrom(address(this), address(joe), id);
                    index++;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance.
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned.
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // Log the token ids returned.
        emit log_array(tokenIds);
    }



    /// @notice Test updating metadata URI
    function test_nft_setBaseURI() public {
        //Pre-state check
        assertEq(raftToken.baseURI(), "");

        //Owner sets new baseURI
        raftToken.setBaseURI("Arbitrary String");

        //Post-state check
        assertEq(raftToken.baseURI(), "Arbitrary String");
    }

    /// @notice Test calling tokenURI for a specific NFT
    function test_nft_tokenURI_Basic() public {
        // Owner enables public mint and sets BaseURI
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        // Joe mints token id 1
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Joe can callcCall TokenURI for id 1
        assert(joe.try_tokenURI(address(raftToken), 1));

        // Post-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");
    }

    /// tests calling tokenURI for a specific NFT after updated base URI
    function test_nft_tokenURI_Update() public {
        // Set baseURI and enable public sale
        raftToken.setBaseURI("URI/");
        raftToken.setPublicSaleState(true);

        // Joe can mint token id 1
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1, 1 ether));

        // Pre-state check
        assertEq(raftToken.tokenURI(1), "URI/1.json");

        // Update BaseURI
        raftToken.setBaseURI("UpdatedURI/");

        // Post-state check
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

}
