// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "./Utility.sol";
import "../src/NFT.sol";
import "../src/Rewards.sol";
import "./utils/VRFCoordinatorV2Mock.sol";

contract RewardsTest is Test, Utility {
    // State variable for contract.
    NFT raftToken;
    Rewards reward;
    VRFCoordinatorV2Mock vrfCoordinator;

    function setUp() public {
        createActors();
        setUpTokens();

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection
            "RT",                               // Symbol of collection
            address(crc),                       // Circle account
            address(sig),                       // Multi-signature wallet
            bytes32(0x0)                        // Whitelist root
        );

        // Initialize mock VRF Coordinator contract with new subscription and funding
        vrfCoordinator = new VRFCoordinatorV2Mock(100000, 100000);
        uint64 subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether);
        
        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                               // USDC Address.
            address(raftToken),                 // NFT Address.
            address(vrfCoordinator),            // Mock VRF Address.
            (block.timestamp + 86400)           // Mint start timestamp = time of deployment + 1 day
        ); 

        // Update the subscription and add the Rewards contract as a consumner 
        reward.updateSubId(subscriptionId);
        vrfCoordinator.addConsumer(subscriptionId, address(reward));
    }

    /// @notice Test intial values set in the constructor.
    function test_rewards_DeployedState() public {
        assertEq(address(reward.stableCurrency()), address(USDC));
        assertEq(address(reward.nftContract()), address(raftToken));
        assertEq(address(reward.vrfCoordinatorV2()), address(vrfCoordinator));
    }

    /// @notice Test that randomness requests and fulfillment are successful using VRF.
    function test_rewards_requestEntropy_RequestFuzzing(uint256 word) public {
        // Mock entropy that Chainlink provides, word is a random uint256 from Forge's fuzzer
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        assert(!reward.entropyFulfilled());

        // Request entropy from Chainlink VRF
        uint256 requestId = reward.requestEntropy();
        assert(!reward.entropyFulfilled());
        assertEq(reward.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), word);
    }

    /// @notice Test that randomness is can only be fulfilled once without reverting in
    /// the case that multiple requests were made and multiple fulfillments received.
    function test_rewards_requestEntropy_MultipleRequestsFuzzing(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Request entropy from Chainlink VRF
        uint256 requestIdOne = reward.requestEntropy();
        uint256 requestIdTwo = reward.requestEntropy();
        assert(!reward.entropyFulfilled());
        assertEq(reward.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdOne, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), word);

        // The fulfillRandomWords function will not revert and only fulfill entropy once
        words[0] = uint256(bytes32(0xdbdb4ee44eca0cfa2a2479a529fd35fb4a40df14358c724b6d7fb834aef0288f));
        vrfCoordinator.fulfillRandomWordsWithOverride(requestIdTwo, address(reward), words);

        // Entropy should not change if/when another request is "fulfilled"
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), word);
    }

    /// @notice Test that requests for randomness revert if entropy is already fulfilled. 
    function test_rewards_requestEntropy_AlreadyFulfilledFuzzing(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        // Request entropy from Chainlink VRF
        uint256 requestId = reward.requestEntropy();
        assert(!reward.entropyFulfilled());
        assertEq(reward.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), word);

        // Entropy cannot be requested again since it has already been fulfilled
        vm.expectRevert(bytes("Gifts.sol::requestEntropy() Entropy has already been fulfilled"));
        reward.requestEntropy();
    }

    /// @notice Test that the tokens array is initialized correctly.
    function test_rewards_initializeTokens_Init() public {
        // Ensure that state variables and length reflect the array is not initialized
        assert(!reward.initialized());
        uint256[] memory beforeInit = reward.getTokens();
        assertEq(beforeInit.length, 0);

        // Initialize the array by filling it with token ids 1 through 10000
        reward.initializeTokens();

        // Ensure that state variables and length reflect the array has been initialized
        uint256[] memory afterInit = reward.getTokens();
        assertEq(afterInit.length, 10_000);
        assert(reward.initialized());
    }

    /// @notice Test that the tokens array is shuffled successfully when entropy is fulfilled.
    function test_rewards_shuffleTokens_EntropyFulfilled() public {
        reward.initializeTokens();
        assert(reward.initialized());

        // Request entropy from Chainlink VRF
        uint256 requestId = reward.requestEntropy();
        assert(!reward.entropyFulfilled());

        // Mock entropy that Chainlink provides
        uint256[] memory words = new uint256[](1);
        uint256 entropy = uint256(bytes32(0x01e4928c21c69891d8b1c3520a35b74f6df5f28a867f30b2cd9cd81a01b3aabd));
        words[0] = entropy;

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), entropy);

        // Shuffle the initialized array using the entropy
        reward.shuffleTokens();
        assert(reward.shuffled());

        // Return shuffled array
        reward.getTokens();
    }

}
