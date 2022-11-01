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
    uint256[] ids;

    function setUp() public {
        createActors();
        setUpTokens();

        // Initialize NFT contract.
        raftToken = new NFT(
            "RaftToken",                        // Name of collection.
            "RT",                               // Symbol of collection.
            address(crc),
            address(sig)
        );

        vrfCoordinator = new VRFCoordinatorV2Mock(100000, 100000);
        uint64 subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 100 ether);
        
        // Initialize Rewards contract.
        reward = new Rewards(
            USDC,                               // USDC Address.
            address(raftToken),                 // NFT Address.
            address(vrfCoordinator)             // Mock VRF Address.
        ); 
        reward.setSubscriptionId(subscriptionId);
        vrfCoordinator.addConsumer(subscriptionId, address(reward));
    }

    /// @notice tests intial values set in the constructor.
    function test_rewards_init_state() public {
        assertEq(reward.stableCurrency(), USDC);
        assertEq(reward.nftContract(), address(raftToken));
        //emit log_array(reward.getFisherArray());

        reward.setFisherArray();
        uint256[] memory array = reward.getFisherArray();
        assertEq(array.length, 10_000);
        //emit log_array(array);
    }

    function test_rewards_RequestRandomness(uint256 word) public {
        uint256[] memory words = new uint256[](1);
        words[0] = word;

        assertEq(reward.entropyId(), 0);
        assert(!reward.entropySet());

        // request entropy from Chainlink VRF
        uint256 requestId = reward.setEntropy();
        assertEq(requestId, reward.entropyId());
        assert(!reward.entropySet());

        // Mock VRF response once entropy is received from Chainlink
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropySet());
        assertEq(reward.entropy(), word);
    }


    function test_rewards_SetArray() public {
       reward.setFisherArray();
    }

    function test_rewards_ShuffleArray() public {
        reward.setFisherArray();

        // request entropy from Chainlink VRF
        uint256 requestId = reward.setEntropy();
        assertEq(requestId, reward.entropyId());
        assert(!reward.entropySet());

        // Mock VRF response once entropy is received from Chainlink
        uint256[] memory words = new uint256[](1);
        uint256 entropy = uint256(bytes32(0x01e4928c21c69891d8b1c3520a35b74f6df5f28a867f30b2cd9cd81a01b3aabd));
        words[0] = entropy;
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(reward), words);
        assert(reward.entropySet());
        assertEq(reward.entropy(), entropy);

        reward.shuffle();
        reward.getFisherArray();
    }

}
