// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LoyaltyApp is ERC721, Ownable {
    // Token ID counter
    uint256 private tokenIdCounter;

    // Mapping to keep track of token burn status
    mapping(uint256 => bool) private isTokenBurnt;

    // Mapping to keep track of token balances
    mapping(address => mapping(uint256 => uint256)) private loyaltyPointsBalance;

    // Mapping to keep track of token expiration date
    mapping(uint256 => uint256) private tokenExpirationDate;

    // Flag to determine if token is transferable
    bool private isTokenTransferable;

    // Points expiration period (in seconds)
    uint256 private pointsExpirationPeriod;

    // Event emitted when a new token is minted
    event TokenMinted(address indexed user, uint256 indexed tokenId);

    // Event emitted when a token is burned
    event TokenBurned(address indexed user, uint256 indexed tokenId);

    // Event emitted when loyalty points are transferred
    event LoyaltyPointsTransferred(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount);

    // Event emitted when loyalty points are redeemed
    event LoyaltyPointsRedeemed(address indexed user, uint256 indexed tokenId, uint256 amount);

    // Modifier to check if token is transferable
    modifier onlyTransferable() {
        require(isTokenTransferable, "Token is not transferable");
        _;
    }

    constructor(uint256 expirationPeriod) ERC721("Loyalty Token", "LOYALTY") {
        tokenIdCounter = 1;
        isTokenBurnt[0] = true; // Reserve token ID 0 to represent a burnt token
        isTokenTransferable = false; // Token is not transferable by default
        pointsExpirationPeriod = expirationPeriod;
    }

    /**
     * @dev Mint a new token for the user.
     * Only the contract owner or an admin can call this function.
     * The admin can mint tokens for any address.
     */
    function mintToken(address user) external returns (uint256) {
        require(user != address(0), "Invalid user address");
        require(_msgSender() == owner() || isAdmin(_msgSender()), "Caller is not the owner or admin");

        uint256 newTokenId = tokenIdCounter;
        tokenIdCounter++;

        // Set the token expiration date to current time + expiration period
        tokenExpirationDate[newTokenId] = block.timestamp + pointsExpirationPeriod;

        // Mint new token
        _safeMint(user, newTokenId);

        emit TokenMinted(user, newTokenId);

        return newTokenId;
    }

    /**
     * @dev Check if a given address is in the admin role.
     */
    function isAdmin(address account) public view returns (bool) {
        // Add your own logic to determine admin role, e.g., using access control
        // For simplicity, we assume only the contract owner is the admin here
        return account == owner();
    }

    /**
     * @dev Burn a token.
     * The caller must be the owner of the token or the contract owner.
     */
    function burnToken(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not the owner nor approved");
        require(!isTokenBurnt[tokenId], "Token is already burnt");

        isTokenBurnt[tokenId] = true;
        _burn(tokenId);

        emit TokenBurned(_msgSender(), tokenId);
    }

    /**
     * @dev Set whether the token is transferable or not.
     * Only the contract owner can call this function.
     */
    function setTokenTransferability(bool transferable) external onlyOwner {
        isTokenTransferable = transferable;
    }

    /**
     * @dev Check if a token is burnt.
     */
    function isTokenBurned(uint256 tokenId) external view returns (bool) {
        return isTokenBurnt[tokenId];
    }
    
    /**
     * @dev Transfer loyalty points from one address to another.
     * Only the owner of the token can call this function.
     * The token must not be burnt and must be transferable.
     * @param to The address to which loyalty points are transferred.
     * @param tokenId The ID of the token whose loyalty points are transferred.
     * @param amount The amount of loyalty points to be transferred.
     */
    function transferLoyaltyPoints(address to, uint256 tokenId, uint256 amount) external {
        require(!_isBurntToken(tokenId), "Token is burnt");
        require(isTokenTransferable, "Token is not transferable");
        require(_msgSender() == ownerOf(tokenId), "Caller is not the token owner");
        require(to != address(0), "Invalid receiver address");

        // Reduce the loyalty points balance of the sender
        uint256 senderBalance = loyaltyPointsBalance[_msgSender()][tokenId];
        require(senderBalance >= amount, "Insufficient loyalty points balance");
        loyaltyPointsBalance[_msgSender()][tokenId] = senderBalance - amount;

        // Increase the loyalty points balance of the receiver
        loyaltyPointsBalance[to][tokenId] += amount;

        emit LoyaltyPointsTransferred(_msgSender(), to, tokenId, amount);
    }

    /**
     * @dev Redeem loyalty points for a specific token.
     * The caller must be the owner of the token.
     * The token must not be burnt and must not be expired.
     * @param tokenId The ID of the token for which loyalty points are redeemed.
     * @param amount The amount of loyalty points to be redeemed.
     */
    function redeemLoyaltyPoints(uint256 tokenId, uint256 amount) external {
        require(!_isBurntToken(tokenId), "Token is burnt");
        require(!_isTokenExpired(tokenId), "Token is expired");
        require(_msgSender() == ownerOf(tokenId), "Caller is not the token owner");

        uint256 senderBalance = loyaltyPointsBalance[_msgSender()][tokenId];
        require(senderBalance >= amount, "Insufficient loyalty points balance");
        
        // Deduct the redeemed loyalty points from the sender's balance
        loyaltyPointsBalance[_msgSender()][tokenId] = senderBalance - amount;

        emit LoyaltyPointsRedeemed(_msgSender(), tokenId, amount);
    }

    /**
     * @dev Get the loyalty points balance of a user for a specific token.
     * @param user The address of the user.
     * @param tokenId The ID of the token.
     * @return The loyalty points balance.
     */
    function getLoyaltyPointsBalance(address user, uint256 tokenId) external view returns (uint256) {
        return loyaltyPointsBalance[user][tokenId];
    }

    /**
     * @dev Check if the token is transferable.
     */
    function getTransferability() external view returns (bool) {
        return isTokenTransferable;
    }

    /**
     * @dev Check if a token is expired.
     */
    function isTokenExpired(uint256 tokenId) external view returns (bool) {
        return _isTokenExpired(tokenId);
    }

    /**
     * @dev Internal function to check if a token is burnt.
     */
    function _isBurntToken(uint256 tokenId) internal view returns (bool) {
        return isTokenBurnt[tokenId];
    }

    /**
     * @dev Internal function to check if a token is expired.
     */
    function _isTokenExpired(uint256 tokenId) internal view returns (bool) {
        return block.timestamp > tokenExpirationDate[tokenId];
    }
}