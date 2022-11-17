// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

import "./users/Actor.sol";
import "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/Test.sol";
import {IERC20} from "../src/interfaces/InterfacesAggregated.sol";


contract Utility is Test {
    /***********************************/
    /*** Ethereum Contract Addresses ***/
    /***********************************/

    // Mainnet Addresses
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    /**************/
    /*** Actors ***/
    /**************/

    Actor dev = new Actor(); // Owner/Dev
    Actor joe = new Actor(); // NFT Holder
    Actor sig = new Actor(); // MultiSig Wallet
    Actor crc = new Actor(); // Circle Account

    /*****************/
    /*** Constants ***/
    /*****************/

    uint256 constant USD = 10**6; // USDC decimals
    uint256 constant WAD = 10**18;
    uint256 constant RAY = 10**27;

    /*****************/
    /*** Utilities ***/
    /*****************/

    struct Token {
        address addr; // ERC20 Mainnet address
        uint256 slot; // Balance storage slot
        address orcl; // Chainlink oracle address
    }

    /*****************************/
    /*** Actor Setup Functions ***/
    /*****************************/
    function createActors() public {
        vm.deal(address(joe), 100 ether);
        vm.deal(address(dev), 100 ether);
    }

    /// @notice ADD NATSPEC!!!
    function createWhitelist(uint256 _amount) public returns (Actor[] memory, bytes32[] memory) {
        Actor[] memory whitelist = new Actor[](_amount);
        bytes32[] memory tree = new bytes32[](_amount);

        for(uint256 i = 0; i < _amount; ++i) {
            Actor user = new Actor();
            vm.deal(address(user), 100 ether);
            whitelist[i] = user;
            tree[i] = keccak256(abi.encodePacked(address(user)));
        }

        return (whitelist, tree);
    }

    /// @notice ADD NATSPEC!!!
    function reserveTokens(address _contract, uint256 _amount) public {
        uint256 remainder = _amount % 20;
        uint256 quotient = _amount / 20;

        // mint max amount of tokens, quotient times.
        for(uint i = 0; i < quotient; ++i) {
            Actor minter = new Actor();
            vm.deal(address(minter), 25 ether);
            assert(minter.try_mint{value:20 ether}(_contract, 20));
        }

        // mint amount of tokens remaining.
        if(remainder > 0) {
            Actor remaining = new Actor();
            vm.deal(address(remaining), 25 ether);
            assert(remaining.try_mint{value: remainder * 10**18}(_contract, remainder));
        }
    }

    mapping(bytes32 => Token) tokens;

    event Debug(string, uint256);
    event Debug(string, address);
    event Debug(string, bool);

    /******************************/
    /*** Test Utility Functions ***/
    /******************************/

    function setUpTokens() public {
        tokens["USDC"].addr = USDC;
        tokens["USDC"].slot = 9;

        tokens["WETH"].addr = WETH;
        tokens["WETH"].slot = 3;
    }

    // Manipulate mainnet ERC20 balance.
    function mint(bytes32 symbol, address account, uint256 amt) public {
        address addr = tokens[symbol].addr;
        uint256 slot = tokens[symbol].slot;
        uint256 bal = IERC20(addr).balanceOf(account);

        // use Foundry's vm to call "store" cheatcode
        vm.store(
            addr,
            keccak256(abi.encode(account, slot)), // Mint tokens
            bytes32(bal + amt)
        );

        assertEq(IERC20(addr).balanceOf(account), bal + amt); // Assert new balance
    }

    // Verify equality within accuracy decimals
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10**accuracy);

        if (!check) {
            // use Foundry's logging events to log string, uint pairs.
            emit log_named_uint( "Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("  Actual", val1);
        }
    }

    // Verify equality within difference
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            // use Foundry's logging events to log string, uint pairs.
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
