// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";
import "./libraries/Strings.sol";
import "./libraries/ERC721.sol";
import "./libraries/MerkleProof.sol";

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
    uint256 public currentTokenId;
    uint256 public constant totalSupply = 10_000;
    uint256 public constant raftPrice = 1 ether;
    uint256 public constant maxRaftPurchase = 20;

    // ERC721 Metadata
    string public baseURI;

    // Extras
    bytes32 private whitelistRoot;      /// @notice Merkle tree root hash used to verify whitelisted addresses.
    address public rewardsContract;     /// @notice Stores the contract address of Rewards.sol.
    bool public publicSaleActive;       /// @notice Controls the access for public mint.
    bool public whitelistSaleActive;    /// @notice Controls the access for whitelist mint.
    mapping(address => uint256) public amountMinted;


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes MetaRaft.sol.
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol)
    {

    }


    // ------
    // Events
    // ------
    event log_uint256(uint256 value);


    // ---------
    // Modifiers
    // ---------

    modifier isRewards(address sender) {
        require(rewardsContract == sender, "NFT.sol::isRewards() msg.sender is not Rewards.sol");
        _;
    }



    // ----------------
    // Public Functions
    // ----------------

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, _tokenId.toString(), ".json")
                )
                : "";
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

    /// @notice This function allows NFTs to be minted via whitelist and added to the total supply.
    /// @param _amount The amount of NFTs to be minted.
    /// @dev Only 20 NFTs can be minted per address, and may not mint if minted supply >= 10,000.
    function mintWhitelist(uint256 _amount, bytes32[] calldata _proof) public payable {
        require(publicSaleActive, "NFT.sol::mint() Public sale is not currently active");
        require(_amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum purchase (20)");
        require(currentTokenId + _amount <= totalSupply, "NFT.sol::mint() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= maxRaftPurchase, "NFT.sol::mint() Amount requested exceeds maximum tokens per address (20)");
        require(msg.value >= raftPrice * _amount, "NFT.sol::mint() Message value must be at least equal to the price of token(s)");
        require(MerkleProof.verify(_proof, whitelistRoot, keccak256(abi.encodePacked(msg.sender))), "NFT.sol::mintWhitelist() Address not whitelisted");

        amountMinted[msg.sender] += _amount;
        for(_amount; _amount > 0; --_amount) {
            _mint(msg.sender, currentTokenId);
            currentTokenId++;
        }
    }

    /// @notice Helper function that returns an array of token ids that the calling address owns.
    /// @dev Runtime of O(n) where n is number of tokens minted, if the caller owns token ids up to currentTokenId.
    function ownedTokensOriginal() public view returns (uint256[] memory ids) {
        require(currentTokenId >= 1, "NFT.sol::ownedTokens() No tokens have been minted");
        require(balanceOf(msg.sender) > 0, "NFT.sol::ownedTokens() Wallet does not own any tokens");

        // Originally used currentTokenId directly in the for loop and if statement, but was worried
        // about the atomicity of the value given state changes. Safest to assign to local variable.
        uint256 currentId = currentTokenId;
        uint256 balance = balanceOf(msg.sender);
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 total = 0;

        for(uint256 i = 1; i <= currentId; i++) {

            // If balanceOf(msg.sender) = 8 and only 8 tokens have been minted then currentTokenId = 8 
            // and every minted token id belongs to msg.sender.
            // It is impossible for someone to own a token id or have a balance that is greater than 
            // currentTokenId.
            if(address(msg.sender) == ownerOf(i)) {
                tokenIds[total++] = i;
                if(total >= balance) {
                    return tokenIds;
                }
            }
        }
        // Safety net, however the return should trigger within the for loop assuming that the
        // balanceOf(msg.sender) is accurate.
        return tokenIds;
    }

    /// @notice Helper function that returns an array of token ids that the calling address owns.
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
                // token ids to specific indices within the array.
                // If balanceOf(msg.sender) = 8, then this will cover indices 7, 6, 5, 4, 3, 2, 1, 0
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

    /// @notice This function will mint out any NFTs that were not minted during the mint phase and burn them.
    /// TODO:  Decide if we mint directly to the null addy or a holding account.
    function mintLeftovers() external onlyOwner {
        //currentTokenId == totalSupply
        // burn all tokenIds from currentTokenId up to totalSupply
    }

    function reserveAmount(uint256 _amount) external onlyOwner {
        for (_amount; _amount > 0; _amount--) {
            _mint(msg.sender, ++currentTokenId);
        }
    }

    /// @notice This function toggles public sale.
    /// @param _state true if public sale is active.
    function setPublicSaleState(bool _state) public onlyOwner {
        require(publicSaleActive != _state, "NFT.sol::setPubliclistSaleState() _state cannot be same as before");
        publicSaleActive = _state;
    }

    /// @notice This function toggles whitelist sale.
    /// @param _state true if whitelist sale is active.
    function setWhitelistSaleState(bool _state) public onlyOwner {
        require(whitelistSaleActive != _state, "NFT.sol::setWhitelistSaleState() _state cannot be same as before");
        whitelistSaleActive = _state;
    }

    /// @notice This function updates the root hash of the Merkle tree to verify whitelisted wallets.
    /// @param _root Root hash of a Merkle tree generated using keccak256.
    function updateWhitelistRoot(bytes32 _root) public onlyOwner {
        require(whitelistRoot != _root, "NFT.sol::updateWhitelistRoot() Roots cannot be the same");
        whitelistRoot = _root;
    }

    /// @notice Used to update the base URI for metadata stored on IPFS.
    /// @dev URL must be in the format "ipfs://<hash>/“ and the proper extension is used ".json".
    /// @param   _baseURI    The IPFS URI pointing to stored metadata.
    function setBaseURI(string memory _baseURI) public onlyOwner {
        require(keccak256(abi.encodePacked(_baseURI)) != keccak256(abi.encodePacked("")), "NFT.sol::setBaseURI() baseURI cannot be empty");
        require(keccak256(abi.encodePacked(_baseURI)) != keccak256(abi.encodePacked(baseURI)), "NFT.sol::setBaseURI() baseURI address cannot be the same as before");

        baseURI = _baseURI;
    }


        // figure out how to only set this value once or twice
        // 1) Default images with blank metadata (while minting)
        /*
        NFT Metadata (While minting):
        {
            "name": <name of NFT>
            "description": <description of collection or round>
            "image": <Default image URL>
            "external-url": <link to our minting page or website>
            "attributes": [
                { 
                    "trait_type": "Ticket ID",
                    "display_type": "number",
                    "value": <NFT ID from mint>
                },
                {
                    "trait_type": "Ticket Tier",
                    "value": "???"
                }
            ]
        }
        */
        // 2) Revealed images with metadata (after drawing)
        /*
        NFT Metadata (After drawing):
        {
            "name": <name of NFT>
            "description": <description of collection or round>
            "image": <IPFS image URL>
            "external-url": <link to our minting page or website>
            "attributes": [
                { 
                    "trait_type": "Ticket ID",
                    "display_type": "number",
                    "value": <NFT ID from mint>
                },
                {
                    "trait_type": "Ticket Tier",
                    "value": <string value of tier 1 through tier 6, where tier 6 receives no gift>
                }
            ]
        }
        */
    


    /// @notice This function is used to update the merkleRoot.
    /// @param _whitelistRoot is the root of the whitelist merkle tree.
    function modifyWhitelistRoot(bytes32 _whitelistRoot) public onlyOwner {
        require(_whitelistRoot != bytes32(""), "NFT.sol::modifyWhitelistRoot Merkle root cannot be empty");
        require(_whitelistRoot != whitelistRoot, "NFT.sol::modifyWhitelistRoot Merkle root cannot be the same as before");

        whitelistRoot = _whitelistRoot;
    }

    /// @notice This function is used to set the rewards.sol contract address.
    /// @param  _rewardsContract is the wallet address that will have their whitelist status modified.
    function setRewardsAddress(address _rewardsContract) external onlyOwner {
        require(_rewardsContract != address(0), "NFT.sol::setRewardsAddress() Reward.sol address cannot be address(0)");
        require(_rewardsContract != address(this), "NFT.sol::setRewardsAddress() Reward.sol cannot be the NFT address");
        require(_rewardsContract != rewardsContract, "NFT.sol::setRewardsAddress() Reward.sol address cannot be the same as before");

        rewardsContract = _rewardsContract;
    }

    /// @notice This function is used to withdraw all ETH to Rewards.sol.
    function withdraw() external onlyOwner {

    }

}
