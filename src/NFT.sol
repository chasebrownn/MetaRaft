// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/openzeppelin-contracts-master/contracts/access/Ownable.sol";


contract NFT is Ownable, ERC721 {
    
uint tokenId;
mapping(address=>tokenMetaData[]) public ownershipRecord;

struct tokenMetaData{
    uint tokenId;
    uint timeStamp;
    string tokenURI;
}

/// @notice This function will create new NFTs and add them to the total supply.
/// @param _wallet The account we are minting a NFT to.
/// @param _amount The amount of NFTs we are minting.
/// @dev Minters can mint up to only 20 NFTs at a time, and may not mint if minted supply >= 10,000
function mintDapp(address _wallet, uint256 _amount) onlyOwner public {

}

/// @notice This function will mint out any NFTs that were not minted during the mint phase and burn them.
/// @TODO:  Decide if we mint directly to the null addy or a holding account.
function mintLeftover() onlyOwner public {

}


}
