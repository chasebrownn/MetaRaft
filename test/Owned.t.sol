// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Utility } from "./utils/Utility.sol";
import { Owned } from "../src/bases/Owned.sol";

contract MockOwned is Owned {
    bool public flag;

    constructor() Owned(msg.sender) {}

    function updateFlag() public virtual onlyOwner {
        flag = true;
    }
}

/// @author Andrew Thomas
/// @notice Unit tests for modified Owned contract.
contract OwnedTest is Utility {
    MockOwned internal ownedContract;
    address internal newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        ownedContract = new MockOwned();

        newOwner = makeAddr("New Owner");
    }

    function test_owned_transferOwnership_Transferred() public {
        vm.expectEmit(true, true, true, true, address(ownedContract));
        emit OwnershipTransferred(address(this), newOwner);
        ownedContract.transferOwnership(newOwner);

        assertEq(ownedContract.owner(), newOwner);
    }

    function test_owned_transferOwnership_ZeroAddress() public {
        vm.expectRevert("ZERO ADDRESS");
        ownedContract.transferOwnership(address(0));
    }

    function test_owned_onlyOwner_Authorized() public {
        ownedContract.updateFlag();

        assertEq(ownedContract.flag(), true);
    }

    function test_owned_onlyOwner_Unauthorized() public {
        vm.prank(newOwner);
        vm.expectRevert("UNAUTHORIZED");
        ownedContract.updateFlag();
    }
}