// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import "./utils/Merkle.sol";

contract NFTTest is Test, Utility {
    // State variable for contracts.
    NFT raftToken;
    Merkle merkle;

    // State variables for whitelist.
    Actor[] public whitelist;
    bytes32[] public tree;
    bytes32 root;

    function setUp() public {
        createActors();
        setUpTokens();

        // Initialize Merkle contract for constructing Merkle tree roots and proofs
        merkle = new Merkle();

        // Assign array of 20 whitelisted addresses + 20 bytes32 hashed addresses to construct merkle tree
        (whitelist, tree) = createWhitelist(20);
        // Assign root of merkle tree constructed with Murky helper contract
        root = merkle.getRoot(tree);

        // Initialize NFT contract
        raftToken = new NFT(
            "RaftToken",                        // Name of collection
            "RT",                               // Symbol of collection
            "ipfs::/Unrevealed/",               // Unrevealed URI
            crc,                                // Circle Account
            sig,                                // Multi-signature wallet
            root                                // Whitelist root
        );

    }

    /// @notice Test constants and values assigned in the constructor once deployed.
    function test_nft_DeployedState() public {
        assertEq(raftToken.symbol(), "RT");
        assertEq(raftToken.name(), "RaftToken");
        assertEq(raftToken.circleAccount(), crc);
        assertEq(raftToken.multiSig(), sig);
        assertEq(raftToken.whitelistRoot(), root);
        assertEq(raftToken.unrevealedURI(), "ipfs::/Unrevealed/");

        assertEq(raftToken.currentTokenId(), 0);
        assertEq(raftToken.TOTAL_RAFTS(), 10000);
        assertEq(raftToken.RAFT_PRICE(), 1 ether);
        assertEq(raftToken.MAX_RAFTS(), 20);
        assertEq(raftToken.baseURI(), "");

        assertEq(raftToken.publicSaleActive(), false);
        assertEq(raftToken.whitelistSaleActive(), false);
    }


    // ----------------
    // Public Functions
    // ----------------

    // --- tokenURI() ---

    /// @notice Test that token URIs returned use the unrevealed URI when the base URI is not set.
    function test_nft_tokenURI_Unrevealed() public {
        // Verify base and unrevealed URIs are initialized properly
        assertEq(raftToken.baseURI(), "");
        assertEq(raftToken.unrevealedURI(), "ipfs::/Unrevealed/");

        // Ensure that token URIs return the unrevealed URI when base URI is not set
        assertEq(raftToken.tokenURI(1), "ipfs::/Unrevealed/1.json");
    }

    /// @notice Test that token URIs returned use the base URI once the base URI is set.
    function test_nft_tokenURI_Revealed() public {
        // Enable public sale
        raftToken.setPublicSaleState(true);

        // Joe can mint token id 1
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1));

        // Joe can get the token URI for token id 1 without reverting
        assert(joe.try_tokenURI(address(raftToken), 1));
        // Ensure that the token URI for token id 1 is the unrevealed URI
        assertEq(raftToken.tokenURI(1), "ipfs::/Unrevealed/1.json");

        // Once token tiers are finalized in Gifts, owner sets the base URI
        raftToken.setBaseURI("ipfs::/Revealed/");

        // Verify URI updates are reflected in state and functions
        assertEq(raftToken.baseURI(), "ipfs::/Revealed/");
        assertEq(raftToken.tokenURI(1), "ipfs::/Revealed/1.json");
    }

    // ---- mint() / mintWhitelist() ----

    /// @notice Test that minting while whitelist and public sale not active reverts.
    function test_nft_mint_NoActiveSales() public {
        // Verify state reflects active sales
        assert(!raftToken.publicSaleActive());
        assert(!raftToken.whitelistSaleActive());

        // Joe cannot mint with no active sales
        bytes32[] memory invalidProof;
        vm.startPrank(address(joe));

        // Joe cannot mint via public mint
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        raftToken.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Whitelist sale is not currently active"));
        raftToken.mintWhitelist{value: 1 ether}(1, invalidProof);
    }

    /// @notice Test that minting while whitelist sale active reverts.
    function test_nft_mint_AddressNotWhitelisted() public {
        // Enable whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Verify state reflects active sales
        assert(!raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        // Joe cannot mint via public mint 
        vm.startPrank(address(joe));
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        raftToken.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Address not whitelisted"));
        bytes32[] memory invalidProof;
        raftToken.mintWhitelist{value: 1 ether}(1, invalidProof);
    }

    /// @notice Test that a whitelisted address with a valid proof can mint.
    function test_nft_mint_AddressIsWhitelisted() public {
        // Enable whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Obtain proof using Murky contract
        bytes32[] memory validProof = merkle.getProof(tree, 0);

        // Attempt to mint via whitelist using valid proof
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(raftToken), 1, validProof));

        // Verify token id, ownership, and balance state changes
        assertEq(raftToken.currentTokenId(), 1);
        assertEq(raftToken.balanceOf(address(whitelist[0])), 1);
        assertEq(raftToken.ownerOf(1), address(whitelist[0]));
    }

    /// @notice Test that minting with whitelisted address and invalid proof reverts.
    function test_nft_mint_WhitelistedInvalidProof() public {
        // Enable whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Obtain proof using Murky contract
        bytes32[] memory invalidProof = merkle.getProof(tree, 1);

        // Attempt to mint via whitelist using invalid proof
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Address not whitelisted"));
        vm.prank(address(whitelist[0]));
        raftToken.mintWhitelist{value: 1 ether}(1, invalidProof);

        // Verify token id and ownership state changes
        assertEq(raftToken.currentTokenId(), 0);
        assertEq(raftToken.balanceOf(address(whitelist[0])), 0);
    }

    /// @notice Test that only whitelisted addresses with valid proofs can mint during whitelist sale.
    function test_nft_mint_WhitelistedValidProof() public {
        // Enable whitelist sale
        raftToken.setWhitelistSaleState(true);

        // Verify state reflects active sales
        assert(!raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());

        // Mint every whitelisted user 20 tokens and verify proofs are valid (20 * 20 = 400 tokens total)
        for(uint j = 0; j < 20; ++j) {
            bytes32[] memory proof = merkle.getProof(tree, j);
            assert(whitelist[j].try_mintWhitelist{value: 20 ether}(address(raftToken), 20, proof));
            assertEq(raftToken.balanceOf(address(whitelist[j])), 20);
        }

        // Joe cannot mint with no active public sale
        vm.expectRevert(bytes("NFT.sol::mint() Public sale is not currently active"));
        vm.prank(address(joe));
        raftToken.mint{value: 20 ether}(20);
        
        // Joe cannot mint during whitelist sale even with a "valid" proof
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        vm.expectRevert(bytes("NFT.sol::mintWhitelist() Address not whitelisted"));
        vm.prank(address(joe));
        raftToken.mintWhitelist{value: 20 ether}(20, validProof);
        
        // Verify token id and balance state changes
        assertEq(raftToken.balanceOf(address(joe)), 0);
        assertEq(raftToken.currentTokenId(), 20 * 20);
    }
    
    /// @notice Test active sale restrictions for whitelist and public mint.
    function test_nft_mint_BothSalesActive() public{
        // Enable whitelist and public sales
        raftToken.setWhitelistSaleState(true);
        raftToken.setPublicSaleState(true);
        
        // Verify balance for public and whitelist minters as well as sale state
        assert(raftToken.publicSaleActive());
        assert(raftToken.whitelistSaleActive());
        assertEq(raftToken.balanceOf(address(joe)), 0);
        assertEq(raftToken.balanceOf(address(whitelist[0])), 0);

        // Joe can mint tokens via public
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1));

        // Whitelisted user 0 can mint tokens via whitelist (cheaper to use public)
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(raftToken), 1, validProof));

        // Verify balance state changes for public and whitelist minters
        assertEq(raftToken.balanceOf(address(joe)), 1);
        assertEq(raftToken.balanceOf(address(whitelist[0])), 1);
    }

    /// @notice Test that minting yields the proper token quantity and token ids.
    function test_nft_mint_PublicBasic() public {
        // Enable public sale
        raftToken.setPublicSaleState(true);

        // Ensure currentTokenId starts at 0
        assertEq(raftToken.currentTokenId(), 0);

        // Joe can mint himself an NFT
        assert(joe.try_mint{value: 1 ether}(address(raftToken), 1));

        // After mint currentTokenId is incremented to 1 since this is the
        // most recently minted token id
        assertEq(raftToken.currentTokenId(), 1);
        // Joe owns token with id 1
        assertEq(raftToken.ownerOf(1), address(joe));
        // Joe has a balance of 1 token
        assertEq(raftToken.balanceOf(address(joe)), 1);
    }

    /// @notice Test the mint function reverts on amount values greater than maximum overall purchase.
    function test_nft_mint_MaxAmount() public {
        // Enable public sale
        raftToken.setPublicSaleState(true);

        // Assign amount of tokens to maximum value of parameter type
        uint256 amount = type(uint256).max;

        // Ensure that the current token id begins at 0
        assertEq(raftToken.currentTokenId(), 0);
        // Ensure that the current token id after minting 90 tokens is 90
        mintTokens(address(raftToken), 90);
        assertEq(raftToken.currentTokenId(), 90);
        
        // Joe cannot mint more than the maximum purchase amount at one time.
        vm.expectRevert(bytes("NFT.sol::mint() Amount requested exceeds maximum purchase (20)"));
        vm.prank(address(joe));
        raftToken.mint{value: 21 ether}(amount);

        // Joe can still mint up to the maximum amount at one time.
        assert(joe.try_mint{value: 20 ether}(address(raftToken), 20));
    }

    /// @notice Test that an attempt to mint more than the total supply reverts.
    function test_nft_mint_TotalSupply() public {
        // Enable public sale
        raftToken.setPublicSaleState(true);

        // Mint total supply worth of tokens
        uint256 price = raftToken.MAX_RAFTS() * raftToken.RAFT_PRICE();
        uint256 totalBuys = raftToken.TOTAL_RAFTS() / raftToken.MAX_RAFTS();
        for(uint i = 0; i < totalBuys; i++) {
            Actor user = new Actor();
            assert(user.try_mint{value: price}(address(raftToken), 20));
        }

        // Verify that current token id is equal to total supply.
        assertEq(raftToken.currentTokenId(), raftToken.TOTAL_RAFTS());

        // Attempt to mint more than total supply.
        vm.expectRevert(bytes("NFT.sol::mint() Amount requested exceeds total supply"));
        vm.prank(address(joe));
        raftToken.mint{value: 1 ether}(1);

        // Verify that the current token id is unchanged after failed mint.
        assertEq(raftToken.currentTokenId(), raftToken.TOTAL_RAFTS());
    }

    /// @notice Test that minting more tokens than the maximum overall purchase reverts.
    function test_nft_mint_MaxRaftPurchase() public {
        // Enable public sale.
        raftToken.setPublicSaleState(true);

        // Joe can mint 20 tokens which is the maximum number of tokens mintable per address.
        assert(joe.try_mint{value: 20 ether}(address(raftToken), 20));
        
        // Joe cannot mint more than the maximum amount at one time.
        vm.expectRevert(bytes( "NFT.sol::mint() Amount requested exceeds maximum tokens per address (20)"));
        vm.prank(address(joe));
        raftToken.mint{value: 1 ether}(1);
    }

    /// @notice Test that minting with unequal value reverts.
    function test_nft_mint_RaftPrice() public {
        // Enable public sale
        raftToken.setPublicSaleState(true);

        // Joe cannot mint for less than the token price
        vm.expectRevert(bytes("NFT.sol::mint() Message value must be equal to the price of token(s)"));
        vm.startPrank(address(joe));
        raftToken.mint{value: .9 ether}(1);
        assertEq(raftToken.balanceOf(address(joe)), 0);

        // Joe cannot mint multiple tokens with msg.value less than the token price * number of tokens
        assert(!joe.try_mint{value: 1 ether}(address(raftToken), 2));
        assertEq(raftToken.balanceOf(address(joe)), 0);

        // Joe cannot mint less tokens than the msg.value greater than token price * number of tokens
        assert(!joe.try_mint{value: 5 ether}(address(raftToken), 4));
        assertEq(raftToken.balanceOf(address(joe)), 0);
    }

    // --- ownedTokens() ---

    /// @notice Test to estimate gas costs for ownedTokens view function for a wallet that owns
    /// random number of sequential token ids at random in the range of possible token ids
    function test_nft_ownedTokens_Fuzzing(uint256 mintAmount, uint256 startingId) public {
        // Constrain fuzzer input
        mintAmount = bound(mintAmount, 1, 20);
        startingId = bound(startingId, 1, raftToken.TOTAL_RAFTS()-mintAmount);
        raftToken.setPublicSaleState(true);

        // Mint all token ids up to the random starting token id
        mintTokens(address(raftToken), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        uint256 value = mintAmount * WAD;
        assert(joe.try_mint{value: value}(address(raftToken), mintAmount));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet
    /// that owns sequential token ids at the start of the range of possible token ids.
    function test_nft_ownedTokens_SequentialLow() public {
        uint256 startingId = 700;
        uint256 mintAmount = 17;
        raftToken.setPublicSaleState(true);

        // Mint all tokens up to the starting token id
        mintTokens(address(raftToken), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        assert(joe.try_mint{value: 17 ether}(address(raftToken), mintAmount));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet
    /// that owns sequential token ids at the height of the range of possible token ids.
    function test_nft_ownedTokens_SequentialHigh() public {
        uint256 mintAmount = 17;
        uint256 startingId = 9000;
        raftToken.setPublicSaleState(true);

        // Mint out all tokens up to starting token id
        mintTokens(address(raftToken), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = raftToken.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        assert(joe.try_mint{value: 17 ether}(address(raftToken), mintAmount));
        assertEq(raftToken.balanceOf(address(joe)), mintAmount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = raftToken.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokens = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        uint256 index = 0;
        for(firstTokenId; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[index++], firstTokenId);
            assertEq(raftToken.ownerOf(firstTokenId), address(joe));
        }

        // emit log_array(tokens);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 0.5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_SporadicSmall() public {
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own.
        uint16[50] memory ownedIds = [268, 435, 656, 767, 1186, 1197, 1229, 1655, 1673, 1897, 1950, 2230, 2332, 2489, 2497, 2981, 3069, 3524, 3603, 3644, 3876, 4075, 4124, 4144, 4375, 4393, 4587, 4857, 5274, 5436, 5565, 5663, 6206, 6497, 6552, 7150, 7197, 7321, 7348, 7697, 7736, 8236, 8496, 8563, 8586, 8601, 9311, 9324, 9458, 9846];
        uint256 total = raftToken.TOTAL_RAFTS(); 
        uint256 index = 0;

        // Mint out all token ids 1-10000
        mintTokens(address(raftToken), total);

        // Transfer any "owned" token ids to Joe
        for(uint256 id = 1; id <= total; ++id) {                
            if(id == ownedIds[index]) {
                address from = raftToken.ownerOf(id);
                vm.prank(from);
                raftToken.transferFrom(from, address(joe), id);
                if(++index == ownedIds.length) {
                    break;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // emit log_array(tokenIds);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 2% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_SporadicMedium() public {
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own
        uint16[200] memory ownedIds = [46, 214, 248, 258, 260, 273, 287, 344, 412, 617, 620, 691, 696, 758, 777, 901, 1020, 1021, 1093, 1114, 1144, 1151, 1165, 1191, 1225, 1257, 1288, 1312, 1397, 1409, 1430, 1444, 1447, 1614, 1627, 1718, 1940, 2166, 2232, 2313, 2321, 2371, 2374, 2380, 2382, 2407, 2446, 2500, 2524, 2584, 2615, 2647, 2662, 2751, 2816, 2943, 2973, 2977, 3041, 3048, 3132, 3141, 3147, 3357, 3397, 3405, 3480, 3485, 3587, 3632, 3743, 3748, 3766, 3824, 4068, 4157, 4197, 4227, 4255, 4295, 4305, 4309, 4464, 4538, 4564, 4576, 4577, 4603, 4610, 4657, 4659, 4695, 4722, 4732, 4760, 4803, 4854, 4889, 4900, 4949, 5033, 5067, 5074, 5087, 5179, 5247, 5305, 5411, 5420, 5625, 5737, 5741, 5745, 5753, 5778, 5839, 5959, 6027, 6029, 6258, 6281, 6445, 6523, 6563, 6633, 6686, 6796, 6824, 6840, 6989, 7026, 7032, 7104, 7151, 7171, 7204, 7320, 7325, 7335, 7411, 7412, 7435, 7485, 7557, 7588, 7654, 7655, 7667, 7668, 7689, 7758, 7762, 7773, 7774, 7786, 7831, 7924, 7948, 7975, 7991, 8194, 8215, 8218, 8222, 8239, 8252, 8279, 8335, 8344, 8359, 8429, 8444, 8453, 8458, 8684, 8742, 8785, 8789, 8827, 8897, 9022, 9221, 9246, 9249, 9300, 9338, 9347, 9370, 9437, 9509, 9536, 9629, 9648, 9664, 9679, 9693, 9756, 9797, 9876, 9961];
        uint256 index = 0;
        uint256 total = raftToken.TOTAL_RAFTS();

        // Mint out all token ids 1-10000
        mintTokens(address(raftToken), total);

        // Transfer any "owned" token ids to Joe
        for(uint256 id = 1; id <= total; ++id) {                
            if(id == ownedIds[index]) {
                address from = raftToken.ownerOf(id);
                vm.prank(from);
                raftToken.transferFrom(from, address(joe), id);
                if(++index == ownedIds.length) {
                    break;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // emit log_array(tokenIds);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for a wallet that owns
    /// 5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_SporadicLarge() public {
        raftToken.setPublicSaleState(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own
        uint16[500] memory ownedIds = [12, 15, 29, 37, 43, 50, 88, 94, 100, 107, 109, 137, 164, 177, 186, 213, 281, 295, 296, 350, 352, 361, 379, 389, 420, 441, 443, 461, 506, 516, 551, 579, 584, 625, 633, 643, 653, 668, 682, 702, 708, 728, 763, 777, 783, 794, 836, 882, 890, 897, 906, 920, 922, 933, 945, 975, 1004, 1016, 1018, 1030, 1037, 1042, 1053, 1084, 1085, 1090, 1094, 1122, 1146, 1154, 1160, 1190, 1201, 1204, 1212, 1221, 1224, 1231, 1269, 1280, 1284, 1317, 1330, 1363, 1379, 1384, 1390, 1400, 1418, 1468, 1475, 1477, 1478, 1485, 1504, 1514, 1541, 1551, 1568, 1599, 1603, 1606, 1620, 1628, 1651, 1652, 1663, 1715, 1721, 1744, 1759, 1776, 1797, 1837, 1847, 1875, 1879, 1891, 1917, 1919, 1957, 1973, 2015, 2048, 2052, 2065, 2069, 2074, 2076, 2102, 2104, 2112, 2114, 2118, 2151, 2183, 2194, 2205, 2209, 2219, 2251, 2262, 2279, 2288, 2307, 2369, 2380, 2383, 2434, 2451, 2499, 2572, 2581, 2586, 2616, 2617, 2628, 2642, 2643, 2649, 2651, 2659, 2666, 2722, 2731, 2733, 2748, 2762, 2792, 2797, 2807, 2814, 2848, 2878, 2894, 2914, 2924, 2929, 2933, 2965, 2977, 2978, 2986, 3107, 3117, 3147, 3158, 3175, 3206, 3213, 3229, 3259, 3309, 3331, 3349, 3407, 3418, 3439, 3445, 3455, 3469, 3483, 3488, 3525, 3530, 3594, 3607, 3628, 3663, 3687, 3699, 3705, 3721, 3742, 3767, 3769, 3775, 3790, 3839, 3861, 3866, 3906, 3911, 3933, 3957, 3981, 3988, 4008, 4016, 4045, 4057, 4100, 4128, 4147, 4149, 4172, 4188, 4211, 4214, 4228, 4261, 4291, 4311, 4336, 4340, 4356, 4366, 4371, 4398, 4407, 4412, 4429, 4436, 4454, 4456, 4462, 4521, 4592, 4609, 4610, 4614, 4648, 4650, 4663, 4730, 4744, 4785, 4787, 4794, 4823, 4827, 4831, 4853, 4891, 4894, 4895, 4897, 4914, 4933, 4969, 4983, 5001, 5005, 5016, 5034, 5073, 5081, 5100, 5109, 5111, 5114, 5117, 5132, 5221, 5258, 5265, 5272, 5286, 5314, 5316, 5373, 5376, 5381, 5389, 5393, 5397, 5500, 5502, 5551, 5587, 5589, 5611, 5618, 5623, 5634, 5643, 5677, 5700, 5732, 5779, 5784, 5809, 5833, 5843, 5862, 5887, 5905, 5951, 5972, 5991, 6016, 6110, 6122, 6126, 6132, 6147, 6152, 6154, 6177, 6184, 6201, 6202, 6228, 6266, 6267, 6283, 6285, 6298, 6324, 6329, 6344, 6360, 6376, 6404, 6423, 6529, 6547, 6550, 6587, 6588, 6649, 6650, 6675, 6728, 6730, 6731, 6742, 6748, 6766, 6782, 6784, 6890, 6893, 6900, 6902, 6927, 6938, 6944, 6972, 6989, 7019, 7031, 7042, 7072, 7100, 7110, 7126, 7149, 7163, 7174, 7196, 7203, 7214, 7239, 7282, 7299, 7315, 7320, 7330, 7346, 7369, 7441, 7444, 7459, 7465, 7515, 7517, 7539, 7553, 7608, 7631, 7640, 7647, 7657, 7664, 7769, 7801, 7815, 7838, 7848, 7855, 7871, 7874, 7918, 7977, 8013, 8038, 8076, 8077, 8127, 8133, 8204, 8288, 8294, 8300, 8321, 8346, 8348, 8360, 8401, 8443, 8484, 8485, 8535, 8554, 8582, 8584, 8599, 8601, 8649, 8721, 8736, 8754, 8801, 8913, 8958, 8968, 8980, 8982, 8987, 8992, 8994, 9002, 9040, 9145, 9188, 9190, 9201, 9238, 9253, 9254, 9271, 9313, 9356, 9380, 9424, 9450, 9542, 9550, 9560, 9592, 9596, 9598, 9657, 9663, 9716, 9731, 9797, 9809, 9850, 9852, 9861, 9890, 9893, 9910, 9919, 9933, 9937, 9985, 9993];
        uint256 index = 0;
        uint256 total = raftToken.TOTAL_RAFTS(); 

        // Mint out all token ids 1-10000
        mintTokens(address(raftToken), total);

        // Transfer any "owned" token ids to Joe
        for(uint256 id = 1; id <= total; ++id) {                
            if(id == ownedIds[index]) {
                address from = raftToken.ownerOf(id);
                vm.prank(from);
                raftToken.transferFrom(from, address(joe), id);
                if(++index == ownedIds.length) {
                    break;
                }
            }
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        vm.prank(address(joe));
        uint256[] memory tokenIds = raftToken.ownedTokens();
        assertEq(raftToken.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 i = 0; i < ownedIds.length; i++) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(raftToken.ownerOf(ownedIds[i]), address(joe));
        }

        // emit log_array(tokenIds);
    }


    // ----------------
    // Owner Functions
    // ----------------

    /// @notice Test that the onlyOwner modifier reverts unless the call is from the owner.
    function test_nft_OnlyOwner() public {
        // Transfer ownership to the developer actor
        raftToken.transferOwnership(address(dev));

        // Joe cannot call functions with onlyOwner modifier
        assert(!joe.try_setBaseURI(address(raftToken), "ipfs::/RevealedURI/"));
        assert(!joe.try_setPublicSaleState(address(raftToken), true));
        assert(!joe.try_setWhitelistSaleState(address(raftToken), true));
        
        // Developer can call function with onlyOwner modifier
        assert(dev.try_setBaseURI(address(raftToken), "ipfs::/RevealedURI/"));
        assert(dev.try_setPublicSaleState(address(raftToken), true));
        assert(dev.try_setWhitelistSaleState(address(raftToken), true));
    }

    // --- setBaseURI() ---

    /// @notice Test that the base URI can be set to a new address for revealing.
    function test_nft_setBaseURI_Set() public {
        // Verify URI state reflects deployment
        assertEq(raftToken.baseURI(), "");

        // Owner can set the base URI to a new address
        raftToken.setBaseURI("ipfs::/RevealedURI/");

        // Verify URI state reflects changes
        assertEq(raftToken.baseURI(), "ipfs::/RevealedURI/");
    }

    // --- setPublicSaleState() ---

    /// @notice Test that the public sale state can be set to begin public mint.
    function test_nft_setPublicSaleState_Set() public {
        // Verify public sale state reflects deployment
        assert(!raftToken.publicSaleActive());

        // Owner can update the public sale state from false to true
        raftToken.setPublicSaleState(true);

        // Verify public sale state reflects changes
        assert(raftToken.publicSaleActive());
    }

    // --- setWhitelistSaleState() ---

    /// @notice Test that the whitelist sale state can be set to begin whitelist mint.
    function test_nft_setWhitelistSaleState_Set() public {
        // Verify whitelist sale state reflects deployment
        assert(!raftToken.whitelistSaleActive());

        // Owner can update the whitelist sale state from false to true
        raftToken.setWhitelistSaleState(true);

        // Verify whitelist sale state reflects changes
        assert(raftToken.whitelistSaleActive());
    }

    // --- updateCircleAccount() ---

    /// @notice Test that the circle account address can be updated to a new address.
    function test_nft_updateCircleAccount_Updated() public {
        // Verify circle account state reflects deployment
        assertEq(raftToken.circleAccount(), crc);
        
        // Owner can update circle account to a new address
        address newCrc = makeAddr("New Circle Account");
        raftToken.updateCircleAccount(newCrc);

        // Verify circle account reflects changes
        assertEq(raftToken.circleAccount(), newCrc);
    }

    /// @notice Test that updating the circle account to the zero address reverts.
    function test_nft_updateCircleAccount_ZeroAddress() public {
        // Verify circle account state reflects deployment
        assertEq(raftToken.circleAccount(), crc);

        // Owner cannot update circle account to the zero address
        vm.expectRevert(bytes("NFT.sol::updateCircleAccount() Address cannot be zero address"));
        raftToken.updateCircleAccount(address(0));

        // Verify circle account is unchanged
        assertEq(raftToken.circleAccount(), crc);
    }

    // --- updateMultiSig() ---

    /// @notice Test that the multisig wallet address can be updated to a new address.
    function test_nft_updateMultiSig_Updated() public {
        // Verify multisig wallet state reflects deployment
        assertEq(raftToken.multiSig(), sig);
        
        // Owner can update multisig to a new address
        address newSig = makeAddr("New MultiSig");
        raftToken.updateMultiSig(newSig);

        // Verify multisig wallet reflects changes
        assertEq(raftToken.multiSig(), newSig);
    }

    /// @notice Test that updating the multisig wallet to the zero address reverts.
    function test_nft_updateMultiSig_ZeroAddress() public {
        // Verify multisig wallet state reflects deployment
        assertEq(raftToken.multiSig(), sig);

        // Owner cannot update multisig wallet to the zero address
        vm.expectRevert(bytes("NFT.sol::updateMultiSig() Address cannot be zero address"));
        raftToken.updateMultiSig(address(0));

        // Verify multisig wallet is unchanged
        assertEq(raftToken.multiSig(), sig);
    }
    
    // --- withdraw() ---
    /// @dev Withdraw test cases must be run with an appropriate rpc url!

    /// @notice Test that the balance of the contract can be withdrawn to circle account.
    function test_nft_withdraw_Basic() public {
        assertEq(crc.balance, 0);
        assertEq(address(raftToken).balance, 0);

        // Simulate minting out by giving NFT contract an Ether balance of TOTAL_RAFTS * RAFT_PRICE
        uint256 totalBalance = raftToken.TOTAL_RAFTS() * raftToken.RAFT_PRICE();
        vm.deal(address(raftToken), totalBalance);
        assertEq(address(raftToken).balance, totalBalance);

        // Withdraw NFT contract balance after minting out to circle account
        raftToken.withdraw();
        assertEq(crc.balance, totalBalance);
        assertEq(address(raftToken).balance, 0);
    }

    /// @notice Test that withdrawal attempts when the contract balance is zero revert.
    function test_nft_withdraw_InsufficientBalance() public {
        assertEq(crc.balance, 0);
        assertEq(address(raftToken).balance, 0);

        // Owner cannot withdraw from the contract unless the contract contains Ether.
        vm.expectRevert(bytes("NFT.sol::withdraw() Insufficient ETH balance"));
        raftToken.withdraw();
        assertEq(crc.balance, 0);
        assertEq(address(raftToken).balance, 0);
    }

    /// @notice Test that withdrawal attempts revert when the recipient reverts on transfer.
    function test_nft_withdraw_BadRecipient() public {
        // Actor is a contract that cannot receive Ether on calls
        Actor newCrc = new Actor();
        assertEq(address(newCrc).balance, 0);
        assertEq(address(raftToken).balance, 0);
        raftToken.updateCircleAccount(address(newCrc));

        // Simulate minting out by giving NFT contract an Ether balance of TOTAL_RAFTS * RAFT_PRICE
        uint256 totalBalance = raftToken.TOTAL_RAFTS() * raftToken.RAFT_PRICE();
        vm.deal(address(raftToken), totalBalance);
        assertEq(address(raftToken).balance, totalBalance);

        // Owner cannot withdraw to a circle account if the circle account cannot accept Ether
        vm.expectRevert(bytes("NFT.sol::withdraw() Unable to withdraw funds, recipient may have reverted"));
        raftToken.withdraw();
        assertEq(crc.balance, 0);
        assertEq(address(raftToken).balance, totalBalance);
    }

    // --- withdrawERC20() ---
    /// @dev Withdraw test cases must be run with an appropriate rpc url!

    /// @notice Test that ERC20 token amounts can be withdrawn from NFT contract to MultiSig.
    /// @dev vm.deal() used elsewhere and the deal() function used here are different!
    function test_nft_withdrawERC20_Fuzzing(uint256 amount) public {
        amount = bound(amount, 1, 100000 * USD);

        // Use USDC as an example ERC20 token
        IERC20 token = IERC20(USDC);
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(raftToken)), 0);

        // Simulate NFT contract receiving an amount of USDC
        deal(address(USDC), address(raftToken), amount);
        assertEq(token.balanceOf(address(raftToken)), amount);

        // Owner can withdraw NFT contract ERC20 balance to multisig wallet
        raftToken.withdrawERC20(USDC);
        assertEq(token.balanceOf(sig), amount);
        assertEq(token.balanceOf(address(raftToken)), 0);
    }

    /// @notice Test that ERC20 withdrawl attempts from the zero address revert.
    function test_nft_withdrawERC20_ZeroAddress() public {
        // Owner cannot call the transfer function on the zero address
        vm.expectRevert(bytes("NFT.sol::withdrawERC20() Contract address cannot be zero address"));
        raftToken.withdrawERC20(address(0));
    }

    /// @notice Test that ERC20 withdrawl attempts when the contract balance is zero revert.
    function test_nft_withdrawERC20_InsufficientBalance() public {
        // Use USDC as an example ERC20 token
        IERC20 token = IERC20(USDC);
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(raftToken)), 0);

        // Owner cannot withdraw NFT contract ERC20 balance when the balance is zero
        vm.expectRevert(bytes("NFT.sol::withdrawERC20() Insufficient token balance"));
        raftToken.withdrawERC20(USDC);
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(raftToken)), 0);
    }

}