// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Actor } from "./Actor.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

contract Utility is Test {
    // ----------------------------
    // Ethereum Contract References
    // ----------------------------

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant LINK = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;

    // --------------
    // Primary Actors
    // --------------

    Actor dev = new Actor();                    // Developer wallet
    Actor joe = new Actor();                    // Average joe user
    address sig = makeAddr("MultiSig Wallet");  // MultiSig wallet

    // ---------
    // Constants
    // ---------

    uint256 constant USD = 10**6;   // USDC decimals
    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    // ----------------------
    // Actor Helper Functions
    // ----------------------

    function createActors() public {
        vm.label(USDC, "USD Coin");
        vm.label(LINK, "ChainLink Token");

        vm.label(address(joe), "Joe");
        vm.label(address(dev), "Dev");
        vm.deal(address(joe), 100 ether);
        vm.deal(address(dev), 100 ether);
    }

    /// @notice Helper function to create a merkle tree whitelist for an amount of minters.
    /// @param _amount Number of whitelisted minters.
    /// @dev Returns an array of whitelisted minters and an array of their hashed addresses.
    function createWhitelist(uint256 _amount) internal returns (Actor[] memory whitelist, bytes32[] memory tree) {
        whitelist = new Actor[](_amount);
        tree = new bytes32[](_amount);

        // Create an actor amount times and provide actors with ETH to mint
        for(uint256 i = 0; i < _amount; ++i) {
            Actor minter = new Actor();
            vm.deal(address(minter), 100 ether);
            whitelist[i] = minter;
            tree[i] = keccak256(abi.encodePacked(address(minter)));
        }
    }

    /// @notice Helper function to mint a desired amount of tokens from the NFT contract.
    /// @param _contract Contract address to mint tokens from.
    /// @param _amount Number of tokens to mint.
    function mintTokens(address _contract, uint256 _amount) internal {
        uint256 remainder = _amount % 20;
        uint256 quotient = _amount / 20;

        // Mint max amount of tokens, quotient times
        for(uint i = 0; i < quotient; ++i) {
            Actor minter = new Actor();
            vm.deal(address(minter), 25 ether);
            assert(minter.try_mint{value:20 ether}(_contract, 20));
        }

        // Mint remaining amount of tokens, if there is a remainder
        if(remainder != 0) {
            Actor remaining = new Actor();
            vm.deal(address(remaining), 25 ether);
            assert(remaining.try_mint{value: remainder * 10**18}(_contract, remainder));
        }
    }

    // ----------------------
    // Test Utility Functions
    // ----------------------

    /// @notice  Verify equality within accuracy decimals.
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10**accuracy);

        if (!check) {
            // use Foundry's logging events to log string, uint pairs
            emit log_named_uint( "Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("  Actual", val1);
        }
    }

    /// @notice Verify equality within difference.
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            // use Foundry's logging events to log string, uint pairs
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("  Actual", val1);
        }
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max) public pure returns (uint256) {
        return constrictToRange(val, min, max, false);
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max, bool nonZero) public pure returns (uint256) {
        if (val == 0 && !nonZero) return 0;
        else if (max == min) return max;
        else return (val % (max - min)) + min;
    }
}
