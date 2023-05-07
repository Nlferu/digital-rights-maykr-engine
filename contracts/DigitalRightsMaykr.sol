// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./EIPs/ERC4671.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error DRM__NotEnoughETH();
error DRM__NotOwnerOfToken();
error DRM__TokenNotValid();

contract DigitalRightsMaykr is ERC4671, Ownable {
    /** @dev How it should work from start to end:
     
    @notice Below have to be done off-chain to receive cert image
        1. User is filling certificate required fields (inclusing file hash encoding)
        2. Certificate image is being created with all filled data
        3. Certificate image is being uploaded into IPFS
        4. We have now created tokenURI to use in order to create our NFT
    @notice Below have to be done on-chain to create NFT, which will be our cert
        5. User is minting NFT (tokenId) with assigned tokenURI (option will show up on front after creating cert image)
        6. User can now borrow rights to use copyrights from his NFT (for certain time)
        7. Add option to revoke tokenId if it is confirmed as plagiarism
        8. Add chat option between wallets to communicate on chain

     @notice Off-Chain Idea 
     * Create NFT's database to trace copyrights existance (getters like totalSupply, description of token Id etc.)
    */

    // NFT Structs
    struct Certificate {
        string s_tokenIdToURI;
        address s_tokenIdToBorrower;
        uint256 s_tokenIdToBorrowStart;
        uint256 s_tokenIdToBorrowFinish;
    }

    // NFT Mappings
    mapping(uint256 => Certificate) private certs;

    // NFT Events
    event NFT_Minted(address indexed owner, string uri, uint256 indexed id);

    constructor() ERC4671("Digital Rights Maykr", "DRM") {}

    /// @notice Mint a new token
    /// @param createdTokenURI URI to assign for minted token
    function mintNFT(string memory createdTokenURI) external {
        // Counting certs from 0 per total created
        uint256 newTokenId = emittedCount();
        Certificate storage cert = certs[newTokenId];

        // Minting NFT (Certificate)
        _mint(msg.sender);
        // Assigning new tokenId to given tokenURI and to owner
        cert.s_tokenIdToURI = createdTokenURI;
        // Emiting all data associated with created NFT
        emit NFT_Minted(msg.sender, cert.s_tokenIdToURI, newTokenId);
    }

    /// @notice URI to query to get the token's metadata
    /// @param tokenId Identifier of the token
    /// @return URI for the token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Checking if given tokenId exists
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToURI;
    }

    /// @notice Gives permission to borrower to use copyrights assigned to tokenId
    /// @param tokenId Identifier of the copyright
    /// @param lendingTime time for how long permission will persist
    /// @param borrower address whom will receive permission
    function lendCopyrights(uint256 tokenId, uint256 lendingTime, address borrower) external {
        // Checking if given tokenId exists, not revoked and if caller is owner of given tokenId
        if (ownerOf(tokenId) != msg.sender) revert DRM__NotOwnerOfToken();
        if (isValid(tokenId) == false) revert DRM__TokenNotValid();

        Certificate storage cert = certs[tokenId];

        cert.s_tokenIdToBorrower = borrower;
        cert.s_tokenIdToBorrowStart = block.timestamp;
        cert.s_tokenIdToBorrowFinish = block.timestamp + lendingTime;
    }

    /// @notice Allows contract owner to revoke token with copyrights plagiarism
    /// @param tokenId Identifier of the copyright
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        _revoke(tokenId);
    }
}
