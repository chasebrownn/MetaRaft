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

    // // State variables for whitelist.
    // address[] public whitelist;
    // bytes32[] public tree;
    bytes32 root;

    function setUp() public {
        createActors();
        setUpTokens();

        // // Assign array of 20 whitelisted addresses + 20 bytes32 encoded addresses to construct merkle tree.
        // (whitelist, tree) = createWhitelist(20);
        // // Assign root of merkle tree constructed with Murky helper contracts.
        // root = merkle.getRoot(tree);

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection.
            "RT",                               // Symbol of collection.
            "Unrevealed",                       // Unrevealed URI.
            address(crc),                       // Circle Account.
            address(sig),                       // Multi-signature wallet.
            root                                // Whitelist root.
        );

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
        reward.updateSubId(subscriptionId);
        vrfCoordinator.addConsumer(subscriptionId, address(reward));
    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_init_state() public {
        assertEq(address(reward.stableCurrency()), address(USDC));
        assertEq(address(reward.nftContract()), address(raftToken));
        //emit log_array(reward.getTokens());
    }

    function test_rewards_RequestRandomness(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        assert(!reward.entropyFulfilled());

        // request entropy from Chainlink VRF
        uint256 requestId = reward.requestEntropy();
        assert(!reward.entropyFulfilled());
        assertEq(reward.entropy(), 0);

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), word);
    }


    function test_rewards_InitializeTokens() public {
       reward.initializeTokens();

        uint256[] memory array = reward.getTokens();
        assertEq(array.length, 10_000);
        emit log_array(array);
    }

    function test_rewards_ShuffleArray() public {
        reward.initializeTokens();

        // request entropy from Chainlink VRF
        uint256 requestId = reward.requestEntropy();
        assert(!reward.entropyFulfilled());

        // Mock VRF response once entropy is received from Chainlink
        uint256[] memory words = new uint256[](1);
        uint256 entropy = uint256(bytes32(0x01e4928c21c69891d8b1c3520a35b74f6df5f28a867f30b2cd9cd81a01b3aabd));

        words[0] = entropy;
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropyFulfilled());
        assertEq(reward.entropy(), entropy);

        reward.shuffleTokens();
        reward.getTokens();
    }

}
