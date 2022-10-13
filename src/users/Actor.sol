// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "../interfaces/InterfacesAggregated.sol";

contract Actor {
    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    // function transferToken(address token, address to, uint256 amt) external {
    //     IERC20(token).transfer(to, amt);
    // }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    // function try_updateTreasury(address stake, address _newTreasury) external returns (bool ok) {
    //      string memory sig = "updateTreasury(address)";
    //      (ok,) = address(stake).call(abi.encodeWithSignature(sig, _newTreasury));
    // }
    function try_mint(address token, uint256 _amount, uint256 _value) external payable returns (bool ok) {
        string memory sig = "mint(uint256)";
        (ok, ) = address(token).call{value: _value}(abi.encodeWithSignature(sig, _amount));
    }

    function try_tokenURI(address token, uint256 _id) external returns (bool ok) {
         string memory sig = "tokenURI(uint256)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _id));
    }

    function try_setBaseURI(address token, string memory _baseURI) external returns (bool ok) {
         string memory sig = "setBaseURI(string)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _baseURI));
    }
    
    function try_modifyWhitelistRoot(address token, bytes32 _modifyWhitelistRoot) external returns (bool ok) {
         string memory sig = "modifyWhitelistRoot(bytes32)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _modifyWhitelistRoot));
    }
    
    function try_setRewardsAddress(address token, address _rewardsContract) external returns (bool ok) {
         string memory sig = "setRewardsAddress(address)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _rewardsContract));
    }

    function try_setPublicSaleState(address token, bool _state) external returns (bool ok) {
         string memory sig = "setPublicSaleState(bool)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _state));
    }

    function try_setWhitelistSaleState(address token, bool _state) external returns (bool ok) {
         string memory sig = "setWhitelistSaleState(bool)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _state));
    }    

    function try_ownedTokens(address token) external returns (bool ok) {
          string memory sig = "ownedTokens()";
          (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }
}