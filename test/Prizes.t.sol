// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Utility } from "./utils/Utility.sol";
import { VRFCoordinatorV2Mock } from "./utils/VRFCoordinatorV2Mock.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { NFT } from "../src/NFT.sol";
import { Prizes } from "../src/Prizes.sol";

/// @author Andrew Thomas
/// @notice Unit tests for Prizes contract.
contract PrizesTest is Utility {
    // State variables for contracts.
    Prizes internal prizeContract;
    NFT internal nftContract;
    VRFCoordinatorV2Mock internal vrfCoordinator;

    // State variables for claiming and VRF.
    uint256 internal claimStart;
    uint256 internal claimEnd;
    uint256[] internal entropy = [uint256(uint160(address(this)))];
    uint64 internal subId;

    // State variables for number of prizes per tier.
    uint256 constant NUM_PRIZES_ONE = 1;
    uint256 constant NUM_PRIZES_TWO = 10;
    uint256 constant NUM_PRIZES_THREE = 100;
    uint256 constant NUM_PRIZES_FOUR = 400;
    uint256 constant NUM_PRIZES_FIVE = 2000;
    uint256 constant NUM_PRIZES_SIX = 7489;

    // Mock event the Prizes contract will emit.
    event PrizeClaimed(
        address indexed recipient, 
        uint256 indexed id,          
        uint256 level,
        uint256 prize
    );

    function setUp() public {
        createActors();

        // Initialize mock VRF coordinator contract with subscription and funding
        vrfCoordinator = new VRFCoordinatorV2Mock(100000, 100000);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 100 ether);

        // Initialize NFT contract
        nftContract = new NFT(
            "RaftToken",                        // Collection name
            "RT",                               // Collection symbol
            "ipfs::/Unrevealed/",               // Unrevealed URI
            bytes32(0x0),                       // Whitelist root
            address(vrfCoordinator),            // Mock VRF coordinator
            sig                                 // Multi-signature wallet
        );

        // Update subscription and add the NFT contract as a consumer
        nftContract.updateSubId(subId);
        vrfCoordinator.addConsumer(subId, address(nftContract));
        
        // Initialize Prizes contract
        prizeContract = new Prizes(
            address(nftContract),               // NFT address
            USDC,                               // USDC ERC20 address
            sig                                 // Multi-signature wallet
        );
        
        // Simulate preparation for Prizes contract deployment:
        // Mint all tokens
        nftContract.updatePublicMint(true);
        mintTokens(address(nftContract), 10000);

        // Finalize mint
        nftContract.finalizeMint();

        // Request and fulfill entropy
        uint256 requestId = nftContract.requestEntropy();
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(nftContract), entropy);

        // Shuffle levels
        nftContract.shuffleLevels();

        // Start claim period and assign start and end
        // 01/01/3005 12:00 AM
        vm.warp(32661471600);
        prizeContract.setClaimPeriod();
        claimStart = prizeContract.claimStart();
        claimEnd = prizeContract.claimEnd();
    }


    // --------------
    // Deployed State
    // --------------

    /// @notice Test constants and values assigned in the constructor once deployed.
    function test_prizes_DeployedState() public {
        assertEq(address(prizeContract.nftContract()), address(nftContract));
        assertEq(address(prizeContract.stableCurrency()), USDC);
        assertEq(prizeContract.multiSig(), sig);
        // assertEq(prizeContract.circleAccount(), crc);

        assertEq(prizeContract.TIER_ONE_LEVELS(), 1);
        assertEq(prizeContract.TIER_TWO_LEVELS(), 11);
        assertEq(prizeContract.TIER_THREE_LEVELS(), 111);
        assertEq(prizeContract.TIER_FOUR_LEVELS(), 511);
        assertEq(prizeContract.TIER_FIVE_LEVELS(), 2511);

        assertEq(prizeContract.STABLE_DECIMALS(), USD);
        assertEq(prizeContract.TIER_ONE_PRIZE(), 0);
        assertEq(prizeContract.TIER_TWO_PRIZE(), 10000 * USD);
        assertEq(prizeContract.TIER_THREE_PRIZE(), 1000 * USD);
        assertEq(prizeContract.TIER_FOUR_PRIZE(), 500 * USD);
        assertEq(prizeContract.TIER_FIVE_PRIZE(), 250 * USD);
        assertEq(prizeContract.TIER_SIX_PRIZE(), 0);

        assertEq(prizeContract.claimStart(), 32661471600);
        assertEq(prizeContract.claimEnd(), 32661471600 + 7 days);
    }

    /// @notice Test default values for token ids within prizeInfo mapping.
    function testFuzz_prizes_prizeInfo_DeployedState(uint256 tokenId) public {
        (address recipient, bool claimed) = prizeContract.prizeInfo(tokenId);

        // Verify gift data values against expected default values
        assertEq(recipient, address(0));
        assert(!claimed);
    }


    // ----------------
    // Public Functions
    // ----------------

    // --- prizeOf() ---
    /// @dev Number of integers between two integers with half open interval [a,b) is b - a

    /// @notice Test that prizes returned for tier one token levels are correct.
    function test_prizes_prizeOf_TierOne() public {
        // Tier one levels stop at this constant, tier two levels start after
        uint256 tierOneLevel = prizeContract.TIER_ONE_LEVELS();

        // Verify prize returned for the tier one level
        assertEq(prizeContract.TIER_ONE_PRIZE(), prizeContract.prizeOf(tierOneLevel));
    }

    /// @notice Test that prizes returned for tier two token levels are correct.
    function test_prizes_prizeOf_TierTwo() public {
        // First tier two level starts after this constant
        uint256 tierOneLevel = prizeContract.TIER_ONE_LEVELS();
        // Last tier two level
        uint256 level = prizeContract.TIER_TWO_LEVELS();

        // Verify number of prizes
        assertEq(level - tierOneLevel, NUM_PRIZES_TWO);

        // Verify prize returned for each tier two level, from last to first
        uint256 prize = prizeContract.TIER_TWO_PRIZE();
        while(level > tierOneLevel) {
            assertEq(prize, prizeContract.prizeOf(level--));
        }
    }

    /// @notice Test that prizes returned for tier three token levels are correct.
    function test_prizes_prizeOf_TierThree() public {        
        // First tier three level starts after this constant
        uint256 tierTwoLevel = prizeContract.TIER_TWO_LEVELS();
        // Last tier three level
        uint256 level = prizeContract.TIER_THREE_LEVELS();

        // Verify number of prizes
        assertEq(level - tierTwoLevel, NUM_PRIZES_THREE);

        // Verify prize returned for each tier three level, from last to first
        uint256 prize = prizeContract.TIER_THREE_PRIZE();
        while(level > tierTwoLevel) {
            assertEq(prize, prizeContract.prizeOf(level--));
        }
    }

    /// @notice Test that prizes returned for tier four token levels are correct.
    function test_prizes_prizeOf_TierFour() public {
        // First tier four level starts after this constant
        uint256 tierThreeLevel = prizeContract.TIER_THREE_LEVELS();
        // Last tier four level
        uint256 level = prizeContract.TIER_FOUR_LEVELS();

        // Verify number of prizes
        assertEq(level - tierThreeLevel, NUM_PRIZES_FOUR);
        
        // Verify prize returned for each tier four level, from last to first
        uint256 prize = prizeContract.TIER_FOUR_PRIZE();
        while(level > tierThreeLevel) {
            assertEq(prize, prizeContract.prizeOf(level--));
        }
    }

    /// @notice Test that prizes returned for tier five token levels are correct.
    function test_prizes_prizeOf_TierFive() public {
        // First tier five level starts after this constant
        uint256 tierFourLevel = prizeContract.TIER_FOUR_LEVELS();
        // Last tier five level
        uint256 level = prizeContract.TIER_FIVE_LEVELS();

        // Verify number of prizes against expected
        assertEq(level - tierFourLevel, NUM_PRIZES_FIVE);

        // Verify prize returned for each tier five level, from last to first
        uint256 prize = prizeContract.TIER_FIVE_PRIZE();
        while(level > tierFourLevel) {
            assertEq(prize, prizeContract.prizeOf(level--));
        }
    }

    /// @notice Test that prizes returned for tier six token levels are correct.
    function test_prizes_prizeOf_TierSix() public {
        // First tier six level starts after this constant
        uint256 tierFiveLevel = prizeContract.TIER_FIVE_LEVELS();
        // Last tier six level
        uint256 level = nftContract.currentTokenId();

        // Verify number of prizes against expected
        assertEq(level - tierFiveLevel, NUM_PRIZES_SIX);

        // Verify prize returned for each tier six level, from last to first
        uint256 prize = prizeContract.TIER_SIX_PRIZE();
        while(level > tierFiveLevel) {
            assertEq(prize, prizeContract.prizeOf(level--));
        }
    }


    // ------------------
    // External Functions
    // ------------------

    // --- claimPrize() ---
    /// @dev Claim test cases must be run with an appropriate rpc url!
    /// @dev Valid token ids and levels include [1,10000] (with total supply minted)

    /// @notice Test that the prizes can be claimed for all minted tokens and respective levels.
    function testFuzz_prizes_claimPrize_Claimed(uint256 tokenId) public {
        vm.warp(claimStart + 1);

        // Prizes cannot be claimed for token ids that were not minted
        if(tokenId < 1 || tokenId > 10000) {
            vm.expectRevert("NOT_MINTED");
            prizeContract.claimPrize(tokenId);
            return;
        }

        // Get the owner, level, and prize of a token id
        address owner = nftContract.ownerOf(tokenId);
        uint256 level = nftContract.levelOf(tokenId);
        uint256 prize = prizeContract.prizeOf(level);

        // Give contract the prize amount in stable currency and get initial balances
        IERC20 token = prizeContract.stableCurrency();
        deal(address(token), address(prizeContract), prize);
        uint256 initialBalanceContract = token.balanceOf(address(prizeContract));
        uint256 initialBalanceOwner = token.balanceOf(owner);

        // An owner can claim the prize associated with their token
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(prizeContract));
        emit PrizeClaimed(owner, tokenId, level, prize);
        uint256 prizeReceived = prizeContract.claimPrize(tokenId);

        // Verify prize amount, status, recipient, and balances are updated correctly
        assert(prizeContract.prizeStatus(tokenId));
        assertEq(prizeContract.prizeRecipient(tokenId), owner);
        assertEq(prizeReceived, prize);
        assertEq(token.balanceOf(owner), initialBalanceOwner + prize);
        assertEq(token.balanceOf(address(prizeContract)), initialBalanceContract - prize);
    }

    /// @notice Test that attempts to claim the prize for a token more than once revert.
    function testFuzz_prizes_claimPrize_AlreadyClaimed(uint256 tokenId) public {
        vm.warp(claimStart + 1);

        // Prizes cannot be claimed for token ids that were not minted
        if(tokenId < 1 || tokenId > 10000) {
            vm.expectRevert("NOT_MINTED");
            prizeContract.claimPrize(tokenId);
            return;
        }

        // Get the owner, level, and prize of a token id
        address owner = nftContract.ownerOf(tokenId);
        uint256 level = nftContract.levelOf(tokenId);
        uint256 prize = prizeContract.prizeOf(level);

        // Give contract the prize amount in stable currency and get initial balances
        IERC20 token = prizeContract.stableCurrency();
        deal(address(token), address(prizeContract), prize);
        uint256 initialBalanceContract = token.balanceOf(address(prizeContract));
        uint256 initialBalanceOwner = token.balanceOf(owner);

        // An owner can claim the prize associated with their token
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true, address(prizeContract));
        emit PrizeClaimed(owner, tokenId, level, prize);
        uint256 prizeReceived = prizeContract.claimPrize(tokenId);

        // Verify prize amount, status, recipient, and balances are updated correctly
        assert(prizeContract.prizeStatus(tokenId));
        assertEq(prizeContract.prizeRecipient(tokenId), owner);
        assertEq(prizeReceived, prize);
        assertEq(token.balanceOf(owner), initialBalanceOwner + prize);
        assertEq(token.balanceOf(address(prizeContract)), initialBalanceContract - prize);

        // An owner cannot claim the prize more than once
        vm.expectRevert("Prizes.sol::claimPrize() Prize already claimed for the token");
        prizeContract.claimPrize(tokenId);
        vm.stopPrank();
    }

    /// @notice Test that attempts to claim prizes without enough stable currency revert.
    function testFuzz_prizes_claimPrize_InsufficientBalance(uint256 tokenId) public {
        vm.warp(claimStart + 1);

        // Prizes cannot be claimed for token ids that were not minted
        if(tokenId < 1 || tokenId > 10000) {
            vm.expectRevert("NOT_MINTED");
            prizeContract.claimPrize(tokenId);
            return;
        }

        // Get the owner, level, and prize of a token id
        address owner = nftContract.ownerOf(tokenId);
        uint256 level = nftContract.levelOf(tokenId);
        uint256 prize = prizeContract.prizeOf(level);

        // Transfers only occur when prize is nonzero
        if(prize != 0) {
            // Verify the state and balance of the contract
            assert(!prizeContract.prizeStatus(tokenId));
            assertEq(prizeContract.prizeRecipient(tokenId), address(0));
            IERC20 token = prizeContract.stableCurrency();
            assertEq(token.balanceOf(address(prizeContract)), 0);

            // An owner cannot claim if the contract balance cannot cover the prize of their token
            vm.prank(owner);
            vm.expectRevert("Prizes.sol::claimPrize() Insufficient balance for prize");
            prizeContract.claimPrize(tokenId);
            return;
        }

        // Otherwise claiming for zero prizes is successful
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(prizeContract));
        emit PrizeClaimed(owner, tokenId, level, prize);
        uint256 prizeReceived = prizeContract.claimPrize(tokenId);

        assert(prizeContract.prizeStatus(tokenId));
        assertEq(prizeContract.prizeRecipient(tokenId), owner);
        assertEq(prizeReceived, prize);
    }

    /// @notice Test that attempts to claim prizes outside of the token owner revert.
    function test_prizes_claimPrize_InvalidOwner() public {
        vm.warp(claimStart + 1);

        // Joe cannot claim prizes for a token that he does not own
        vm.prank(address(joe));
        vm.expectRevert("Prizes.sol::claimPrize() Address is not the token owner");
        prizeContract.claimPrize(1);
    }

    /// @notice Test that attempts to claim before claiming starts revert.
    function test_prizes_claimPrize_Pending() public {        
        // Nobody can claim prizes for any token id before claim start
        vm.warp(claimStart - 1);
        vm.expectRevert("Prizes.sol::claimPrize() Claiming period has not started");
        prizeContract.claimPrize(1);
    }

    /// @notice Test that attempts to claim any token id before claiming starts revert.
    function testFuzz_prizes_claimPrize_Pending(uint256 tokenId) public {
        // Nobody can claim prizes for any token id before the claim start
        vm.warp(claimStart - 1);
        vm.expectRevert("Prizes.sol::claimPrize() Claiming period has not started");
        prizeContract.claimPrize(tokenId);
    }

    /// @notice Test that attempts to claim after claiming ends revert.
    function test_prizes_claimPrize_Ended() public {
        // Nobody can claim prizes for any token id after claim end
        vm.warp(claimEnd + 1);
        vm.expectRevert("Prizes.sol::claimPrize() Claiming period has already ended");
        prizeContract.claimPrize(1);
    }

    /// @notice Test that attempts to claim any token id after claiming ends revert.
    function testFuzz_prizes_claimPrize_Ended(uint256 tokenId) public {
        // Nobody can claim prizes for any token id after claim end
        vm.warp(claimEnd + 1);
        vm.expectRevert("Prizes.sol::claimPrize() Claiming period has already ended");
        prizeContract.claimPrize(tokenId);
    }


    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Test that the onlyOwner modifier reverts unless call is from the owner.
    /// @dev Must be run with an appropriate rpc url!
    function test_prizes_OnlyOwner() public {
        // Transfer ownership to the developer actor
        prizeContract.transferOwnership(address(dev));

        // Setup new addresses and balances
        address newSig = makeAddr("New MultiSig Wallet");
        deal(USDC, address(prizeContract), 100 * USD);

        // Joe cannot call functions with onlyOwner modifier
        assert(!joe.try_setClaimPeriod(address(prizeContract)));
        assert(!joe.try_overrideClaimEnd(address(prizeContract), 0));
        assert(!joe.try_updateMultiSig(address(prizeContract), newSig));
        assert(!joe.try_withdrawERC20(address(prizeContract), USDC));

        // Developer can call function with onlyOwner modifier
        assert(dev.try_setClaimPeriod(address(prizeContract)));
        assert(dev.try_overrideClaimEnd(address(prizeContract), 0));
        assert(dev.try_updateMultiSig(address(prizeContract), newSig));
        assert(dev.try_withdrawERC20(address(prizeContract), USDC));
    }

    // should probably make this settable once..? not sure of legalities.
    /// @notice Test that claim period is set to a 7 day period starting at the current block's timestamp.
    function test_prizes_setClaimPeriod_Set() public {
        // 12/31/3004 11:59 PM
        vm.warp(32661471599);

        // Owner can set the claim period to end 7 days from the current block's timestamp
        prizeContract.setClaimPeriod();
        assertEq(prizeContract.claimStart(), 32661471599);
        assertEq(prizeContract.claimEnd(), 32661471599 + 7 days);
    }

    // should probably establish reasonable bounds so that the prizes don't go forever.
    /// @notice Test that the claim end timestamp can be overriden.
    function testFuzz_prizes_overrideClaimEnd_Overridden(uint256 timestamp) public {
        // Owner can set the claim period to end 7 days from the current block's timestamp
        prizeContract.setClaimPeriod();
        assertEq(prizeContract.claimEnd(), block.timestamp + 7 days);

        // Owner can override the end of the claim period to any timestamp value
        prizeContract.overrideClaimEnd(timestamp);
        assertEq(prizeContract.claimEnd(), timestamp);
    }

    // --- updateMultiSig() ---

    /// @notice Test that the multisig wallet address can be updated to a new address.
    function test_prizes_updateMultiSig_Updated() public {
        // Verify multisig wallet state reflects deployment
        assertEq(prizeContract.multiSig(), sig);
        
        // Owner can update multisig to a new address
        address newSig = makeAddr("New MultiSig Wallet");
        prizeContract.updateMultiSig(newSig);

        // Verify multisig wallet reflects changes
        assertEq(prizeContract.multiSig(), newSig);
    }

    /// @notice Test that updating the multisig wallet to the zero address reverts.
    function test_prizes_updateMultiSig_ZeroAddress() public {
        // Verify multisig wallet state reflects deployment
        assertEq(prizeContract.multiSig(), sig);

        // Owner cannot update multisig wallet to the zero address
        vm.expectRevert("Prizes.sol::updateMultiSig() Address cannot be zero address");
        prizeContract.updateMultiSig(address(0));
    }

    // --- withdrawERC20() ---
    /// @dev Withdraw test cases must be run with an appropriate rpc url!

    /// @notice Test that valid ERC20 token amounts are withdrawn to multi-sig.
    function testFuzz_prizes_withdrawERC20_Withdrawn(uint256 amount) public {
        if(amount < 1) {
            return;
        }

        // Use LINK as an example ERC20 token
        IERC20 token = IERC20(LINK);
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(prizeContract)), 0);

        // Simulate contract receiving an amount of LINK
        deal(address(token), address(prizeContract), amount);

        // Owner can withdraw contract token balance to multi-sig wallet
        prizeContract.withdrawERC20(address(token));
        assertEq(token.balanceOf(sig), amount);
        assertEq(token.balanceOf(address(prizeContract)), 0);
    }

    /// @notice Test that stable currency token amounts are withdrawn to multi-sig.
    function testFuzz_prizes_withdrawERC20_WithdrawStable(uint256 amount) public {
        if(amount < 1) {
            return;
        }

        // Use USDC which is the stable currency of the contract
        IERC20 token = prizeContract.stableCurrency();
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(prizeContract)), 0);

        // Simulate contract receiving an amount of USDC
        deal(address(token), address(prizeContract), amount);

        // Owner can withdraw contract token balance to multi-sig wallet
        prizeContract.withdrawERC20(address(token));
        assertEq(token.balanceOf(sig), amount);
        assertEq(token.balanceOf(address(prizeContract)), 0);
    }

    /// @notice Test that ERC20 withdrawl attempts from the zero address revert.
    function test_prizes_withdrawERC20_ZeroAddress() public {
        // Owner cannot withdraw from the zero address
        vm.expectRevert("Prizes.sol::withdrawERC20() Address cannot be zero address");
        prizeContract.withdrawERC20(address(0));
    }

    /// @notice Test that ERC20 withdrawl attempts when the contract balance is zero revert.
    function test_prizes_withdrawERC20_InsufficientBalance() public {
        // Use LINK as an example ERC20 token
        IERC20 token = IERC20(LINK);
        assertEq(token.balanceOf(sig), 0);
        assertEq(token.balanceOf(address(prizeContract)), 0);

        // Owner cannot withdraw contract token balance when the balance is zero
        vm.expectRevert("Prizes.sol::withdrawERC20() Insufficient token balance");
        prizeContract.withdrawERC20(address(token));
    }
}