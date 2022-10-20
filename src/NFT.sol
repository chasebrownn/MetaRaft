// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";
import "./libraries/Strings.sol";
import "./libraries/ERC721.sol";
import "./libraries/MerkleProof.sol";
import {IERC20} from "./interfaces/InterfacesAggregated.sol";

/// @dev    This ERC721 contract represents a standard NFT contract that holds unique art and rewards data.
///         This contract should support the following functionalities:
///         - Mintable
///         - Tradeable
///         - 6 unique art pieces 
///         - Support whitelist mints
///         - Withdraw ETH to rewards.sol contract
///         - NOTE: Rewards are ***NON-TRANSFFERABLE***
///                 After mint the ORIGINAL wallet that minted the NFT MUST be the one to collect rewards from the front end.
///                 Only TIER_ONE NFTs are intended to be transffered as they will only be drawn at the end of the year.

contract NFT is ERC721, Ownable {
    using Strings for uint256;

    // ---------------
    // State Variables
    // ---------------

    // ERC721 Basic
    uint256 public currentTokenId;                      /// @notice Last minted token id, the next token id minted is currentTokenId + 1
    uint256 public constant totalSupply = 10_000;
    uint256 public constant raftPrice = 1 ether;   
    uint256 public constant maxRaftPurchase = 20;

    // ERC721 Metadata
    string public baseURI;

    // Extras
    bytes32 private whitelistRoot;                      /// @notice Merkle tree root hash used to verify whitelisted addresses.
    address payable public circleAccount;               /// @notice Address of Circle account.
    address payable public multiSig;                    /// @notice Address of multi-signature wallet.
    bool public publicSaleActive;                       /// @notice Controls the access for public mint.
    bool public whitelistSaleActive;                    /// @notice Controls the access for whitelist mint.
    mapping(address => uint256) public amountMinted;    /// @notice Internal balance tracking to prevent transfers to mint more tokens.
    mapping(uint256 => address) public originalOwner;   /// @notice Internal ownership tracking to ensure gifts are non-transferrable.

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes MetaRaft.sol.
    constructor(string memory _name, string memory _symbol, address _circleAccount, address _multiSig) ERC721(_name, _symbol)
    {
        circleAccount = payable(_circleAccount);
        multiSig = payable(_multiSig);
    }


    // ------
    // Events
    // ------


    // ---------
    // Modifiers
    // ---------


    // ----------------
    // Public Functions
    // ----------------

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _tokenId.toString(), ".json")) : "";
    }

    /// @notice This function allows tokens to be minted publicly and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mint(uint256 _amount) public payable {
        require(publicSaleActive, "NFT.sol::mint() Public sale is not currently active");
        require(_amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum purchase (20)");
        require(currentTokenId + _amount <= totalSupply, "NFT.sol::mint() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum tokens per address (20)");
        require(msg.value >= raftPrice * _amount, "NFT.sol::mint() Message value must be at least equal to the price of token(s)");

        amountMinted[msg.sender] += _amount;
        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, ++currentTokenId);
        }
    }

    /// @notice This function allows tokens to be minted via whitelist and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mintWhitelist(uint256 _amount, bytes32[] calldata _proof) public payable {
        require(whitelistSaleActive, "NFT.sol::mint() Whitelist sale is not currently active");
        require(_amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum purchase (20)");
        require(currentTokenId + _amount <= totalSupply, "NFT.sol::mint() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum tokens per address (20)");
        require(msg.value >= raftPrice * _amount, "NFT.sol::mint() Message value must be at least equal to the price of token(s)");
        require(MerkleProof.verify(_proof, whitelistRoot, keccak256(abi.encodePacked(msg.sender))), "NFT.sol::mintWhitelist() Address not whitelisted");

        amountMinted[msg.sender] += _amount;
        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, ++currentTokenId);
        }
    }

    /// @notice Helper function that returns an array of token ids that the calling address owns.
    /// @dev Compare to calling ownerOf() off-chain versus this function.
    /// @dev Runtime of O(n) where n is number of tokens minted, if the caller owns token ids up to currentTokenId.
    function ownedTokens() public view returns (uint256[] memory ids) {
        require(currentTokenId > 0, "NFT.sol::ownedTokens() No tokens have been minted");
        require(balanceOf(msg.sender) > 0, "NFT.sol::ownedTokens() Wallet does not own any tokens");

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


    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Helper function that allows minting an amount of tokens without payment or active sales.
    /// @dev Only the owner of the contract can reserve tokens.
    function reserveTokens(uint256 _amount) external onlyOwner {
        require(_amount > 0, "NFT.sol::reserveTokens() Amount of tokens must be greater than zero");
        require(currentTokenId + _amount <= totalSupply, "NFT.sol::reserveTokens() Amount requested exceeds total supply");
        // add a maximum amount to reserve, maybe a percentage of total supply..

        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, ++currentTokenId);
        }
    }

    /// @notice This function toggles public sale.
    /// @param _state true if public sale is active.
    function setPublicSaleState(bool _state) public onlyOwner {
        require(publicSaleActive != _state, "NFT.sol::setPubliclistSaleState() State cannot be same as before");
        publicSaleActive = _state;
    }

    /// @notice This function toggles whitelist sale.
    /// @param _state true if whitelist sale is active.
    function setWhitelistSaleState(bool _state) public onlyOwner {
        require(whitelistSaleActive != _state, "NFT.sol::setWhitelistSaleState() State cannot be same as before");
        whitelistSaleActive = _state;
    }

    /// @notice Used to update the base URI for metadata stored on IPFS.
    /// @param _baseURI The IPFS URI pointing to stored metadata.
    /// @dev URL must be in the format "ipfs://<hash>/“ and the proper extension is used ".json".
    function setBaseURI(string memory _baseURI) public onlyOwner {
        require(keccak256(abi.encodePacked(_baseURI)) != keccak256(abi.encodePacked("")), "NFT.sol::setBaseURI() Base URI cannot be empty");
        require(keccak256(abi.encodePacked(_baseURI)) != keccak256(abi.encodePacked(baseURI)), "NFT.sol::setBaseURI() Base URI address cannot be the same as before");
        baseURI = _baseURI;
    }

    /// @notice This function updates the root hash of the Merkle tree to verify whitelisted wallets.
    /// @param _root Root hash of a Merkle tree generated using keccak256.
    function updateWhitelistRoot(bytes32 _root) public onlyOwner {
        require(_root != bytes32(""), "NFT.sol::modifyWhitelistRoot() Merkle root cannot be empty");
        require(_root != whitelistRoot, "NFT.sol::updateWhitelistRoot() Roots cannot be the same");
        whitelistRoot = _root;
    }

    /// @notice This function updates the address of the Circle account to withdraw ETH to. 
    /// @param _circleAccount Address of the Circle account.
    function updateCircleAccount(address _circleAccount) public onlyOwner {
        require(_circleAccount != address(0), "NFT.sol::updateCircleAccount() Address cannot be the zero address");
        require(_circleAccount != circleAccount, "NFT.sol::updateCircleAccount() Address cannot be the same");
        circleAccount = payable(_circleAccount);
    }

    /// @notice This function updates the address of the multi-signature wallet to safe withdraw ERC20 tokens. 
    /// @param _multiSig Address of the multi-signature wallet.
    function updateMultiSig(address _multiSig) public onlyOwner {
        require(_multiSig != address(0), "NFT.sol::updateCircleAccount() Address cannot be the zero address");
        require(_multiSig != multiSig, "NFT.sol::updateCircleAccount() Address cannot be the same");
        multiSig = payable(_multiSig);
    }

    /// @notice Withdraws the ETH balance of this contract into a Circle account.
    function withdraw() external onlyOwner {
        require(address(this).balance > 0, "NFT.sol::withdraw() Insufficient ETH balance");
        circleAccount.transfer(address(this).balance);
    }

    /// @notice Withdraw any ERC20 token balance of this contract to the owning address.
    /// @param _contract Contract address of an ERC20 compliant token. 
    function safeWithdraw(address _contract) external onlyOwner {
        require(_contract != address(0), "NFT.sol::safeWithdraw() Contract address cannot be the zero address");
        require(IERC20(_contract).balanceOf(address(this)) > 0, "NFT.sol::safeWithdraw() Insufficient token balance");
        uint256 balance = IERC20(_contract).balanceOf(address(this));
        IERC20(_contract).transfer(multiSig, balance);
    }

}
