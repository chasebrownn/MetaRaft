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
    function try_mintDapp(address token, uint256 _amount, uint256 _value) external payable returns (bool ok) {
        string memory sig = "mintDapp(uint256)";
        (ok, ) = address(token).call{value: _value}(abi.encodeWithSignature(sig, _amount));
    }
}
