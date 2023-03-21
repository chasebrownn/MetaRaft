// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { Owned } from "./bases/Owned.sol";
import { IRaft721 } from "./interfaces/IRaft721.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

/// @notice MetaRaft Prizes Distribution
/// @author Andrew Thomas
contract Prizes is Owned {

    // ---------------
    // State Variables
    // ---------------

    // ---- LEVEL, PRIZE, AND CLAIM INFO ----

    /// @notice Level threshold for tier one prizes.
    /// @dev [2,11] 11-2+1 = 10 total
    uint256 public constant TIER_ONE_LEVELS = 1;
    /// @notice Level threshold for tier two prizes.
    /// @dev [12,111] 111-12+1 = 100 total
    uint256 public constant TIER_TWO_LEVELS = 11;
    /// @notice Level threshold for tier three prizes.
    /// @dev [112,511] 511-112+1 = 400 total
    uint256 public constant TIER_THREE_LEVELS = 111;
    /// @notice Level threshold for tier four prizes.
    /// @dev [512,2511] 2511-512+1 = 2000 total
    uint256 public constant TIER_FOUR_LEVELS = 511;    
    /// @notice Tier five prize level threshold. 
    /// @dev [2512,10000] = 10000-2512+1 = 7489 total
    uint256 public constant TIER_FIVE_LEVELS = 2511;

    /// @notice Decimals of USDC ERC20 implementation for prize values.
    uint256 public constant STABLE_DECIMALS = 10**6;
    /// @notice Stable currency value for tier one prizes.
    uint256 public constant TIER_ONE_PRIZE = 0;
    /// @notice Stable currency value for tier two prizes.
    uint256 public constant TIER_TWO_PRIZE = 10_000 * STABLE_DECIMALS;
    /// @notice Stable currency value for tier four prizes.
    uint256 public constant TIER_FOUR_PRIZE = 500 * STABLE_DECIMALS;
    /// @notice Stable currency value for tier five prizes.
    uint256 public constant TIER_FIVE_PRIZE = 250 * STABLE_DECIMALS;
    /// @notice Stable currency value for tier three prizes.
    uint256 public constant TIER_THREE_PRIZE = 1000 * STABLE_DECIMALS;
    /// @notice Tier six prize value.
    uint256 public constant TIER_SIX_PRIZE = 0;


    /// NOTE:
    /// Should we include some sort of reference to the series these prizes came from or
    /// the nft contract or would this be irrelevant?

    /// @notice Struct of prize information for tokens.
    struct Prize {
        // Prize recipient address, default value is zero address
        address recipient;
        // Prize claim status, default value is unclaimed (false)
        bool claimed;
    }
    /// @dev Returns the prize recipient and claim status for a given token id.
    mapping(uint256 => Prize) public prizeInfo;

    /// @notice Used to track the start of the claiming period.
    uint256 public claimStart;
    /// @notice Used to track the end of the claiming period.
    uint256 public claimEnd;


    // ---- CONTRACT, TOKEN, AND WALLET ADDRESSES ----

    /// @notice Used to store the address of the NFT contract.
    IRaft721 public immutable nftContract;
    /// @notice Address of stablecoin used as the prize currency.
    IERC20 public immutable stableCurrency;
    /// @notice Address of multi-signature wallet for ERC20 deposits.
    address public multiSig;


    // -----------
    // Constructor
    // -----------

    /// @notice Initializes Prizes.sol.
    /// @param _nftContract Contract address of the NFT.
    /// @param _stableCurrency Contract address of stablecoin used for prizes (default is USDC).
    /// @param _multiSig Address of multi-signature wallet.
    constructor(
        address _nftContract, 
        address _stableCurrency, 
        address _multiSig
    )
        Owned(msg.sender) 
    {
        nftContract = IRaft721(_nftContract);
        stableCurrency = IERC20(_stableCurrency);
        multiSig = _multiSig;
    }


    // ------
    // Events
    // ------

    /// NOTE:
    /// Should we include the NFT contract address since we'll have multiple deployments 
    /// and these signatures could become confusing overtime?
    event PrizeClaimed(
        address indexed recipient,
        uint256 indexed id,
        uint256 level,
        uint256 prize
    );


    // ----------------
    // Public Functions
    // ----------------

    /// @notice Returns the prize in stable currency for a given token level.
    /// @param _level Token level.
    function prizeOf(uint256 _level) public pure returns (uint256) {
        // Levels [2512...10000]    Tier Six
        if(_level > TIER_FIVE_LEVELS) {
            return TIER_SIX_PRIZE;
        }
        // Levels [512...2511]      Tier Five
        else if(_level > TIER_FOUR_LEVELS) {
            return TIER_FIVE_PRIZE;
        }
        // Levels [112...511]       Tier Four
        else if(_level > TIER_THREE_LEVELS) {
            return TIER_FOUR_PRIZE;
        }
        // Levels [12...111]        Tier Three
        else if(_level > TIER_TWO_LEVELS) {
            return TIER_THREE_PRIZE;
        }
        // Levels [2...11]          Tier Two
        else if(_level > TIER_ONE_LEVELS) {
            return TIER_TWO_PRIZE;
        }
        // Level 1                  Tier One
        else {
            return TIER_ONE_PRIZE;
        }
    }


    // ------------------
    // External Functions
    // ------------------

    /// @notice Returns a boolean representing the claim status for a given token id.
    /// @param _tokenId Token id.
    /// @dev True indicates prize was claimed, false indicates prize is unclaimed.
    function prizeStatus(uint256 _tokenId) external view returns (bool) {
        return prizeInfo[_tokenId].claimed;
    }

    /// @notice Returns the address that claimed the prize associated with a given token id.
    /// @param _tokenId Token id.
    /// @dev Zero address indicates prize is unclaimed, nonzero address indicates prize was claimed.
    function prizeRecipient(uint256 _tokenId) external view returns (address) {
        return prizeInfo[_tokenId].recipient;
    }

    /// @notice Allows the owner of a token id to claim its associated prize if unclaimed.
    /// @param _tokenId Token id.
    /// @return prize Amount received.
    /// @dev Token ids with levels between 1 and 2511 have prizes available to claim.
    /// @dev The level 1 token id owner must claim their prize directly from the NFT team.
    function claimPrize(uint256 _tokenId) external returns (uint256 prize) {
        require(claimStart < block.timestamp, "Prizes.sol::claimPrize() Claiming period has not started");
        require(claimEnd > block.timestamp, "Prizes.sol::claimPrize() Claiming period has already ended");
        require(!prizeInfo[_tokenId].claimed, "Prizes.sol::claimPrize() Prize already claimed for the token");
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Prizes.sol::claimPrize() Address is not the token owner");
        uint256 level = nftContract.levelOf(_tokenId);
        prize = prizeOf(level);

        // Update first before transfer
        prizeInfo[_tokenId].claimed = true;
        prizeInfo[_tokenId].recipient = msg.sender;

        // Send non zero gifts using IERC20 etc
        if(prize != 0) {
            require(stableCurrency.balanceOf(address(this)) >= prize, "Prizes.sol::claimPrize() Insufficient balance for prize");
            require(stableCurrency.transfer(msg.sender, prize), "Prizes.sol::claimPrize() Transfer failed on stable currency");
        }

        emit PrizeClaimed(
            msg.sender,
            _tokenId,
            level,
            prize
        );
    }


    // ---------------
    // Owner Functions
    // ---------------

    /// NOTE:
    /// Should probably make this settable once..? Not sure of legalities behind being able to set
    /// these values multiple times but it definitely doesn't make the project look that good.

    /// @notice Sets the 7 day gift claiming period starting at the current block's timestamp.
    function setClaimPeriod() external onlyOwner {
        claimStart = block.timestamp;
        claimEnd = block.timestamp + 7 days;
    }

    /// NOTE:
    /// Should probably establish reasonable bounds so that claims are not available forever. 
    /// Even so, not having bounds would not hurt any functionality.

    /// @notice Allows owner to override the timestamp when the gift claiming period ends.
    /// @param _claimEnd New timestamp for the end of the gift claiming period.
    function overrideClaimEnd(uint256 _claimEnd) external onlyOwner {
        claimEnd = _claimEnd;
    }

    /// @notice Updates the address of the multi-signature wallet to safe withdraw ERC20 tokens. 
    /// @param _multiSig Address of the multi-signature wallet.
    function updateMultiSig(address _multiSig) external onlyOwner {
        require(_multiSig != address(0), "Prizes.sol::updateMultiSig() Address cannot be zero address");
        multiSig = _multiSig;
    }

    /// @notice Withdraws any ERC20 token balance of this contract into the multi-sig wallet.
    /// @dev Withdraws stable currency token balance into the Circle account.
    /// @param _contract Address of an ERC20 compliant token. 
    function withdrawERC20(address _contract) external onlyOwner {
        require(_contract != address(0), "Prizes.sol::withdrawERC20() Address cannot be zero address");

        uint256 balance = IERC20(_contract).balanceOf(address(this));
        require(balance > 0, "Prizes.sol::withdrawERC20() Insufficient token balance");
        require(IERC20(_contract).transfer(multiSig, balance), "Prizes.sol::withdrawERC20() Transfer failed on ERC20 contract");
    }
}