// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/openzeppelin-contracts-master/contracts/access/Ownable.sol";


contract NFT is Ownable, ERC721 {
 
    // ---------------
    // State Variables
    // ---------------

    // ERC721 Basic
    uint tokenId;
    uint256 _totalSupply;
    string private _name;
    string private _symbol;

    // ERC71 Mappings
    mapping(uint256 => address) _ownerOf;     // Used to keep track of who owns a particular ID.

    // Extra
    mapping(address => bool) whitelist;       // Used to keep track of who is whitelsited for minting.
    mapping (address => bool) exception;      // Mapping of wallets who are allowed to receive or send tokens.
    address public rewards;                   // Stores the address of Rewards.sol.

    struct tokenMetaData{
        uint tokenId;
        uint timeStamp;
        string tokenURI;
    }



    // -----------
    // Constructor
    // -----------

    /// @notice Initializes NFT.sol.
    constructor () {
        _name = "MetaRaft";
        _symbol = "MRAFT";         // TODO: Decide on Name and Symbol
        _totalSupply = 10000;
        transferOwnership(_admin);

    }



    // ------
    // Events
    // ------

    /// @dev Emitted when approve() is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);   
 
    /// @dev Emitted during transfer() or transferFrom().
    event Transfer(address indexed _from, address indexed _to, uint256 _value);



    // ---------
    // Modifiers
    // ---------

    modifier isRewards(address sender) {
        require(treasury == sender,
        "NFT.sol::isRewards() msg.sender is not Rewards.sol");
        _;
    }



    // ---------
    // Functions
    // ---------


    // ~ ERC721 View ~

    /// @notice Returns the name of the collection.
    function name() external view returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the collection.
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns unique metadata identifier for each token.
    /// @param tokenId The ID of the token being queried.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {

    }

    /// @notice Returns base URI.
    function baseURI() public view virtual override returns (string memory) {

    }

    /// @notice Returns the total supply of the collection (10,000).
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the total amount of NFTs held by a wallet.
    /// @param _owner The address whose total balance is desired.
    function balanceOf(address _owner) external view returns (uint256 balance) {
        return balances[_owner];
    }

    /// @notice Returns the owner of a particular NFT.
    /// @param tokenId The ID of the token being queried.
    function ownerOf(uint256 tokenId) external view returns (address holder) {
       return _ownerOf[_id];
    }



    // ~ Core IERC721 ~

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {

    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {

    }

    function approve(address _to, uint256 _tokenId) external {

    }

    function getApproved(uint256 _tokenId) external returns (address account) {

    }

    function setApprovalForAll(address operator, bool _approved) external {

    }

    function isApprovalForAll(address owner, address operator) external returns (bool isAllowed){

    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes _data) external {

    }



    // ~ Admin ~

    /// @notice This function will create new NFTs and add them to the total supply.
    /// @param _wallet The account we are minting a NFT to.
    /// @param _amount The amount of NFTs we are minting.
    /// @dev Minters can mint up to only 20 NFTs at a time, and may not mint if minted supply >= 10,000.
    function mintDapp(address _wallet, uint256 _amount) external onlyOwner {

    }

    /// @notice This function will mint out any NFTs that were not minted during the mint phase and burn them.
    /// TODO:  Decide if we mint directly to the null addy or a holding account.
    function safeMint() external onlyOwner {

    }

    /// @notice Used to update the base URI for metadata stored on IPFS.
    /// @dev URL must be in the format "ipfs://<hash>/“ and the proper extension is used ".json".
    /// @param   _baseURI    The IPFS URI pointing to stored metadata.
    function setBaseURI(string memory _baseURI) public onlyOwner {


    }

    /// @notice This function is used to add wallets to the whitelist mapping.
    /// @param  _wallet is the wallet address that will have their whitelist status modified.
    /// @param  _whitelist use True to whitelist a wallet, otherwise use False to remove wallet from whitelist.
    function modifyWhitelist(address _wallet, bool _whitelist) public onlyOwner {
        whitelist[_wallet] = _whitelist;
    }

}
