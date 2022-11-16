// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

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

    function try_mint(address token, uint256 _amount) external payable returns (bool ok) {
        string memory sig = "mint(uint256)";
        (ok, ) = address(token).call{value: msg.value}(abi.encodeWithSignature(sig, _amount));
    }

    function try_mintWhitelist(address token, uint256 _amount, bytes32[] calldata proof) external payable returns (bool ok) {
          string memory sig = "mintWhitelist(uint256,bytes32[])";
          (ok,) = address(token).call{value: msg.value}(abi.encodeWithSignature(sig, _amount, proof));
    }

    function try_transferFrom(address token, address _from, address _to, uint256 _id) external returns (bool ok) {
          string memory sig = "transferFrom(address,address,uint256)";
          (ok,) = address(token).call(abi.encodeWithSignature(sig, _from, _to, _id));
    }

    function try_tokenURI(address token, uint256 _id) external returns (bool ok) {
         string memory sig = "tokenURI(uint256)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _id));
    }

    function try_setBaseURI(address token, string memory _baseURI) external returns (bool ok) {
         string memory sig = "setBaseURI(string)";
         (ok,) = address(token).call(abi.encodeWithSignature(sig, _baseURI));
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