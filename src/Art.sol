// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/openzeppelin-contracts-master/contracts/access/Ownable.sol";


contract Art is Ownable, ERC721 {
    
uint tokenId;
mapping(address=>tokenMetaData[]) public ownershipRecord;

struct tokenMetaData{
    uint tokenId;
    uint timeStamp;
    string tokenURI;
}

function mintToken(address recipient) onlyOwner public {
    require(owner()!=recipient, "Recipient cannot be the owner of the contract");
    _safeMint(recipient, tokenId);
    ownershipRecord[recipient].push(tokenMetaData(tokenId, block.timestamp, "https://miro.medium.com/max/1120/1*k_EY7dcLYB5Z5k8zhMcv6g.png"));
    tokenId = tokenId + 1;
}


}
