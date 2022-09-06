// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./openzeppelin-contracts-master/contracts/utils/Strings.sol";
import "./libraries/ERC721.sol";

contract NFT is ERC721, Ownable {
 
    using Strings for uint256;

    // ---------------
    // State Variables
    // ---------------

    // ERC721 Basic
    uint256 public currentTokenId = 1;
    uint256 public constant totalSupply = 10_000;
    uint256 public constant raftPrice = 1 ether;
    uint256 public constant maxRaftPurchase = 20;

    // ERC721 Metadata
    string public baseURI;

    // Extras
    mapping(address => bool) whitelistMinted;       /// @notice Used to keep track of who is whitelsited for minting.

    bytes32 private merkleRoot;                     /// @notice Merkle root for verifying whitelisted addresses.
    address public rewards;                         /// @notice Stores the contract address of Rewards.sol.
    bool public publicSaleActive;                   /// @notice 
    bool public whitelistSaleActive;                /// @notice 

    // -----------
    // Constructor
    // -----------

    /// @notice Initializes MetaRaft.sol.
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    }

    // ---------
    // Modifiers
    // ---------

    modifier isRewards(address sender) {
        require(rewards == sender,
        "NFT.sol::isRewards() msg.sender is not Rewards.sol");
        _;
    }

    // ---------
    // Functions
    // ---------

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (ownerOf(_tokenId) == address(0)) {
            //revert NonExistentTokenURI();
        }
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _tokenId.toString(), ".json"))
                : "";
    }

    /// @notice This function will create new NFTs and add them to the total supply.
    /// @param _amount The amount of NFTs we are minting.
    /// @dev Minters can mint up to only 20 NFTs at a time, and may not mint if minted supply >= 10,000.
    function mintDapp(uint256 _amount) public payable {
        require(publicSaleActive, "");
        require(currentTokenId + _amount <= totalSupply, "");
        require(balanceOf(msg.sender) + _amount <= maxRaftPurchase, "");
        require(raftPrice * _amount <= msg.value, "");
        

    }

    function mintWhitelist(uint256 _amount) public payable {
        // verify merkle proof and address beforehand
        require(whitelistSaleActive, "");
        require(currentTokenId + _amount <= totalSupply, "");
        require(balanceOf(msg.sender) + _amount <= maxRaftPurchase, "");
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

    /// @notice Used to update the base URI for metadata stored on IPFS.
    /// @dev URL must be in the format "ipfs://<hash>/“ and the proper extension is used ".json".
    /// @param   _baseURI    The IPFS URI pointing to stored metadata.
    function setBaseURI(string memory _baseURI) public onlyOwner {
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

    }

    /// @notice This function is used to add wallets to the whitelist mapping.
    /// @param  _wallet is the wallet address that will have their whitelist status modified.
    /// @param  _whitelist use True to whitelist a wallet, otherwise use False to remove wallet from whitelist.
    function modifyWhitelist(address _wallet, bool _whitelist) public onlyOwner {
        //whitelist[_wallet] = _whitelist;
    }

    function modifyWhitelistRoot(bytes32 _merkleRoot) public onlyOwner {

    }

}