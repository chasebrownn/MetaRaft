// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./libraries/Ownable.sol";
import "./libraries/Strings.sol";
import "./interfaces/ERC721.sol";

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
    uint256 public currentTokenId = 1;
    uint256 public constant totalSupply = 10_000;
    uint256 public constant raftPrice = 1 ether;
    uint256 public constant maxRaftPurchase = 20;

    // ERC721 Metadata
    string public baseURI;

    // Extras
    mapping(address => bool) whitelistMinted; /// @notice Used to keep track of who is whitelsited for minting.

    bytes32 private merkleRoot;         /// @notice Root hash used for verifying whitelisted addresses.
    address public rewardsContract;     /// @notice Stores the contract address of Rewards.sol.
    bool public publicSaleActive;       /// @notice Controls the access for public mint.
    bool public whitelistSaleActive;    /// @notice Controls the access for whitelist mint.



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes MetaRaft.sol.
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {

    }



    // ---------
    // Modifiers
    // ---------

    modifier isRewards(address sender) {
        require(rewardsContract == sender, "NFT.sol::isRewards() msg.sender is not Rewards.sol");
        _;
    }



    // ---------
    // Functions
    // ---------

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){
        return
            bytes(baseURI).length > 0
                ? string(
                    abi.encodePacked(baseURI, _tokenId.toString(), ".json")
                )
                : "";
    }

    /// @notice This function will create new NFTs and add them to the total supply.
    /// @param _amount The amount of NFTs we are minting.
    /// @dev Minters can mint up to only 20 NFTs at a time, and may not mint if minted supply >= 10,000.
    function mintDapp(uint256 _amount) public payable {
        require(currentTokenId + _amount <= totalSupply + 1, "NFT.sol::mintDapp() Transaction exceeds total supply");
        require(balanceOf(msg.sender) + _amount <= maxRaftPurchase, "NFT.sol::mintDapp() Transaction exceeds maximum purchase restriction (20)");
        require(raftPrice * _amount <= msg.value, "NFT.sol::mintDapp() Message value must be greater than price of NFTs");
        require(whitelistSaleActive || publicSaleActive, "NFT.sol::mintDapp() No sale is currently active");
        if (publicSaleActive) {
            mint(msg.sender, _amount);
        } else if (whitelistSaleActive) {
            require(merkleCheck(msg.sender), "NFT.sol::mintWhitelist() Wallet is not whitelisted");
            mint(msg.sender, _amount);
        }
    }

    /// @notice This function will verify whitelist status using a merkle proof received from the front-end.
    /// @dev this function will check whitelist against a mapping until front-end implementation.
    /// TODO: create a low level dapp to test merkle tree.
    function merkleCheck(address _address) internal view returns (bool) {
        return (whitelistMinted[_address]);
    }

    /// @notice handles minting for public sale
    function mint(address _address, uint256 _amount) internal {
        for (uint256 i = 0; i < _amount; i++) {
            _mint(_address, currentTokenId);
            emit Transfer(address(0), msg.sender, currentTokenId);
            currentTokenId++;
        }
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

    /// @notice This function is used to add wallets to the whitelist mapping.
    /// @param  _address is the wallet address that will have their whitelist status modified.
    /// @param  _state use True to whitelist a wallet, otherwise use False to remove wallet from whitelist.
    /// @dev temporary for 
    function modifyWhitelist(address _address, bool _state) public onlyOwner {
        whitelistMinted[_address] = _state;
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
    /// @param _merkleRoot is the root of the whitelist merkle tree.
    function modifyWhitelistRoot(bytes32 _merkleRoot) public onlyOwner {
        require(_merkleRoot != bytes32(""), "NFT.sol::modifyWhitelistRoot Merkle root cannot be empty");
        require(_merkleRoot != merkleRoot, "NFT.sol::modifyWhitelistRoot Merkle root cannot be the same as before");

        merkleRoot = _merkleRoot;
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
