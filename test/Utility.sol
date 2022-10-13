// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "../src/users/Actor.sol";
import "../lib/forge-std/src/Vm.sol";
import "../lib/forge-std/src/Test.sol";
import {IWETH} from "../src/interfaces/InterfacesAggregated.sol";

//import "../lib/forge-std/lib/ds-test/src/test.sol";

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
    Actor art = new Actor(); // Art Contract
    Actor tkt = new Actor(); // Ticket Contract
    Actor rwd = new Actor(); // Rewards Contract
    Actor mlt = new Actor(); // Multi Sig wallet address

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
        dev = new Actor();
        joe = new Actor();
        art = new Actor();
        tkt = new Actor();
        rwd = new Actor();
        mlt = new Actor();
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

    // function mintETH(uint256 _amount) public {
    //     IWETH(WETH).deposit{value: _amount}();
    // }

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
