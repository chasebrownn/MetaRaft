// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract Actor {
    // -------------
    // Try Functions
    // -------------

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

    function try_ownedTokens(address token, address _owner) external returns (bool ok) {
        string memory sig = "ownedTokens(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _owner));
    }

    function try_tokenURI(address token, uint256 _id) external returns (bool ok) {
        string memory sig = "tokenURI(uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _id));
    }

    function try_requestEntropy(address token) external returns (bool ok) {
        string memory sig = "requestEntropy()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_finalizeMint(address token) external returns (bool ok) {
        string memory sig = "finalizeMint()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_shuffleLevels(address token) external returns (bool ok) {
        string memory sig = "shuffleLevels()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }   

    function try_setBaseURI(address token, string memory _baseURI) external returns (bool ok) {
        string memory sig = "setBaseURI(string)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _baseURI));
    }

    function try_updatePublicMint(address token, bool _state) external returns (bool ok) {
        string memory sig = "updatePublicMint(bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _state));
    }

    function try_updateWhitelistMint(address token, bool _state) external returns (bool ok) {
        string memory sig = "updateWhitelistMint(bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _state));
    }

    function try_updateSubId(address token, uint64 _subId) external returns (bool ok) {
        string memory sig = "updateSubId(uint64)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _subId));
    }

    function try_updateCircleAccount(address token, address _circleAccount) external returns (bool ok) {
        string memory sig = "updateCircleAccount(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _circleAccount));
    }

    function try_updateMultiSig(address token, address _multiSig) external returns (bool ok) {
        string memory sig = "updateMultiSig(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _multiSig));
    }

    function try_withdraw(address token) external returns (bool ok) {
        string memory sig = "withdraw()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_withdrawERC20(address token, address _contract) external returns (bool ok) {
        string memory sig = "withdrawERC20(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, _contract));
    } 

    function try_setClaimPeriod(address token) external returns (bool ok) {
        string memory sig = "setClaimPeriod()";
        (ok,) = token.call(abi.encodeWithSignature(sig));
    }

    function try_overrideClaimEnd(address token, uint256 _claimEnd) external returns (bool ok) {
        string memory sig = "overrideClaimEnd(uint256)";
        (ok,) = token.call(abi.encodeWithSignature(sig, _claimEnd));
    }
}