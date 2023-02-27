// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Utility } from "./utils/Utility.sol";
import { Actor } from "./utils/Actor.sol";
import { VRFCoordinatorV2Mock } from "./utils/VRFCoordinatorV2Mock.sol";
import { Merkle } from "./utils/Merkle.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { NFT } from "../src/NFT.sol";

/// @notice Unit tests for NFT contract.
/// @author Andrew Thomas
contract NFTTest is Utility {
    // State variable for contracts.
    NFT internal nftContract;
    VRFCoordinatorV2Mock internal vrfCoordinator;
    Merkle internal merkle;

    // State variables for whitelist.
    Actor[] internal whitelist;
    bytes32[] internal tree;
    bytes32 internal root;

    // State variables for VRF.
    uint256[] internal entropy = [uint256(uint160(address(this)))];
    uint64 internal subId;

    function setUp() public {
        createActors();

        // Initialize Merkle contract for constructing Merkle tree roots and proofs
        merkle = new Merkle();
        // Assign array of 20 whitelisted addresses + 20 bytes32 hashed addresses to construct merkle tree
        (whitelist, tree) = createWhitelist(20);
        // Assign root of merkle tree constructed with Murky helper contract
        root = merkle.getRoot(tree);

        // Initialize mock VRF coordinator contract with subscription and funding
        vrfCoordinator = new VRFCoordinatorV2Mock(100000, 100000);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 100 ether);

        // Initialize NFT contract
        nftContract = new NFT(
            "RaftToken",                        // Name of collection
            "RT",                               // Symbol of collection
            "ipfs::/Unrevealed/",               // Unrevealed URI
            root,                               // Whitelist root
            address(vrfCoordinator),            // Mock VRF coordinator
            sig                                 // Multi-signature wallet
        );

        // Update subscription and add the NFT contract as a consumer
        nftContract.updateSubId(subId);
        vrfCoordinator.addConsumer(subId, address(nftContract));
    }


    // --------------
    // Deployed State
    // --------------

    /// @notice Test constants and values assigned in the constructor once deployed.
    function test_nft_DeployedState() public {
        assertEq(nftContract.symbol(), "RT");
        assertEq(nftContract.name(), "RaftToken");
        assertEq(nftContract.unrevealedURI(), "ipfs::/Unrevealed/");
        assertEq(nftContract.whitelistRoot(), root);
        assertEq(address(nftContract.vrfCoordinatorV2()), address(vrfCoordinator));
        assertEq(nftContract.multiSig(), sig);

        assertEq(nftContract.currentTokenId(), 0);
        assertEq(nftContract.TOTAL_RAFTS(), 10000);
        assertEq(nftContract.RAFT_PRICE(), 1 ether);
        assertEq(nftContract.MAX_RAFTS(), 20);
        assertEq(nftContract.baseURI(), "");
        assertEq(nftContract.entropy(), 0);
        assertEq(nftContract.subId(), subId);
        assertEq(nftContract.KEY_HASH(), 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15);
        assertEq(nftContract.CALLBACK_GAS_LIMIT(), 50_000);
        assertEq(nftContract.NUM_WORDS(), 1);
        assertEq(nftContract.REQUEST_CONFIRMATIONS(), 20);

        assert(!nftContract.fulfilled());
        assert(!nftContract.finalized());
        assert(!nftContract.publicMint());
        assert(!nftContract.whitelistMint());
        assert(!nftContract.shuffled());
    }

    /// @notice Test that the result of a random value modulo a range is within that range.
    function testFuzz_nft_ModuloRangeRestriction(uint256 currentTokenId, uint256 vrfRandomWord) public {
        currentTokenId = bound(currentTokenId, 1, 10000);
        uint256 result = vrfRandomWord % currentTokenId + 1;

        // 1 <= result <= 10000
        assertGe(result, 1);
        assertLe(result, 10000);
    }


    // ----------------
    // Public Functions
    // ----------------

    // --- tokenURI() ---

    /// @notice Test that token URIs returned use unrevealed URI when the base URI is not set.
    function test_nft_tokenURI_Unrevealed() public {
        // Verify base and unrevealed URIs are initialized properly
        assertEq(nftContract.baseURI(), "");
        assertEq(nftContract.unrevealedURI(), "ipfs::/Unrevealed/");

        // Verify that the unrevealed URI is returned since base URI has not been set
        assertEq(nftContract.tokenURI(1), "ipfs::/Unrevealed/1.json");
    }

    /// @notice Test that token URIs returned use the base URI once the base URI is set.
    function test_nft_tokenURI_Revealed() public {
        // Verify the token URI returned for token id 420 is the unrevealed URI
        assertEq(nftContract.tokenURI(420), "ipfs::/Unrevealed/420.json");

        // Owner sets the base URI once token levels are finalized
        nftContract.setBaseURI("ipfs::/Revealed/");

        // Verify URI updates are reflected in state and functions
        assertEq(nftContract.baseURI(), "ipfs::/Revealed/");
        assertEq(nftContract.tokenURI(420), "ipfs::/Revealed/420.json");
    }


    // ------------------
    // External Functions
    // ------------------

    // --- levelOf() ---

    /// @notice Test that attempts to get the level of token ids not minted revert.
    function testFuzz_nft_levelOf_NotMinted(uint256 tokenId) public {
        vm.expectRevert("NOT_MINTED");
        nftContract.levelOf(tokenId);
    }

    /// @notice Test that minted token id levels are correct before shuffling.
    function test_nft_levelOf_TotalSupply() public {
        nftContract.updatePublicMint(true);

        // Mint out all tokens
        mintTokens(address(nftContract), nftContract.TOTAL_RAFTS());

        // Verify shuffle state
        assert(!nftContract.shuffled());

        // Verify that token id levels are equal for every token id
        for(uint256 tokenId = nftContract.currentTokenId(); tokenId > 0; --tokenId) {
            assertEq(tokenId, nftContract.levelOf(tokenId));
        }
    }

    // ---- mint() / mintWhitelist() ----

    /// @notice Test that a whitelisted address with a valid proof can mint.
    function test_nft_mint_AddressIsWhitelisted() public {
        // Enable whitelist mint
        nftContract.updateWhitelistMint(true);

        // Obtain proof using Murky contract
        bytes32[] memory validProof = merkle.getProof(tree, 0);

        // Attempt to mint via whitelist using valid proof
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(nftContract), 1, validProof));

        // Verify token id, ownership, and balance state changes
        assertEq(nftContract.currentTokenId(), 1);
        assertEq(nftContract.balanceOf(address(whitelist[0])), 1);
        assertEq(nftContract.ownerOf(1), address(whitelist[0]));
    }

    /// @notice Test that minting while whitelist mint active reverts.
    function test_nft_mint_AddressNotWhitelisted() public {
        nftContract.updateWhitelistMint(true);

        // Verify state reflects active mints
        assert(!nftContract.publicMint());
        assert(nftContract.whitelistMint());

        // Joe cannot mint via public mint 
        vm.startPrank(address(joe));
        vm.expectRevert("NFT.sol::mint() Public mint is not active");
        nftContract.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint
        vm.expectRevert("NFT.sol::mintWhitelist() Address not whitelisted");
        bytes32[] memory invalidProof;
        nftContract.mintWhitelist{value: 1 ether}(1, invalidProof);
        vm.stopPrank();
    }

    /// @notice Test that only whitelisted addresses with valid proofs can mint during whitelist mint.
    function test_nft_mint_WhitelistedValidProof() public {
        // Enable whitelist mint
        nftContract.updateWhitelistMint(true);

        // Verify state reflects active mints
        assert(!nftContract.publicMint());
        assert(nftContract.whitelistMint());

        // Mint whitelisted users 20 tokens with valid proofs and verify 20 * 20 = 400 tokens minted
        for(uint j = 0; j < 20; ++j) {
            bytes32[] memory proof = merkle.getProof(tree, j);
            assert(whitelist[j].try_mintWhitelist{value: 20 ether}(address(nftContract), 20, proof));
            assertEq(nftContract.balanceOf(address(whitelist[j])), 20);
        }
        assertEq(nftContract.currentTokenId(), 20 * 20);

        // Joe cannot mint without public mint active
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Public mint is not active");
        nftContract.mint{value: 20 ether}(20);
        
        // Joe cannot mint during whitelist mint even with a "valid" proof
        vm.prank(address(joe));
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        vm.expectRevert("NFT.sol::mintWhitelist() Address not whitelisted");
        nftContract.mintWhitelist{value: 20 ether}(20, validProof);
    }

    /// @notice Test that minting with whitelisted address and invalid proof reverts.
    function test_nft_mint_WhitelistedInvalidProof() public {
        // Enable whitelist mint
        nftContract.updateWhitelistMint(true);

        // Obtain proof using Murky contract
        bytes32[] memory invalidProof = merkle.getProof(tree, 1);

        // Attempt to mint via whitelist using invalid proof
        vm.prank(address(whitelist[0]));
        vm.expectRevert("NFT.sol::mintWhitelist() Address not whitelisted");
        nftContract.mintWhitelist{value: 1 ether}(1, invalidProof);
    }
    
    /// @notice Test active mint restrictions for whitelist and public mint.
    function test_nft_mint_BothMintsActive() public{
        nftContract.updateWhitelistMint(true);
        nftContract.updatePublicMint(true);
        
        // Verify balance for public and whitelist minters as well as mint state
        assert(nftContract.publicMint());
        assert(nftContract.whitelistMint());
        assertEq(nftContract.currentTokenId(), 0);
        assertEq(nftContract.balanceOf(address(joe)), 0);
        assertEq(nftContract.balanceOf(address(whitelist[0])), 0);

        // Joe can mint tokens via public
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));

        // Whitelisted user 0 can mint tokens via whitelist (cheaper to use public)
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(nftContract), 1, validProof));

        // Verify balance state changes for public and whitelist minters
        assertEq(nftContract.balanceOf(address(joe)), 1);
        assertEq(nftContract.balanceOf(address(whitelist[0])), 1);
        assertEq(nftContract.currentTokenId(), 2);
    }

    /// @notice Test that minting while whitelist and public mint not active reverts.
    function test_nft_mint_NoActiveMints() public {
        // Verify state reflects no active mints
        assert(!nftContract.publicMint());
        assert(!nftContract.whitelistMint());

        // Joe cannot mint via public mint
        vm.startPrank(address(joe));
        vm.expectRevert("NFT.sol::mint() Public mint is not active");
        nftContract.mint{value: 1 ether}(1);

        // Joe cannot mint via whitelist mint
        bytes32[] memory invalidProof;
        vm.expectRevert("NFT.sol::mintWhitelist() Whitelist mint is not active");
        nftContract.mintWhitelist{value: 1 ether}(1, invalidProof);
        vm.stopPrank();
    }

    /// @notice Test that minting yields the proper token quantity and token ids.
    function test_nft_mint_PublicBasic() public {
        nftContract.updatePublicMint(true);

        // Ensure currentTokenId starts at 0
        assertEq(nftContract.currentTokenId(), 0);

        // Joe can mint one token via public
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));

        // currentTokenId is incremented to 1, the most recently minted token id
        assertEq(nftContract.currentTokenId(), 1);
        // Joe owns token with id 1
        assertEq(nftContract.ownerOf(1), address(joe));
        // Joe has a balance of 1 token
        assertEq(nftContract.balanceOf(address(joe)), 1);
    }

    /// @notice Test that amount values greater than maximum amount cause minting to revert.
    function test_nft_mint_MaxAmount() public {
        nftContract.updatePublicMint(true);

        // Assign amount of tokens to maximum value of parameter type
        uint256 amount = type(uint256).max;

        // Ensure that the current token id begins at 0
        assertEq(nftContract.currentTokenId(), 0);
        // Ensure that the current token id after minting 90 tokens is 90
        mintTokens(address(nftContract), 90);
        assertEq(nftContract.currentTokenId(), 90);
        
        // Joe cannot mint more than the maximum amount at one time
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Amount requested exceeds maximum");
        nftContract.mint{value: 21 ether}(amount);

        // Joe can still mint up to the maximum amount at one time
        assert(joe.try_mint{value: 20 ether}(address(nftContract), 20));
    }

    // function test_nft_mint_Overflow() public {
    //     nftContract.updatePublicMint(true);
    //     mintTokens(address(nftContract), 1);
    //     vm.deal(address(joe), type(uint256).max-1);
    //     vm.prank(address(joe));
    //     nftContract.mint{value: type(uint256).max-1}(type(uint256).max-1);
    // }

    /// @notice Test that an attempt to mint more than the total supply reverts.
    function test_nft_mint_TotalSupply() public {
        // Enable public mint
        nftContract.updatePublicMint(true);

        // Mint total supply worth of tokens
        uint256 price = nftContract.MAX_RAFTS() * nftContract.RAFT_PRICE();
        uint256 total = nftContract.TOTAL_RAFTS() / nftContract.MAX_RAFTS();
        for(uint256 i = 0; i < total; ++i) {
            Actor user = new Actor();
            assert(user.try_mint{value: price}(address(nftContract), 20));
        }

        // Verify that current token id is equal to total supply
        assertEq(nftContract.currentTokenId(), nftContract.TOTAL_RAFTS());

        // Joe cannot mint more than the total supply
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Amount requested exceeds total supply");
        nftContract.mint{value: 1 ether}(1);
    }

    /// @notice Test that minting more tokens than the maximum amount reverts.
    function test_nft_mint_MaxRaftMintable() public {
        nftContract.updatePublicMint(true);

        // Joe can mint 20 tokens which is the maximum number of tokens mintable per address
        assert(joe.try_mint{value: 20 ether}(address(nftContract), 20));
        
        // Joe cannot mint more than the maximum amount at one time
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Amount requested exceeds maximum tokens per address");
        nftContract.mint{value: 1 ether}(1);
    }

    /// @notice Test that minting with unequal value reverts.
    function test_nft_mint_RaftPrice() public {
        nftContract.updatePublicMint(true);

        // Joe cannot mint for less than the token price
        vm.startPrank(address(joe));
        vm.expectRevert("NFT.sol::mint() Message value must be equal to the price of token(s)");
        nftContract.mint{value: .99999 ether}(1);

        // Joe cannot mint multiple tokens with msg.value less than the token price * number of tokens
        vm.expectRevert("NFT.sol::mint() Message value must be equal to the price of token(s)");
        nftContract.mint{value: 1 ether}(2);

        // Joe cannot mint less tokens than the msg.value greater than token price * number of tokens
        vm.expectRevert("NFT.sol::mint() Message value must be equal to the price of token(s)");
        nftContract.mint{value: 5 ether}(4);
        vm.stopPrank();

        assertEq(nftContract.balanceOf(address(joe)), 0);
    }

    /// @notice Test that minting via public and whitelist mint assigns levels correctly.
    function test_nft_mint_LevelsAssigned() public {
        nftContract.updatePublicMint(true);
        nftContract.updateWhitelistMint(true);

        // Verify no token ids have levels
        vm.expectRevert("NOT_MINTED");
        nftContract.levelOf(1);

        // Whitelisted user 0 can mint 10 tokens and token ids 1-10 are added to tokens
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        assert(whitelist[0].try_mintWhitelist{value: 10 ether}(address(nftContract), 10, validProof));
        assertEq(nftContract.currentTokenId(), 10);

        // Joe can mint 10 more tokens and token ids 11-20 are added to tokens
        assert(joe.try_mint{value: 10 ether}(address(nftContract), 10));
        assertEq(nftContract.currentTokenId(), 20);

        // Verify levels from the last token minted to the first token minted
        for(uint256 tokenId = nftContract.currentTokenId(); tokenId > 0; --tokenId) {
            assertEq(nftContract.levelOf(tokenId), tokenId);
        }
    }

    /// @notice Test that levels are assigned for any amount minted between 0 and total supply.
    /// @dev Initially the level of a token is the token's id.
    function testFuzz_nft_mint_LevelsAssigned(uint256 amount) public {
        amount = bound(amount, 0, nftContract.TOTAL_RAFTS());
        nftContract.updatePublicMint(true);

        // Verify no levels have been assigned yet
        vm.expectRevert("NOT_MINTED");
        nftContract.levelOf(1);

        // Mint an amount of tokens
        mintTokens(address(nftContract), amount);

        // After minting an amount of tokens, currentTokenId should equal amount
        assertEq(nftContract.currentTokenId(), amount);

        // Verify the level of each token id from amount down to one
        for(uint256 tokenId = amount; tokenId > 0; --tokenId) {
            assertEq(nftContract.levelOf(tokenId), tokenId);
        }
    }

    /// @notice Test that minting via public and whitelist after mint is finalized reverts.
    function test_nft_mint_MintFinalized() public {
        nftContract.updatePublicMint(true);
        nftContract.updateWhitelistMint(true);

        // Joe can mint one token via public mint
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));

        // Whitelisted user 0 can mint one token via whitelist mint
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(nftContract), 1, validProof));

        // Finalize mint to end public and whitelist mint
        nftContract.finalizeMint();

        // Joe cannot mint once mint is finalized
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Public mint is not active");
        nftContract.mint{value: 1 ether}(1);

        // Whitelisted user 0 cannot mint once mint is finalized
        vm.prank(address(whitelist[0]));
        vm.expectRevert("NFT.sol::mintWhitelist() Whitelist mint is not active");
        nftContract.mintWhitelist{value: 1 ether}(1, validProof);
    }

    // --- ownedTokens() ---

    /// @notice Test validity and gas costs of ownedTokens view function for an address
    /// owning a random number of sequential token ids in the range of possible token ids.
    function testFuzz_nft_ownedTokens_Sequential(uint256 amount, uint256 startingId) public {
        amount = bound(amount, 1, 20);
        startingId = bound(startingId, 1, nftContract.TOTAL_RAFTS()-amount);
        nftContract.updatePublicMint(true);

        // Mint all token ids up to the starting token id
        mintTokens(address(nftContract), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = nftContract.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        uint256 msgValue = amount * WAD;
        assert(joe.try_mint{value: msgValue}(address(nftContract), amount));
        assertEq(nftContract.balanceOf(address(joe)), amount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = nftContract.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        uint256[] memory tokens = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        for(uint256 i = 0; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[i++], firstTokenId);
            assertEq(nftContract.ownerOf(firstTokenId), address(joe));
        }
    }

    /// @notice Test that an empty array is returned for an address with a zero balance.
    function test_nft_ownedTokens_ZeroBalance() public {
        nftContract.updatePublicMint(true);

        // Joe can check owned tokens with a zero balance
        assertEq(nftContract.balanceOf(address(joe)), 0);
        assertEq(nftContract.ownedTokens(address(joe)).length, 0);

        // Joe can mint one token with an id equal to currentTokenId plus one
        uint256 ownedId = nftContract.currentTokenId() + 1;
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));
        assertEq(nftContract.balanceOf(address(joe)), 1);
        assertEq(nftContract.ownerOf(ownedId), address(joe));

        // Joe can get owned tokens with a balance of one or more tokens
        uint256[] memory tokenIds = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokenIds.length);
        assertEq(ownedId, tokenIds[0]);
    }

    /// @notice Test validity and gas costs of ownedTokens view function for an address
    /// owning sequential token ids toward the start of the possible token id range.
    function test_nft_ownedTokens_SequentialLow() public {
        uint256 startingId = 700;
        uint256 amount = 17;
        nftContract.updatePublicMint(true);

        // Mint all token ids up to the starting token id
        mintTokens(address(nftContract), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = nftContract.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        assert(joe.try_mint{value: 17 ether}(address(nftContract), amount));
        assertEq(nftContract.balanceOf(address(joe)), amount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = nftContract.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        uint256[] memory tokens = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        for(uint256 i = 0; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[i++], firstTokenId);
            assertEq(nftContract.ownerOf(firstTokenId), address(joe));
        }
    }

    /// @notice Test validity and gas costs of ownedTokens view function for an address
    /// owning sequential token ids toward the end of the possible token id range.
    function test_nft_ownedTokens_SequentialHigh() public {
        uint256 amount = 17;
        uint256 startingId = 9000;
        nftContract.updatePublicMint(true);

        // Mint all token ids up to the starting token id
        mintTokens(address(nftContract), startingId);

        // The first token id Joe mints, currentTokenId is the token id most recently minted
        uint256 firstTokenId = nftContract.currentTokenId()+1;

        // Mint an amount of tokens for Joe
        assert(joe.try_mint{value: 17 ether}(address(nftContract), amount));
        assertEq(nftContract.balanceOf(address(joe)), amount);

        // The last token id Joe mints, Joe mints up to the currentTokenId inclusive
        uint256 lastTokenId = nftContract.currentTokenId();

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        uint256[] memory tokens = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokens.length);

        // Verify that the token ids in the array returned include all token ids
        // starting with the firstTokenId up to the lastTokenId
        for(uint256 i = 0; firstTokenId <= lastTokenId; firstTokenId++) {
            assertEq(tokens[i++], firstTokenId);
            assertEq(nftContract.ownerOf(firstTokenId), address(joe));
        }
    }

    /// @notice Test validity and gas costs of ownedTokens view function for an address
    /// owning 0.5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_SporadicSmall() public {
        nftContract.updatePublicMint(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own.
        uint16[50] memory ownedIds = [268, 435, 656, 767, 1186, 1197, 1229, 1655, 1673, 1897, 1950, 2230, 2332, 2489, 2497, 2981, 3069, 3524, 3603, 3644, 3876, 4075, 4124, 4144, 4375, 4393, 4587, 4857, 5274, 5436, 5565, 5663, 6206, 6497, 6552, 7150, 7197, 7321, 7348, 7697, 7736, 8236, 8496, 8563, 8586, 8601, 9311, 9324, 9458, 9846];
        uint256 total = nftContract.TOTAL_RAFTS(); 
        uint256 length = ownedIds.length;

        // Mint out all token ids 1-10000
        mintTokens(address(nftContract), total);

        // Transfer any "owned" token ids to Joe
        for(uint256 i = 0; i < length; ++i) {   
            uint256 id = ownedIds[i];             
            address from = nftContract.ownerOf(id);
            vm.prank(from);
            nftContract.transferFrom(from, address(joe), id);
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        uint256[] memory tokenIds = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 i = 0; i < length; ++i) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(nftContract.ownerOf(ownedIds[i]), address(joe));
        }
    }

    /// @notice Test validity and gas costs of ownedTokens view function for an address
    /// owning 5% of total supply randomly spread across the range of possible token ids.
    function test_nft_ownedTokens_SporadicLarge() public {
        nftContract.updatePublicMint(true);

        // Array of random token ids between 1 and 10000 that a wallet could potentially own
        uint16[500] memory ownedIds = [12, 15, 29, 37, 43, 50, 88, 94, 100, 107, 109, 137, 164, 177, 186, 213, 281, 295, 296, 350, 352, 361, 379, 389, 420, 441, 443, 461, 506, 516, 551, 579, 584, 625, 633, 643, 653, 668, 682, 702, 708, 728, 763, 777, 783, 794, 836, 882, 890, 897, 906, 920, 922, 933, 945, 975, 1004, 1016, 1018, 1030, 1037, 1042, 1053, 1084, 1085, 1090, 1094, 1122, 1146, 1154, 1160, 1190, 1201, 1204, 1212, 1221, 1224, 1231, 1269, 1280, 1284, 1317, 1330, 1363, 1379, 1384, 1390, 1400, 1418, 1468, 1475, 1477, 1478, 1485, 1504, 1514, 1541, 1551, 1568, 1599, 1603, 1606, 1620, 1628, 1651, 1652, 1663, 1715, 1721, 1744, 1759, 1776, 1797, 1837, 1847, 1875, 1879, 1891, 1917, 1919, 1957, 1973, 2015, 2048, 2052, 2065, 2069, 2074, 2076, 2102, 2104, 2112, 2114, 2118, 2151, 2183, 2194, 2205, 2209, 2219, 2251, 2262, 2279, 2288, 2307, 2369, 2380, 2383, 2434, 2451, 2499, 2572, 2581, 2586, 2616, 2617, 2628, 2642, 2643, 2649, 2651, 2659, 2666, 2722, 2731, 2733, 2748, 2762, 2792, 2797, 2807, 2814, 2848, 2878, 2894, 2914, 2924, 2929, 2933, 2965, 2977, 2978, 2986, 3107, 3117, 3147, 3158, 3175, 3206, 3213, 3229, 3259, 3309, 3331, 3349, 3407, 3418, 3439, 3445, 3455, 3469, 3483, 3488, 3525, 3530, 3594, 3607, 3628, 3663, 3687, 3699, 3705, 3721, 3742, 3767, 3769, 3775, 3790, 3839, 3861, 3866, 3906, 3911, 3933, 3957, 3981, 3988, 4008, 4016, 4045, 4057, 4100, 4128, 4147, 4149, 4172, 4188, 4211, 4214, 4228, 4261, 4291, 4311, 4336, 4340, 4356, 4366, 4371, 4398, 4407, 4412, 4429, 4436, 4454, 4456, 4462, 4521, 4592, 4609, 4610, 4614, 4648, 4650, 4663, 4730, 4744, 4785, 4787, 4794, 4823, 4827, 4831, 4853, 4891, 4894, 4895, 4897, 4914, 4933, 4969, 4983, 5001, 5005, 5016, 5034, 5073, 5081, 5100, 5109, 5111, 5114, 5117, 5132, 5221, 5258, 5265, 5272, 5286, 5314, 5316, 5373, 5376, 5381, 5389, 5393, 5397, 5500, 5502, 5551, 5587, 5589, 5611, 5618, 5623, 5634, 5643, 5677, 5700, 5732, 5779, 5784, 5809, 5833, 5843, 5862, 5887, 5905, 5951, 5972, 5991, 6016, 6110, 6122, 6126, 6132, 6147, 6152, 6154, 6177, 6184, 6201, 6202, 6228, 6266, 6267, 6283, 6285, 6298, 6324, 6329, 6344, 6360, 6376, 6404, 6423, 6529, 6547, 6550, 6587, 6588, 6649, 6650, 6675, 6728, 6730, 6731, 6742, 6748, 6766, 6782, 6784, 6890, 6893, 6900, 6902, 6927, 6938, 6944, 6972, 6989, 7019, 7031, 7042, 7072, 7100, 7110, 7126, 7149, 7163, 7174, 7196, 7203, 7214, 7239, 7282, 7299, 7315, 7320, 7330, 7346, 7369, 7441, 7444, 7459, 7465, 7515, 7517, 7539, 7553, 7608, 7631, 7640, 7647, 7657, 7664, 7769, 7801, 7815, 7838, 7848, 7855, 7871, 7874, 7918, 7977, 8013, 8038, 8076, 8077, 8127, 8133, 8204, 8288, 8294, 8300, 8321, 8346, 8348, 8360, 8401, 8443, 8484, 8485, 8535, 8554, 8582, 8584, 8599, 8601, 8649, 8721, 8736, 8754, 8801, 8913, 8958, 8968, 8980, 8982, 8987, 8992, 8994, 9002, 9040, 9145, 9188, 9190, 9201, 9238, 9253, 9254, 9271, 9313, 9356, 9380, 9424, 9450, 9542, 9550, 9560, 9592, 9596, 9598, 9657, 9663, 9716, 9731, 9797, 9809, 9850, 9852, 9861, 9890, 9893, 9910, 9919, 9933, 9937, 9985, 9993];
        uint256 total = nftContract.TOTAL_RAFTS(); 
        uint256 length = ownedIds.length;

        // Mint out all token ids 1-10000
        mintTokens(address(nftContract), total);

        // Transfer any "owned" token ids to Joe
        for(uint256 i = 0; i < length; ++i) {   
            uint256 id = ownedIds[i];             
            address from = nftContract.ownerOf(id);
            vm.prank(from);
            nftContract.transferFrom(from, address(joe), id);
        }

        // Check amount of tokens in the array returned is equivalent to Joe's balance
        uint256[] memory tokenIds = nftContract.ownedTokens(address(joe));
        assertEq(nftContract.balanceOf(address(joe)), tokenIds.length);

        // Check every owned token id against the token ids in the array returned
        for(uint256 i = 0; i < ownedIds.length; ++i) {
            assertEq(tokenIds[i], ownedIds[i]);
            assertEq(nftContract.ownerOf(ownedIds[i]), address(joe));
        }
    }


    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Test that the onlyOwner modifier reverts unless call is from the owner.
    /// @dev Must be run with an appropriate rpc url!
    function test_nft_onlyOwner() public {
        // Transfer ownership to the developer actor
        nftContract.transferOwnership(address(dev));

        // Setup new addresses and balances
        address newSig = makeAddr("New MultiSig Wallet");
        vm.deal(address(nftContract), 100 ether);
        deal(USDC, address(nftContract), 100 * USD);

        // Joe cannot call functions with onlyOwner modifier
        assert(!joe.try_setBaseURI(address(nftContract), "ipfs::/RevealedURI/"));
        assert(!joe.try_updatePublicMint(address(nftContract), true));
        assert(!joe.try_updateWhitelistMint(address(nftContract), true));
        assert(!joe.try_updateSubId(address(nftContract), subId));
        assert(!joe.try_updateMultiSig(address(nftContract), newSig));
        assert(!joe.try_withdraw(address(nftContract)));
        assert(!joe.try_withdrawERC20(address(nftContract), USDC));
        assert(!joe.try_requestEntropy(address(nftContract)));
        assert(!joe.try_finalizeMint(address(nftContract)));
        assert(!joe.try_shuffleLevels(address(nftContract)));

        // Developer can call function with onlyOwner modifier
        assert(dev.try_setBaseURI(address(nftContract), "ipfs::/RevealedURI/"));
        assert(dev.try_updatePublicMint(address(nftContract), true));
        assert(dev.try_updateWhitelistMint(address(nftContract), true));
        assert(dev.try_updateSubId(address(nftContract), subId));
        assert(dev.try_updateMultiSig(address(nftContract), newSig));
        assert(dev.try_withdraw(address(nftContract)));
        assert(dev.try_withdrawERC20(address(nftContract), USDC));

        // Mint one token and fulfill entropy for shuffling
        mintTokens(address(nftContract), 1);
        assert(dev.try_requestEntropy(address(nftContract)));        
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(nftContract), entropy);
        assert(dev.try_finalizeMint(address(nftContract)));
        assert(dev.try_shuffleLevels(address(nftContract)));
    }

    // --- finalizeMint() ---

    /// @notice Test that state is updated correctly to finalize mint.
    function test_nft_finalizeMint_Finalized() public {
        nftContract.updatePublicMint(true);
        nftContract.updateWhitelistMint(true);

        // Verify contract state reflects mint is not finalized
        assert(!nftContract.finalized());

        // Joe and whitelisted user 0 can mint one token each
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));
        bytes32[] memory validProof = merkle.getProof(tree, 0);
        assert(whitelist[0].try_mintWhitelist{value: 1 ether}(address(nftContract), 1, validProof));

        // Verify minted token ids have levels assigned and currentTokenId reflects total minted
        assertEq(nftContract.levelOf(1), 1);
        assertEq(nftContract.levelOf(2), 2);
        assertEq(nftContract.currentTokenId(), 2);
        vm.expectRevert("NOT_MINTED");
        nftContract.levelOf(3);

        // Owner can finalize mint to end public and whitelist mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());
        assert(!nftContract.publicMint());
        assert(!nftContract.whitelistMint());

        // Joe cannot mint another token 
        vm.prank(address(joe));
        vm.expectRevert("NFT.sol::mint() Public mint is not active");
        nftContract.mint{value: 1 ether}(1);

        // Whitelisted user 0 cannot mint another token
        vm.prank(address(whitelist[0]));
        vm.expectRevert("NFT.sol::mintWhitelist() Whitelist mint is not active");
        nftContract.mintWhitelist{value: 1 ether}(1, validProof);
    }

    /// @notice Test that attempts to finalize mint more than once revert.
    function test_nft_finalizeMint_AlreadyFinalized() public {
        // Verify contract state reflects mint is not finalized
        assert(!nftContract.finalized());

        // Owner can finalize mint to end public and whitelist mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());
        assert(!nftContract.publicMint());
        assert(!nftContract.whitelistMint());

        // Owner cannot finalize mint again since mint has already been finalized
        vm.expectRevert("NFT.sol::finalizeMint() Mint already finalized");
        nftContract.finalizeMint();
    }

    // --- requestEntropy() ---

    /// @notice Test that randomness can be requested and fulfilled from Chainlink VRF.
    function testFuzz_nft_requestEntropy_RequestFulfilled(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy from Chainlink VRF
        uint256 requestId = nftContract.requestEntropy();
        assert(!nftContract.fulfilled());
        assertEq(nftContract.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), words);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), word);
    }

    /// @notice Test that randomness can only be fulfilled once without reverting 
    /// in case multiple requests are made and multiple fulfillments received.
    function testFuzz_nft_requestEntropy_MultipleRequests(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy multiple times from Chainlink VRF
        uint256 requestIdOne = nftContract.requestEntropy();
        uint256 requestIdTwo = nftContract.requestEntropy();
        assert(!nftContract.fulfilled());
        assertEq(nftContract.entropy(), 0);

        // Mock VRF response with entropy from Chainlink and fulfill request one
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdOne, address(nftContract), words);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), word);

        // The fulfillRandomWords function will not revert/ update entropy when fulfilling request two
        words[0] = uint256(bytes32(0xdbdb4ee44eca0cfa2a2479a529fd35fb4a40df14358c724b6d7fb834aef0288f));
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdTwo, address(nftContract), words);

        // Entropy should not change if/when another request is "fulfilled"
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), word);
    }

    /// @notice Test that attempts to request randomness entropy fulfilled revert. 
    function testFuzz_nft_requestEntropy_AlreadyFulfilled(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy from Chainlink VRF
        uint256 requestId = nftContract.requestEntropy();
        assert(!nftContract.fulfilled());
        assertEq(nftContract.entropy(), 0);

        // Mock VRF response with entropy "from" Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), words);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), word);

        // Owner cannot request entropy again since it was already fulfilled
        vm.expectRevert("NFT.sol::requestEntropy() Entropy already fulfilled");
        nftContract.requestEntropy();
    }

    // --- shuffleLevels() ---

    /// @notice Test that levels can be shuffled with tokens minted, entropy fulfilled, and mint finalized.
    function test_nft_shuffleLevels_Shuffled() public {
        nftContract.updatePublicMint(true);
        
        // Simulate minting out all tokens
        mintTokens(address(nftContract), nftContract.TOTAL_RAFTS());

        // Owner can finalize mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());

        // Owner can request entropy and have it fulfilled
        uint256 requestId = nftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), entropy);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), entropy[0]);

        // Owner can shuffle levels with tokens minted, mint finalized, and entropy fulfilled
        nftContract.shuffleLevels();
        assert(nftContract.shuffled());
    }

        /// @notice Test that shuffled levels are between the first and last token ids.
    function testFuzz_nft_shuffleLevels_Levels(uint256 amount) public {
        amount = bound(amount, 1, nftContract.TOTAL_RAFTS());
        nftContract.updatePublicMint(true);

        // Track the last token id minted
        mintTokens(address(nftContract), amount);
        uint256 lastTokenId = nftContract.currentTokenId();

        // Owner can finalize mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());

        // Owner can request entropy and have it fulfilled
        uint256 requestId = nftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), entropy);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), entropy[0]);

        // Owner can shuffle levels
        nftContract.shuffleLevels();

        // Tokens should have levels between the first and last token id
        for(uint256 tokenId = 1; tokenId <= lastTokenId; ++tokenId) {
            uint256 level = nftContract.levelOf(tokenId);
            assertGe(level, 1);
            assertLe(level, lastTokenId);
        }
    }

    /// @notice Test that attempts to shuffle without any tokens minted revert.
    function test_nft_shuffleTokens_ZeroTokens() public {
        // Verify no tokens have been minted and that levels have not been set
        assertEq(nftContract.currentTokenId(), 0);
        vm.expectRevert("NOT_MINTED");
        nftContract.levelOf(1);

        // Owner cannot shuffle levels without any tokens minted
        vm.expectRevert("NFT.sol::shuffleLevels() No tokens to shuffle");
        nftContract.shuffleLevels();

        // Joe can mint one token before mint is finalized
        nftContract.updatePublicMint(true);
        assert(joe.try_mint{value: 1 ether}(address(nftContract), 1));
        assertEq(nftContract.currentTokenId(), 1);
        
        // Owner can finalize mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());

        // Owner can request entropy and have it fulfilled
        uint256 requestId = nftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), entropy);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), entropy[0]);

        // Owner can shuffle levels with at least one token minted, mint finalized, and entropy fulfilled
        nftContract.shuffleLevels();
        assert(nftContract.shuffled());
    }

    /// @notice Test that attempts to shuffle levels before mint is finalized revert.
    function test_nft_shuffleLevels_NotFinalized() public {
        // Joe can mint 20 tokens before mint is finalized
        nftContract.updatePublicMint(true);
        assert(joe.try_mint{value: 20 ether}(address(nftContract), 20));

        // Owner cannot shuffle levels until mint is finalized
        vm.expectRevert("NFT.sol::shuffleLevels() Mint must be finalized");
        nftContract.shuffleLevels();
    }

    /// @notice Test that attempts to shuffle levels before entropy is fulfilled revert.
    function test_nft_shuffleLevels_NoEntropy() public {
        // Joe can mint 20 tokens before mint is finalized
        nftContract.updatePublicMint(true);
        assert(joe.try_mint{value: 20 ether}(address(nftContract), 20));

        // Owner can finalize mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());

        // Owner can request entropy but not have it fulfilled yet
        nftContract.requestEntropy();
        assert(!nftContract.fulfilled());
        assertEq(nftContract.entropy(), 0);

        // Owner cannot shuffle levels until entropy is fulfilled
        vm.expectRevert("NFT.sol::shuffleLevels() Entropy must be fulfilled");
        nftContract.shuffleLevels();
    }

    /// @notice Test that attempts to shuffle levels more than once revert.
    function test_nft_shuffleLevels_AlreadyShuffled() public {
        // Joe can mint 20 tokens before mint is finalized
        nftContract.updatePublicMint(true);
        assert(joe.try_mint{value: 20 ether}(address(nftContract), 20));

        // Owner can finalize mint
        nftContract.finalizeMint();
        assert(nftContract.finalized());

        // Owner can request entropy and have it fulfilled
        uint256 requestId = nftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), entropy);
        assert(nftContract.fulfilled());
        assertEq(nftContract.entropy(), entropy[0]);

        // Owner can shuffle levels with tokens minted, mint finalized, and entropy fulfilled
        nftContract.shuffleLevels();
        assert(nftContract.shuffled());

        // Owner cannot shuffle levels again since they were already shuffled
        vm.expectRevert("NFT.sol::shuffleLevels() Levels already shuffled");
        nftContract.shuffleLevels();
    }

    // --- setBaseURI() ---

    /// @notice Test that the base URI can be set to a new address for revealing.
    function test_nft_setBaseURI_Set() public {
        // Verify URI state reflects deployment
        assertEq(nftContract.baseURI(), "");

        // Owner can set the base URI to a new address
        nftContract.setBaseURI("ipfs::/RevealedURI/");

        // Verify URI state reflects changes
        assertEq(nftContract.baseURI(), "ipfs::/RevealedURI/");
    }

    // --- updatePublicMint() ---

    /// @notice Test that the public mint can be updated to start public mint.
    function test_nft_updatePublicMint_Updated() public {
        // Verify public mint state reflects deployment
        assert(!nftContract.publicMint());

        // Owner can update the public mint state from false to true
        nftContract.updatePublicMint(true);

        // Verify public mint state reflects changes
        assert(nftContract.publicMint());
    }

    /// @notice Test that attempts to update public mint state after finalizing mint revert.
    function test_nft_updatePublicMint_Finalized() public {
        // Verify public mint state reflects deployment
        assert(!nftContract.publicMint());

        // Owner can update the public mint state from false to true
        nftContract.updatePublicMint(true);
        assert(nftContract.publicMint());

        // Owner can finalize tokens to end public and whitelist mint
        nftContract.finalizeMint();
        assert(!nftContract.publicMint());

        // Owner cannot update the public mint state after finalizing tokens
        vm.expectRevert("NFT.sol::updatePublicMint() Mint is finalized");
        nftContract.updatePublicMint(true);
    }

    // --- updateWhitelistMint() ---

    /// @notice Test that the whitelist mint state can be updated to start whitelist mint.
    function test_nft_updateWhitelistMint_Updated() public {
        // Verify whitelist mint state reflects deployment
        assert(!nftContract.whitelistMint());

        // Owner can update the whitelist mint state from false to true
        nftContract.updateWhitelistMint(true);

        // Verify whitelist mint state reflects changes
        assert(nftContract.whitelistMint());
    }

    /// @notice Test that attempts to update public mint state after finalizing mint revert.
    function test_nft_updateWhitelistMint_Finalized() public {
        // Verify public mint state reflects deployment
        assert(!nftContract.whitelistMint());

        // Owner can update the public mint state from false to true
        nftContract.updateWhitelistMint(true);
        assert(nftContract.whitelistMint());

        // Owner can finalize tokens to end public and whitelist mint
        nftContract.finalizeMint();
        assert(!nftContract.whitelistMint());

        // Owner cannot update the whitelist mint state after finalizing tokens
        vm.expectRevert("NFT.sol::updateWhitelistMint() Mint is finalized");
        nftContract.updateWhitelistMint(true);
    }

    // --- updateMultiSig() ---

    /// @notice Test that the multisig wallet address can be updated to a new address.
    function test_nft_updateMultiSig_Updated() public {
        // Verify multisig wallet state reflects deployment
        assertEq(nftContract.multiSig(), sig);
        
        // Owner can update multisig to a new address
        address newSig = makeAddr("New MultiSig Wallet");
        nftContract.updateMultiSig(newSig);

        // Verify multisig wallet reflects changes
        assertEq(nftContract.multiSig(), newSig);
    }

    /// @notice Test that updating the multisig wallet to the zero address reverts.
    function test_nft_updateMultiSig_ZeroAddress() public {
        // Verify multisig wallet state reflects deployment
        assertEq(nftContract.multiSig(), sig);

        // Owner cannot update multisig wallet to the zero address
        vm.expectRevert("NFT.sol::updateMultiSig() Address cannot be zero address");
        nftContract.updateMultiSig(address(0));
    }
    
    // --- withdraw() ---

    /// @notice Test that the balance of the contract can be withdrawn to multisig wallet.
    function test_nft_withdraw_Basic() public {
        assertEq(address(nftContract).balance, 0);
        assertEq(sig.balance, 0);

        // Simulate minting out by giving NFT contract an Ether balance of TOTAL_RAFTS * RAFT_PRICE
        uint256 totalBalance = nftContract.TOTAL_RAFTS() * nftContract.RAFT_PRICE();
        vm.deal(address(nftContract), totalBalance);
        assertEq(address(nftContract).balance, totalBalance);

        // Withdraw NFT contract balance after minting out to circle account
        nftContract.withdraw();
        assertEq(address(nftContract).balance, 0);
        assertEq(sig.balance, totalBalance);
    }

    /// @notice Test that nonzero balances of the contract can be withdrawn to multisig wallet.
    function testFuzz_nft_withdraw_Withdrawn(uint256 amount) public {
        if(amount < 1) {
            return;
        }

        assertEq(address(nftContract).balance, 0);
        assertEq(sig.balance, 0);

        // Simulate the NFT contract receiving an amount of Ether
        vm.deal(address(nftContract), amount);
        assertEq(address(nftContract).balance, amount);

        // Withdraw NFT contract balance after receiving an amount of Ether from mint
        nftContract.withdraw();
        assertEq(address(nftContract).balance, 0);
        assertEq(sig.balance, amount);
    }

    /// @notice Test that withdrawal attempts when the contract balance is zero revert.
    function test_nft_withdraw_InsufficientBalance() public {
        assertEq(address(nftContract).balance, 0);
        assertEq(sig.balance, 0);

        // Owner cannot withdraw from the contract unless the contract contains Ether.
        vm.expectRevert("NFT.sol::withdraw() Insufficient ETH balance");
        nftContract.withdraw();
    }

    /// @notice Test that withdrawal attempts revert when the recipient reverts on transfer.
    function test_nft_withdraw_BadRecipient() public {
        // Actor is a contract that cannot receive Ether on calls
        Actor newMultiSig = new Actor();
        nftContract.updateMultiSig(address(newMultiSig));

        assertEq(address(nftContract).balance, 0);
        assertEq(address(newMultiSig).balance, 0);

        // Simulate minting out by giving NFT contract an Ether balance of TOTAL_RAFTS * RAFT_PRICE
        uint256 totalBalance = nftContract.TOTAL_RAFTS() * nftContract.RAFT_PRICE();
        vm.deal(address(nftContract), totalBalance);
        assertEq(address(nftContract).balance, totalBalance);

        // Owner cannot withdraw to multi-sig if the address cannot accept Ether
        vm.expectRevert("NFT.sol::withdraw() Unable to withdraw funds, recipient may have reverted");
        nftContract.withdraw();
    }

    // --- withdrawERC20() ---
    /// @dev Withdraw test cases must be run with an appropriate rpc url!

    /// @notice Test that ERC20 token amounts are withdrawn from the contract to multi-sig.
    function testFuzz_nft_withdrawERC20_Withdrawn(uint256 amount) public {
        if(amount < 1) {
            return;
        }

        // Use LINK as an example ERC20 token
        IERC20 token = IERC20(LINK);
        assertEq(token.balanceOf(address(nftContract)), 0);
        assertEq(token.balanceOf(sig), 0);

        // Simulate NFT contract receiving an amount of LINK
        deal(address(LINK), address(nftContract), amount);
        assertEq(token.balanceOf(address(nftContract)), amount);

        // Owner can withdraw NFT contract ERC20 balance to multi-sig wallet
        nftContract.withdrawERC20(LINK);
        assertEq(token.balanceOf(address(nftContract)), 0);
        assertEq(token.balanceOf(sig), amount);
    }

    /// @notice Test that ERC20 withdrawl attempts from the zero address revert.
    function test_nft_withdrawERC20_ZeroAddress() public {
        // Owner cannot withdraw from the zero address
        vm.expectRevert("NFT.sol::withdrawERC20() Address cannot be zero address");
        nftContract.withdrawERC20(address(0));
    }

    /// @notice Test that ERC20 withdrawl attempts when the contract balance is zero revert.
    function test_nft_withdrawERC20_InsufficientBalance() public {
        // Use LINK as an example ERC20 token
        IERC20 token = IERC20(LINK);
        assertEq(token.balanceOf(address(nftContract)), 0);
        assertEq(token.balanceOf(sig), 0);

        // Owner cannot withdraw NFT contract token balance when the balance is zero
        vm.expectRevert("NFT.sol::withdrawERC20() Insufficient token balance");
        nftContract.withdrawERC20(LINK);
    }
}