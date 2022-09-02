// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/openzeppelin-contracts-master/contracts/access/Ownable.sol";


contract NFT is Ownable, ERC721 {
    
uint tokenId;

struct tokenMetaData{
    uint tokenId;
    uint timeStamp;
    string tokenURI;
}

/// @notice This function will create new NFTs and add them to the total supply.
/// @param _wallet The account we are minting a NFT to.
/// @param _amount The amount of NFTs we are minting.
/// @dev Minters can mint up to only 20 NFTs at a time, and may not mint if minted supply >= 10,000
function mintDapp(address _wallet, uint256 _amount) external onlyOwner {

}

/// @notice This function will mint out any NFTs that were not minted during the mint phase and burn them.
/// TODO:  Decide if we mint directly to the null addy or a holding account.
function safeMint() external onlyOwner {

}

/// @notice Used to update the base URI for metadata stored on IPFS 
/// @dev URL must be in the format "ipfs://<hash>/“ and the proper extension is used ".json"
/// @param   _baseURI    The IPFS URI pointing to stored metadata
function setBaseURI(string memory _baseURI) public {}


/// @notice Returns unique metadata identifier for each token
/// @param   tokenId    The ID of the token being queried
function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {}

}
