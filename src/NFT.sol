// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";
import "./libraries/Strings.sol";
import "./libraries/ERC721.sol";
import "./libraries/MerkleProof.sol";
import {IERC20} from "./interfaces/InterfacesAggregated.sol";

contract NFT is ERC721, Ownable {
    using Strings for uint256;

    // ---------------
    // State Variables
    // ---------------

    // ERC721 Basic
    uint256 public currentTokenId;                      /// @notice Last token id minted, the next token id minted is currentTokenId + 1
    uint256 public constant TOTAL_RAFTS = 10_000;       /// @notice Maximum number of tokens aka total supply, that can be minted (10000).
    uint256 public constant RAFT_PRICE = 1 ether;       /// @notice Price of a single token in ETH.
    uint256 public constant MAX_RAFTS = 20;             /// @notice Maximum number of tokens that can be minted per address (20).

    // ERC721 Metadata
    string public unrevealedURI;
    string public baseURI;

    // Extras
    mapping(address => uint256) public amountMinted;    /// @notice Internal balance tracking to prevent transfers to mint more tokens.
    bytes32 public immutable whitelistRoot;             /// @notice Merkle tree root hash used to verify whitelisted addresses.
    address payable public circleAccount;               /// @notice Address of Circle account for ETH deposits.
    address payable public multiSig;                    /// @notice Address of multi-signature wallet for ERC20 deposits.
    bool public whitelistSaleActive;                    /// @notice Controls the access for whitelist mint.
    bool public publicSaleActive;                       /// @notice Controls the access for public mint.


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes NFT.sol.
    constructor(
        string memory _name, 
        string memory _symbol, 
        string memory _unrevealedURI,
        address _circleAccount, 
        address _multiSig, 
        bytes32 _whitelistRoot
    ) ERC721(_name, _symbol)
    {
        unrevealedURI = _unrevealedURI;
        whitelistRoot = _whitelistRoot;
        circleAccount = payable(_circleAccount);
        multiSig = payable(_multiSig);
    }


    // ----------------
    // Public Functions
    // ----------------

    /// @notice Returns the tokens URI reference with the format "ipfs://<CID>/<token-id>.json“.
    /// @dev Returns the unrevealed URI as long as the base URI has not been set or is empty.
    /// @param _tokenId The tokens id.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        return
            bytes(baseURI).length > 0 ? 
                string(abi.encodePacked(baseURI, _tokenId.toString(), ".json")) 
                : 
                string(abi.encodePacked(unrevealedURI, _tokenId.toString(), ".json"));
    }

    /// @notice Helper function that returns an array of token ids that the calling address owns.
    /// @dev Runtime of O(n) where n is number of tokens minted, if the caller owns token ids near the first id.
    function ownedTokens() external view returns (uint256[] memory ids) {
        require(balanceOf(msg.sender) > 0, "NFT.sol::ownedTokens() Address does not own any tokens");

        uint256 currentId = currentTokenId;
        uint256 balance = balanceOf(msg.sender);
        uint256[] memory tokenIds = new uint256[](balance);

        // More gas efficient than incrementing upwards to currentId from one.
        for(currentId; currentId > 0; --currentId) {

            // If balanceOf(msg.sender) = 8 and only 8 tokens have been minted then currentTokenId = 8 
            // and every minted token id belongs to msg.sender.
            // It is impossible for someone to own a token id or have a balance that is greater than 
            // currentTokenId.
            if(address(msg.sender) == ownerOf(currentId)) {
                // More gas efficient to use existing balance variable than create another to assign
                // token ids to specific indexes within the array.
                // If balanceOf(msg.sender) = 8, then this will cover indexes 7, 6, 5, 4, 3, 2, 1, 0
                // in the tokenIds array and order owned token ids from lowest id to highest id.
                tokenIds[--balance] = currentId;
                if(balance == 0) {
                    return tokenIds;
                }
            }
        }
        // Safety net, however the return should trigger within the for loop assuming that the
        // balanceOf(msg.sender) is accurate.
        return tokenIds;
    }

    /// @notice This function allows tokens to be minted publicly and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mint(uint256 _amount) external payable {
        require(publicSaleActive, "NFT.sol::mint() Public sale is not currently active");
        require(_amount <= MAX_RAFTS, "NFT.sol::mint() Amount requested exceeds maximum purchase (20)");
        require(currentTokenId + _amount <= TOTAL_RAFTS, "NFT.sol::mint() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= MAX_RAFTS, "NFT.sol::mint() Amount requested exceeds maximum tokens per address (20)");
        require(msg.value == RAFT_PRICE * _amount, "NFT.sol::mint() Message value must be equal to the price of token(s)");

        amountMinted[msg.sender] += _amount;
        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, ++currentTokenId);
        }
    }

    /// @notice This function allows tokens to be minted via whitelist and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @param _proof  Merkle proof for the calling address.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mintWhitelist(uint256 _amount, bytes32[] calldata _proof) external payable {
        require(whitelistSaleActive, "NFT.sol::mintWhitelist() Whitelist sale is not currently active");
        require(_amount <= MAX_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds maximum purchase (20)");
        require(currentTokenId + _amount <= TOTAL_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= MAX_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds maximum tokens per address (20)");
        require(msg.value == RAFT_PRICE * _amount, "NFT.sol::mintWhitelist() Message value must be equal to the price of token(s)");
        require(MerkleProof.verify(_proof, whitelistRoot, keccak256(abi.encodePacked(msg.sender))), "NFT.sol::mintWhitelist() Address not whitelisted");

        amountMinted[msg.sender] += _amount;
        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, ++currentTokenId);
        }
    }


    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Updates the base URI for metadata stored on IPFS.
    /// @param _baseURI The IPFS URI pointing to the folder with JSON metadata for all tokens.
    /// @dev Must be of the format "ipfs://<CID>/“ where the CID references the folder with JSON metadata for all tokens.
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /// @notice Updates public sale state.
    /// @param _state True if public sale is active, false if public sale is not active.
    function setPublicSaleState(bool _state) external onlyOwner {
        publicSaleActive = _state;
    }

    /// @notice Updates whitelist sale state.
    /// @param _state True if whitelist sale is active, false if whitelist sale is not active.
    function setWhitelistSaleState(bool _state) external onlyOwner {
        whitelistSaleActive = _state;
    }

    /// @notice Updates the address of the Circle account to withdraw ETH to. 
    /// @param _circleAccount Address of the Circle account.
    function updateCircleAccount(address _circleAccount) external onlyOwner {
        require(_circleAccount != address(0), "NFT.sol::updateCircleAccount() Address cannot be zero address");
        circleAccount = payable(_circleAccount);
    }

    /// @notice Updates the address of the multi-signature wallet to safe withdraw ERC20 tokens. 
    /// @param _multiSig Address of the multi-signature wallet.
    function updateMultiSig(address _multiSig) external onlyOwner {
        require(_multiSig != address(0), "NFT.sol::updateMultiSig() Address cannot be zero address");
        multiSig = payable(_multiSig);
    }

    /// @notice Withdraws the entire ETH balance of this contract into the Circle account.
    /// @dev Call pattern adopted from the sendValue(address payable recipient, uint256 amount)
    ///      function in OZ's utils/Address.sol contract. "Please consider reentrancy potential" - OZ.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "NFT.sol::withdraw() Insufficient ETH balance");

        (bool success,) = payable(circleAccount).call{value: balance}("");
        require(success, "NFT.sol::withdraw() Unable to withdraw funds, recipient may have reverted");
    }

    /// @notice Withdraws any ERC20 token balance of this contract into the owning address.
    /// @param _contract Contract address of an ERC20 compliant token. 
    function withdrawERC20(address _contract) external onlyOwner {
        require(_contract != address(0), "NFT.sol::withdrawERC20() Contract address cannot be zero address");

        uint256 balance = IERC20(_contract).balanceOf(address(this));
        require(balance > 0, "NFT.sol::withdrawERC20() Insufficient token balance");

        bool success = IERC20(_contract).transfer(multiSig, balance);
        require(success, "NFT.sol::withdrawERC20() Transfer failed on ERC20 contract");
    }
}