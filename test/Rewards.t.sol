// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Utility.sol";
import "../src/Rewards.sol";
import "../src/NFT.sol";
import "./utils/VRFCoordinatorV2Mock.sol";

/// @author Andrew Gucci
/// @notice Unit tests for Gifts contract.
contract GiftsTest is Utility {
    // State variables for contracts.
    Gifts giftContract;
    NFT raftToken;
    VRFCoordinatorV2Mock vrfCoordinator;

    // State variables for test values.
    uint256 entropy = uint256(bytes32(0x01e4928c21c69891d8b1c3520a35b74f6df5f28a867f30b2cd9cd81a01b3aabd));
    uint256 claimStart;
    uint256 claimEnd;
    uint64 subId;

    // Model events the Gifts contract will emit.
    event TokensInitialized();
    event TokensShuffled();
    event GiftDataSet();
    event GiftClaimed(
        address indexed recipient, 
        uint256 indexed id, 
        Gifts.Tier tier,            
        uint256 value
    );

    function setUp() public {
        createActors();

        // Initialize NFT contract
        raftToken = new NFT(
            "RaftToken",                        // Name of collection
            "RT",                               // Symbol of collection
            "ipfs::/Unrevealed/",               // Unrevealed URI
            crc,                                // Circle Account
            sig,                                // Multi-signature wallet
            bytes32(0x0)                        // Whitelist root
        );

        // Initialize mock VRF coordinator contract with subscription and funding
        vrfCoordinator = new VRFCoordinatorV2Mock(100000, 100000);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 100 ether);
        
        // Initialize Gifts contract with claim start and end times
        claimStart = block.timestamp + 1 days;
        claimEnd = claimStart + 7 days;

        giftContract = new Gifts(
            claimStart,                         // Claim start 
            address(raftToken),                 // NFT Address
            address(vrfCoordinator),            // Mock VRF Address
            USDC,                               // USDC Address
            crc                                 // Circle Account
        ); 

        // Update subscription and add the Gifts contract as a consumner
        giftContract.updateSubId(subId);
        vrfCoordinator.addConsumer(subId, address(giftContract));

        // Mint all NFTs to actors to simulate minting out
        raftToken.setPublicSaleState(true);
        mintTokens(address(raftToken), 10000);
    }


    // ----------------
    // Helper Functions
    // ---------------- 

    function setupTokens() internal {
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit TokensInitialized();
        giftContract.initializeTokens();
        assert(giftContract.initialized());
    }

    function setupEntropy(uint256 word) internal {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        uint256 requestId = giftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(giftContract), words);
        assert(giftContract.fulfilled());
        assertEq(giftContract.entropy(), word);
    }

    function setupShuffle() internal {
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit TokensShuffled();
        giftContract.shuffleTokens();
        assert(giftContract.shuffled());
    }

    function setupGiftData() internal {
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit GiftDataSet();
        giftContract.setTokenGiftData();
    }

    function giftDataForIndex(uint256 index) internal pure returns (uint8 tier, uint256 gift) {
        if(index == 0) {
            gift = 100000 * USD;
            tier = uint8(Gifts.Tier.One);
        } else if(index < 11) {
            gift = 10000 * USD;
            tier = uint8(Gifts.Tier.Two);
        } else if(index < 111) {
            gift = 1000 * USD;
            tier = uint8(Gifts.Tier.Three);
        } else if(index < 511) {
            gift = 500 * USD;
            tier = uint8(Gifts.Tier.Four);
        } else if(index < 2511) {
            gift = 250 * USD;
            tier = uint8(Gifts.Tier.Five);
        } else {
            gift = 0;
            tier = uint8(Gifts.Tier.Six);
        }
    }


    // -----------------------
    // Deployed Contract State
    // -----------------------

    /// @notice Test intial values set in the constructor.
    function test_gifts_DeployedState() public {
        assertEq(address(giftContract.stableCurrency()), address(USDC));
        assertEq(address(giftContract.nftContract()), address(raftToken));
        assertEq(address(giftContract.vrfCoordinatorV2()), address(vrfCoordinator));
        assertEq(giftContract.claimStart(), claimStart);
        assertEq(giftContract.claimEnd(), claimStart + 7 days);

        assertEq(giftContract.entropy(), 0);
        assertEq(giftContract.subId(), subId);
        assertEq(giftContract.CALLBACK_GAS_LIMIT(), 50000);
        assertEq(giftContract.NUM_WORDS(), 1);
        assertEq(giftContract.REQUEST_CONFIRMATIONS(), 20);
        assertEq(giftContract.TOTAL_RECIPIENTS(), 2511);
        assertEq(giftContract.STABLE_DECIMALS(), 10**6);

        assert(!giftContract.fulfilled());
        assert(!giftContract.initialized());
        assert(!giftContract.shuffled());
    }

    /// @notice Test default values within the tokenData mapping.
    function test_gifts_tokenData_DeployedStateFuzzing(uint256 tokenId) public {
        (address recipient, Gifts.Tier tier, bool claimed) = giftContract.tokenData(tokenId);

        // Verify gift data values against expected default values
        assertEq(recipient, address(0));
        assertEq(uint8(tier), uint8(Gifts.Tier.Six));
        assert(!claimed);
    }

    /// @notice Test assigned values within the tokenData mapping after setting gift data.
    function test_gifts_tokenData_GiftDataSetFuzzing(uint256 index) public {
        index = bound(index, 0, 9999);

        // Initialize tokens, get entropy, shuffle tokens, and set gift data
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();
        setupGiftData();

        uint256 tokenId = giftContract.tokens(index);
        (uint8 tokenTier,) = giftDataForIndex(index);
        (address recipient, Gifts.Tier tier, bool claimed) = giftContract.tokenData(tokenId);

        // Verify gift data values against expected set values
        assertEq(recipient, address(0));
        assertEq(uint8(tier), tokenTier);
        assert(!claimed);
    }


    // ----------------
    // Public Functions
    // ----------------

    // --- claimGift() ---
    /// @dev Claim test cases must be run with an appropriate rpc url!

    /**
    TierOne
    - Simple test to make sure Tier One reverts with “No gift available”

    TierTwo
    - Iterate over all Tier Two token ids given an index (1-10)

    TierThree
    - Iterate over all Tier Three token ids given an index (11-110)

    TierFour
    - Iterate over all Tier Four token ids given an index (111-510)

    TierFive
    - Iterate over all Tier Five token ids given an index (511-2510)

    TierSix
    - Iterate over all Tier Six token ids given an index (2511-9999) and ensure all revert with “No gift available”

    AlreadyClaimed
    - Choose an index with a valid gift
    - Claim the gift
    - Attempt to claim gift again
    - Ensure reverts with “Gift already claimed”

    NotOwner
    - Choose an index with a valid gift
    - Attempt to claim the gift but not as the owner
    - Ensure reverts with “Address is not owner”

    NotInitialized && EntropyNotFulfilled && NotShuffled && GiftDataNotSet
    - Ensure that attempts to claim before any of the above revert with “No gift available for token”

    InsufficientBalance
    - Ensure that any claim that is greater than the Gift contract’s stable currency balance reverts with “Insufficient stable currency balance”
     */

    // Test that gifts can be claimed for token ids with valid indexes.
    function test_gifts_claimGift_Claimed() public {
        // Initialize tokens, get entropy, shuffle tokens, and set gift data
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();
        setupGiftData();
        
        // Simulate Gifts contract receiving 1_000_000 USDC from Circle Account
        deal(USDC, address(giftContract), 1000000 * USD);
        vm.warp(claimStart + 1);

        // Iterate over all indexes with valid gifts to claim
        for(uint256 i = 1; i < 2511; ++i) {
            (uint8 tokenTier, uint256 tokenGift) = giftDataForIndex(i);
            uint256 tokenId = giftContract.tokens(i);
            address tokenOwner = raftToken.ownerOf(tokenId);
            uint256 balanceBefore = IERC20(USDC).balanceOf(tokenOwner);

            // The gift associated with the token id can only be claimed by the owner 
            vm.prank(tokenOwner);
            giftContract.claimGift(tokenId);
            
            // Verify gift data values were updated accordingly
            (address recipient, Gifts.Tier tier, bool claimed) = giftContract.tokenData(tokenId);
            assertEq(IERC20(USDC).balanceOf(tokenOwner), balanceBefore + tokenGift);
            assertEq(recipient, tokenOwner);
            assertEq(uint8(tier), uint8(tokenTier));
            assert(claimed);
        }
    }

    /// @notice Test that claiming the Tier One token id reverts.
    function test_gifts_claimGift_TierOne() public {

    }
    
    /// @notice Test that claiming is successful for Tier Two token ids.
    function test_gifts_claimGift_TierTwo() public {
        
    }

    /// @notice Test that claiming is successful for Tier Two token ids.
    function test_gifts_claimGift_TierThree() public {
        
    }

    /// @notice Test that claiming is successful for Tier Two token ids.
    function test_gifts_claimGift_TierFour() public {
        
    }

    /// @notice Test that claiming is successful for Tier Two token ids.
    function test_gifts_claimGift_TierFive() public {
        
    }

    /// @notice Test that claim attempts for any Tier Six token ids revert.
    function test_gifts_claimGift_TierSix() public {
        
    }

    function test_gifts_claimGift_BadToken() public {
        // Initialize tokens, get entropy, shuffle tokens, and set gift data
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();
        setupGiftData();

        // Valid token ids include integers between 1 and 10000 inclusive.
        vm.warp(claimStart + 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() No gift available for the token"));
        giftContract.claimGift(0);
    }

    function testFuzz_gifts_claimGift_BadToken(uint256 tokenId) public {
        // Valid token ids include integers between 1 and 10000 inclusive.
        tokenId = bound(tokenId, 10001, type(uint256).max);
        
        // Initialize tokens, get entropy, shuffle tokens, and set gift data
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();
        setupGiftData();

        vm.warp(claimStart + 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() No gift available for the token"));
        giftContract.claimGift(tokenId);
    }

    /// @notice Test that attempts to claim before claiming starts revert.
    function test_gifts_claimGift_ClaimingPending() public {
        // Nobody can claim gifts for any token id before claiming starts
        vm.warp(claimStart - 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() Claiming period has not started"));
        giftContract.claimGift(1);
    }

    /// @notice Test that attempts to claim any token id before claiming starts revert.
    function testFuzz_gifts_claimGift_ClaimingPending(uint256 tokenId) public {
        // Nobody can claim gifts for any token id before the claiming period starts
        vm.warp(claimStart - 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() Claiming period has not started"));
        giftContract.claimGift(tokenId);
    }

    /// @notice Test that attempts to claim after claiming ends revert.
    function test_gifts_claimGift_ClaimingEnded() public {
        // Nobody can claim gifts for any token id after claiming ends
        vm.warp(claimEnd + 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() Claiming period has already ended"));
        giftContract.claimGift(1);
    }

    /// @notice Test that attempts to claim any token id after claiming ends revert.
    function testFuzz_gifts_claimGift_ClaimingEnded(uint256 tokenId) public {
        // Nobody can claim gifts for any token id after claiming ends
        vm.warp(claimEnd + 1);
        vm.expectRevert(bytes("Gifts.sol::claimGift() Claiming period has already ended"));
        giftContract.claimGift(tokenId);
    }


    // ---------------
    // Owner Functions
    // ---------------

    // --- initializeTokens() ---

    /// @notice Test that tokens are initialized correctly.
    function test_gifts_initializeTokens_Initialized() public {
        // Verify contract state reflects tokens are not initialized
        assert(!giftContract.initialized());
        uint256[] memory beforeInit = giftContract.getTokens();
        assertEq(beforeInit.length, 0);

        // Owner can initialize tokens, filling it with token ids 1-10000
        // Gifts should emit TokensInitialized() event after successful initialization
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit TokensInitialized();
        giftContract.initializeTokens();

        // Verify contract state reflects tokens are initialized
        assert(giftContract.initialized());
        uint256[] memory afterInit = giftContract.getTokens();
        assertEq(afterInit.length, 10_000);
        assertEq(afterInit[0], 1);
        assertEq(afterInit[9999], 10_000);
    }

    /// @notice Test that attempts to initialize tokens more than once revert.
    function test_gifts_initializeTokens_AlreadyInitialized() public {
        assert(!giftContract.initialized());
        uint256[] memory beforeInit = giftContract.getTokens();
        assertEq(beforeInit.length, 0);

        // Owner can initialize tokens, filling it with token ids 1-10000
        giftContract.initializeTokens();

        assert(giftContract.initialized());
        uint256[] memory afterInit = giftContract.getTokens();
        assertEq(afterInit.length, 10_000);

        // Owner cannot initialize tokens once it has already been initialized
        vm.expectRevert(bytes("Gifts.sol::initializeTokens() Tokens array already initialized"));
        giftContract.initializeTokens();
    }

    // --- requestEntropy() ---

    /// @notice Test that randomness can be requested and fulfilled using VRF.
    function testFuzz_gifts_requestEntropy_Requested(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy from Chainlink VRF
        uint256 requestId = giftContract.requestEntropy();
        assert(!giftContract.fulfilled());
        assertEq(giftContract.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(giftContract), words);
        assert(giftContract.fulfilled());
        assertEq(giftContract.entropy(), word);
    }

    /// @notice Test that randomness can only be fulfilled once without reverting 
    /// in case multiple requests are made and multiple fulfillments received.
    function testFuzz_gifts_requestEntropy_MultipleRequests(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy multiple times from Chainlink VRF
        uint256 requestIdOne = giftContract.requestEntropy();
        uint256 requestIdTwo = giftContract.requestEntropy();
        assert(!giftContract.fulfilled());
        assertEq(giftContract.entropy(), 0);

        // Mock VRF response with entropy from Chainlink and fulfill request one
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdOne, address(giftContract), words);
        assert(giftContract.fulfilled());
        assertEq(giftContract.entropy(), word);

        // The fulfillRandomWords function will not revert/ update entropy when fulfilling request two
        words[0] = uint256(bytes32(0xdbdb4ee44eca0cfa2a2479a529fd35fb4a40df14358c724b6d7fb834aef0288f));
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdTwo, address(giftContract), words);

        // Entropy should not change if/when another request is "fulfilled"
        assert(giftContract.fulfilled());
        assertEq(giftContract.entropy(), word);
    }

    /// @notice Test that attempts to request randomness entropy fulfilled revert. 
    function testFuzz_gifts_requestEntropy_AlreadyFulfilled(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Owner can request entropy from Chainlink VRF
        uint256 requestId = giftContract.requestEntropy();
        assert(!giftContract.fulfilled());
        assertEq(giftContract.entropy(), 0);

        // Mock VRF response with entropy "from" Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(giftContract), words);
        assert(giftContract.fulfilled());
        assertEq(giftContract.entropy(), word);

        // Owner cannot request entropy again since it was already fulfilled
        vm.expectRevert(bytes("Gifts.sol::requestEntropy() Entropy has already been fulfilled"));
        giftContract.requestEntropy();
    }

    // --- shuffleTokens() ---

    /// @notice Test that shuffling tokens is successful after initializing and getting entropy.
    // gas = 13430577 uint256
    function test_gifts_shuffleTokens_Shuffled() public {
        // Owner can initialize tokens and get entropy
        setupTokens();
        setupEntropy(entropy);

        // Owner can shuffle tokens if not already shuffled
        // Gifts should emit TokensShuffled() event after a successful shuffle
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit TokensShuffled();
        giftContract.shuffleTokens();
        assert(giftContract.shuffled());
    }

    /// @notice Test that attempts to shuffle tokens before initialization revert.
    function test_gifts_shuffleTokens_NotInitialized() public {
        assert(!giftContract.initialized());
        assertEq(giftContract.getTokens().length, 0);

        // Owner cannot be shuffle tokens if it has not been initialized
        vm.expectRevert(bytes("Gifts.sol::shuffleTokens() Tokens array has not been initialized"));
        giftContract.shuffleTokens();
    }

    /// @notice Test that attempts to shuffle tokens before getting entropy revert.
    function test_gifts_shuffleTokens_NoEntropy() public {
        // Owner can initialize tokens without entropy
        setupTokens();
        assert(!giftContract.fulfilled());
        assertEq(giftContract.entropy(), 0);

        // Owner cannot shuffle tokens without entropy
        vm.expectRevert(bytes("Gifts.sol::shuffleTokens() Entropy for shuffle has not been fulfilled"));
        giftContract.shuffleTokens();
    }

    /// @notice Test that attempts to shuffle tokens more than once revert.
    function test_gifts_shuffleTokens_AlreadyShuffled() public {
        // Owner can intitialize tokens, get entropy, and shuffle tokens
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();

        // Owner cannot shuffle tokens again since it was already shuffled
        vm.expectRevert(bytes("Gifts.sol::shuffleTokens() Tokens have already been shuffled"));
        giftContract.shuffleTokens();
    }


    // --- setTokenGiftData() ---

    /// @dev setTokenGiftData() does not need to be restricted outside of shuffle status.
    /// Setting gift data for the tokens is the same process every time and will not affect
    /// anything unless the tokens are not shuffled.

    /// @notice Test that gift data is set correctly for token ids at every index.
    // gas = 56918141 uint256
    function test_gifts_setTokenGiftData_Set() public {
        // Owner can initialize tokens, get entropy, and shuffle tokens
        setupTokens();
        setupEntropy(entropy);
        setupShuffle();
        
        // Owner can set token gift data after shuffling tokens
        // Gifts should emit GiftDataSet() event after gift data is set for all token ids
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit GiftDataSet();
        giftContract.setTokenGiftData();

        uint256[] memory tokens = giftContract.getTokens();

        for(uint i = 0; i < 10000; ++i) {
            // Get expected tier for an index
            (uint8 tokenTier,) = giftDataForIndex(i);

            // Verify gift tier of token id against expected gift tier
            assertEq(uint8(giftContract.getTier(tokens[i])), tokenTier);
        }
    }

    /// @notice Test that gift data is set correctly for token ids at random indexes.
    function testFuzz_gifts_setTokenGiftData_Set(uint256 index, uint256 word) public {
        index = bound(index, 0, 9999);

        // Owner can initialize tokens, get entropy, shuffle tokens, and set data
        setupTokens();
        setupEntropy(word);
        setupShuffle();

        // Owner can set token gift data once tokens have been shuffled
        // Gifts should emit GiftDataSet() event after gift data is set for all token ids
        vm.expectEmit(true, true, true, true, address(giftContract));
        emit GiftDataSet();
        giftContract.setTokenGiftData();

        // Verify gift tier of token id against expected gift tier
        (uint8 tokenTier,) = giftDataForIndex(index);
        uint256 tokenId = giftContract.tokens(index);
        assertEq(uint8(giftContract.getTier(tokenId)), tokenTier);
    }

    /// @notice Test that attempts to set token gift data before initialization revert.
    function test_gifts_setTokenGiftData_NotInitialized() public {
        assert(!giftContract.initialized());

        // Owner cannot set gift data if tokens has not been initialized
        vm.expectRevert(bytes("Gifts.sol::setTokenGiftData() Tokens array must be shuffled before assigning gift tiers"));
        giftContract.setTokenGiftData();
    }

    /// @notice Test that attempts to set token gift data before getting entropy revert.
    function test_gifts_setTokenGiftData_NoEntropy() public {
        assert(!giftContract.fulfilled());

        // Owner cannot set gift data without entropy
        vm.expectRevert(bytes("Gifts.sol::setTokenGiftData() Tokens array must be shuffled before assigning gift tiers"));
        giftContract.setTokenGiftData();
    }

    /// @notice Test that attempts to set token gift data before shuffling revert.
    function test_gifts_setTokenGiftData_NotShuffled() public {
        // Owner can initialize tokens and get entropy without shuffling
        setupTokens();
        setupEntropy(entropy);
        assert(!giftContract.shuffled());

        // Owner cannot set gift data without shuffling tokens
        vm.expectRevert(bytes("Gifts.sol::setTokenGiftData() Tokens array must be shuffled before assigning gift tiers"));
        giftContract.setTokenGiftData();
    }
}