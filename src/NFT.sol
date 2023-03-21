// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ERC721 } from "./bases/ERC721.sol";
import { VRFConsumerBaseV2 } from "./bases/VRFConsumerBaseV2.sol";
import { Owned } from "./bases/Owned.sol";
import { LibString } from "./libraries/LibString.sol";
import { MerkleProofLib } from "./libraries/MerkleProofLib.sol";
import { VRFCoordinatorV2Interface } from "./interfaces/VRFCoordinatorV2Interface.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

/// @notice MetaRaft NFT
/// @author Andrew Thomas
contract NFT is ERC721, VRFConsumerBaseV2, Owned {
    using LibString for uint256;

    // ---------------
    // State Variables
    // ---------------

    // ERC721 Basic
    /// @notice Last token id minted, the next token id minted is currentTokenId + 1
    uint256 public currentTokenId;
    /// @notice Total number of tokens that can be minted, aka total supply (10000).
    uint256 public constant TOTAL_RAFTS = 10_000;
    /// @notice Price of a single token in ETH.
    uint256 public constant RAFT_PRICE = 1 ether;
    /// @notice Maximum total number of tokens that can be minted per address (20).
    uint256 public constant MAX_RAFTS = 20;

    // Extras
    /// @notice Merkle tree root hash used to verify whitelisted addresses.
    bytes32 public immutable whitelistRoot;
    /// @notice Extra tracking to prevent transfers to mint more tokens.
    mapping(address => uint256) public amountMinted;
    /// @notice Internal level tracking for every token.
    mapping(uint256 => uint256) internal _levelOf;

    // Chainlink & Shuffle State
    /// @notice Entropy provided by Chainlink VRF.
    uint256 public entropy;
    /// @notice VRFCoodinatorV2 reference to make Chainlink VRF requests.
    VRFCoordinatorV2Interface public immutable vrfCoordinatorV2;
    /// @notice KeyHash required by VRF.
    bytes32 public constant KEY_HASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    /// @notice Number of block confirmations before VRF fulfills request.
    uint16 public constant REQUEST_CONFIRMATIONS = 20;
    /// @notice Callback gas limit for VRF request, ideal for one word of entropy.
    uint32 public constant CALLBACK_GAS_LIMIT = 50_000;
    /// @notice Number of random 256 bit words to be requested from VRF.
    uint32 public constant NUM_WORDS = 1;

    /// @notice Chainlink VRF subscription id.
    uint64 public subId;
    /// @notice Used to determine if entropy has been received from VRF.
    bool public fulfilled;
    /// @notice Used to determine if tokens have been finalized.
    bool public finalized;
    /// @notice Used to determine if the tokens array has been shuffled.
    bool public shuffled;
    /// @notice Controls the access for whitelist mint.
    bool public whitelistMint;
    /// @notice Controls the access for public mint.
    bool public publicMint;

    /// @notice Address of multi-signature wallet for ETH or ERC20 deposits.
    address public multiSig;

    // ERC721 Metadata
    string public unrevealedURI;
    string public baseURI;


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes NFT.sol.
    constructor(
        string memory _name, 
        string memory _symbol, 
        string memory _unrevealedURI,
        bytes32 _whitelistRoot,
        address _vrfCoordinator,
        address _multiSig
    ) 
        ERC721(_name, _symbol) 
        VRFConsumerBaseV2(_vrfCoordinator) 
        Owned(msg.sender)
    {
        unrevealedURI = _unrevealedURI;
        whitelistRoot = _whitelistRoot;
        vrfCoordinatorV2 = VRFCoordinatorV2Interface(_vrfCoordinator);
        multiSig = _multiSig;
    }


    // ----------------
    // Public Functions
    // ----------------

    /// @notice Returns the URI for a token id with the format "ipfs://<CID>/<token-id>.json“.
    /// @dev Returns an unrevealed URI as long as the base URI has not been set or is empty.
    /// @param _tokenId The token id.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        string memory base = baseURI;
        return
            bytes(base).length != 0 ? 
                string.concat(base, _tokenId.toString(), ".json") 
                : 
                string.concat(unrevealedURI, _tokenId.toString(), ".json");
    }


    // ------------------
    // External Functions
    // ------------------

    /// @notice Returns the level of a given token id.
    /// @param _tokenId Token id.
    /// @return level Level of the token id.
    /// @dev Minted token levels are within [1...currentTokenId].
    function levelOf(uint256 _tokenId) external view returns (uint256 level) {
        require((level = _levelOf[_tokenId]) != 0, "NOT_MINTED");
    }

    /// @notice Returns an array of token ids that the given address owns.
    /// @param _owner An address that owns some tokens.
    /// @dev Runtime of O(n) where n is number of tokens minted, if the address owns token ids near the first id.
    /// @dev This function should not be called on chain.
    function ownedTokens(address _owner) external view returns (uint256[] memory tokenIds) {
        uint256 balance = _balanceOf[_owner];        
        tokenIds = new uint256[](balance);

        // More gas efficient than incrementing upwards to currentId from one
        for(uint256 currentId = currentTokenId; currentId > 0; --currentId) {
            // If _balanceOf(_owner) = 8 and only 8 tokens have been minted, then currentTokenId = 8 
            // and every minted token id belongs to _owner
            // It is impossible for someone to own a token id or have a balance greater than 
            // currentTokenId
            if(_owner == _ownerOf[currentId]) {
                // More gas efficient to use existing balance variable than create another 
                // to assign token ids to specific indexes within the array
                // If _balanceOf(_owner) = 8, then indexes 7, 6, 5, 4, 3, 2, 1, 0 are covered
                // in the tokenIds array and token ids are ordered from lowest to highest id
                tokenIds[--balance] = currentId;
                if(balance == 0) {
                    break;
                }
            }
        }
    }

    /// @notice This function allows tokens to be minted publicly and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mint(uint256 _amount) external payable {
        require(publicMint, "NFT.sol::mint() Public mint is not active");
        require(_amount <= MAX_RAFTS, "NFT.sol::mint() Amount requested exceeds maximum");
        require(currentTokenId + _amount <= TOTAL_RAFTS, "NFT.sol::mint() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= MAX_RAFTS, "NFT.sol::mint() Amount requested exceeds maximum tokens per address");
        require(msg.value == RAFT_PRICE * _amount, "NFT.sol::mint() Message value must be equal to the price of token(s)");

        amountMinted[msg.sender] += _amount;
        for(; _amount > 0; --_amount) {
            uint256 id = ++currentTokenId;
            _mint(msg.sender, id);
            _levelOf[id] = id;
        }
    }

    /// @notice This function allows tokens to be minted via whitelist and added to the total supply.
    /// @param _amount The amount of tokens to be minted.
    /// @param _proof  Merkle proof for the calling address.
    /// @dev Only 20 tokens can be minted per address. Will revert if current token id plus amount exceeds 10,000.
    function mintWhitelist(uint256 _amount, bytes32[] calldata _proof) external payable {
        require(whitelistMint, "NFT.sol::mintWhitelist() Whitelist mint is not active");
        require(_amount <= MAX_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds maximum");
        require(currentTokenId + _amount <= TOTAL_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds total supply");
        require(amountMinted[msg.sender] + _amount <= MAX_RAFTS, "NFT.sol::mintWhitelist() Amount requested exceeds maximum tokens per address");
        require(msg.value == RAFT_PRICE * _amount, "NFT.sol::mintWhitelist() Message value must be equal to the price of token(s)");
        require(MerkleProofLib.verify(_proof, whitelistRoot, keccak256(abi.encodePacked(msg.sender))), "NFT.sol::mintWhitelist() Address not whitelisted");

        amountMinted[msg.sender] += _amount;
        for(; _amount > 0; --_amount) {
            uint256 id = ++currentTokenId;
            _mint(msg.sender, id);
            _levelOf[id] = id;
        }
    }


    // ---------------
    // Owner Functions
    // ---------------

    /// @notice Receives and assigns entropy from Chainlink VRF.
    /// @dev This function must not revert per Chainlink VRF requirements.
    /// @dev Prevents state changes from future requests once entropy is fulfilled.
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        if(!fulfilled) {
            fulfilled = true;
            entropy = randomWords[0];
        }
    }

    /// @notice Requests one word of entropy from Chainlink VRF to shuffle the tokens.
    /// @dev Entropy can only be fulfilled once, but requested multiple times until fulfilled.
    function requestEntropy() external onlyOwner returns (uint256) {
        require(!fulfilled, "NFT.sol::requestEntropy() Entropy already fulfilled");
        return vrfCoordinatorV2.requestRandomWords(KEY_HASH, subId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS);
    }

    /// @notice Finalizes public and whitelist mint to prepare tokens to be shuffled.
    function finalizeMint() external onlyOwner {
        require(!finalized, "NFT.sol::finalizeMint() Mint already finalized");
        finalized = true;
        publicMint = false;
        whitelistMint = false;
    }

    /// @notice Randomly shuffles the levels of token ids using entropy fulfilled with Chainlink VRF.
    /// @dev Can only shuffle with tokens minted, mint finalized, entropy fulfilled, and tokens not shuffled.
    /// @dev Runtime of O(n) where n is the number of tokens minted.
    function shuffleLevels() external onlyOwner {
        require(currentTokenId != 0, "NFT.sol::shuffleLevels() No tokens to shuffle");
        require(finalized, "NFT.sol::shuffleLevels() Mint must be finalized");
        require(fulfilled, "NFT.sol::shuffleLevels() Entropy must be fulfilled");
        require(!shuffled, "NFT.sol::shuffleLevels() Levels already shuffled");
        
        shuffled = true;

        // This function will randomly shuffle the levels of all token ids
        // mapping(uint256 => uint256)
        // Given a token id, you get a level
        // Token ids and levels have a range of [1,currentTokenId]

        // Process:
        // A random token id is selected within the current range, [1,currentTokenId]
        // The random token id's level is swapped with the level of the last token id in the current range, currentTokenId
        // The level of token id currentTokenId is set in stone

        // A new random token id is selected within the range [1,currentTokenId-1], excluding token id currentTokenId
        // The random token id's level is swapped with the level of the last token id in the current range, currentTokenId-1
        // The level of token id currentTokenId-1 is set in stone

        // ...

        // At the end of this shuffling process each token id in range [1,currentTokenId] will have a random level

        // Knuth shuffle implementation wrapped in unchecked block
        // Overflow/underflow extremely unlikely given currentTokenId bound
        // If something bad happens here, then bigger problems are at hand
        unchecked {
            // Iterates over token ids from currentTokenId to 1
            // Finalizes levels for token ids starting with currentTokenId
            for(uint256 lastTokenId = currentTokenId; lastTokenId > 0; --lastTokenId) {
                // Generate a random token id between 1 and lastTokenId
                // Modulo operator generates values between 0 and lastTokenId-1
                // Adding 1 to the result shifts to values between 1 and lastTokenId
                uint256 randomTokenId = (entropy % lastTokenId) + 1;
                // Store the level of the random token id temporarily
                uint256 levelTmp = _levelOf[randomTokenId];
                // Update the random token id's level to last token id's level
                _levelOf[randomTokenId] = _levelOf[lastTokenId];
                // Update the last token id's level to the level of the random token id
                _levelOf[lastTokenId] = levelTmp;
            }
        }
    }

    /// @notice Updates the base URI for metadata stored on IPFS.
    /// @param _baseURI The IPFS URI pointing to the folder with JSON metadata for all tokens.
    /// @dev Must be of the format "ipfs://<CID>/“ where the CID references the folder with JSON metadata for all tokens.
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /// @notice Updates public mint state as long as mint has not been finalized.
    /// @param _state True if public mint is active, false if public mint is not active.
    function updatePublicMint(bool _state) external onlyOwner {
        require(!finalized, "NFT.sol::updatePublicMint() Mint is finalized");
        publicMint = _state;
    }

    /// @notice Updates whitelist mint state as long as mint has not been finalized.
    /// @param _state True if whitelist mint is active, false if whitelist mint is not active.
    function updateWhitelistMint(bool _state) external onlyOwner {
        require(!finalized, "NFT.sol::updateWhitelistMint() Mint is finalized");
        whitelistMint = _state;
    }

    /// @notice Allows owner to update the Chainlink VRF subscription id.
    /// @param _subId New Chainlink VRF subscription id.
    function updateSubId(uint64 _subId) external onlyOwner {
        subId = _subId;
    }

    /// @notice Updates the address of the multi-signature wallet to safe withdraw ERC20 tokens. 
    /// @param _multiSig Address of the multi-signature wallet.
    function updateMultiSig(address _multiSig) external onlyOwner {
        require(_multiSig != address(0), "NFT.sol::updateMultiSig() Address cannot be zero address");
        multiSig = _multiSig;
    }

    /// @notice Withdraws the entire ETH balance of this contract into the multisig wallet.
    /// @dev Call pattern adopted from the sendValue(address payable recipient, uint256 amount)
    ///      function in OZ's utils/Address.sol contract. "Please consider reentrancy potential" - OZ.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "NFT.sol::withdraw() Insufficient ETH balance");

        (bool success,) = multiSig.call{value: balance}("");
        require(success, "NFT.sol::withdraw() Unable to withdraw funds, recipient may have reverted");
    }

    /// @notice Withdraws any ERC20 token balance of this contract into the multisig wallet.
    /// @param _contract Address of an ERC20 compliant token. 
    function withdrawERC20(address _contract) external onlyOwner {
        require(_contract != address(0), "NFT.sol::withdrawERC20() Address cannot be zero address");

        uint256 balance = IERC20(_contract).balanceOf(address(this));
        require(balance > 0, "NFT.sol::withdrawERC20() Insufficient token balance");

        require(IERC20(_contract).transfer(multiSig, balance), "NFT.sol::withdrawERC20() Transfer failed on ERC20 contract");
    }
}