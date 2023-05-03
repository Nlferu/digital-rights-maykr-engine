// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./EIPs/ERC4671.sol";
import "./ERC4671URIStorage.sol";

contract DigitalRightsMaykr is ERC4671 {
    /** @dev Functions To Implement:
     * mint NFT - our NFT will represent certificate
     * (minting unrestricted)
     * (NFT minter will be immediately it's owner)

     * Use ERC4671 for owner to proof he is creator of something
     * Use Simple Contract to manage his nft's if he want to borrow license to someone for certain time to use his invention (and get money for it)
     * Add chat between wallet's, so users can communicate and exchange certs rights to use
     * 
     * Revoke for us to remove copyright plagiarism (To be considered)
     * 
     * create NFT's database to trace copyrights existance (getters like totalSupply, description of token Id etc.) (Out of contract)
    */

    // NFT Structs
    struct Certificate {
        string s_tokenIdToURI;
        uint256 s_tokenIdToExpirationTime;
    }

    // NFT Mappings
    mapping(uint256 => Certificate) private certs;

    // NFT Events
    event NFT_Minted(address indexed owner, string uri, uint256 indexed id);

    constructor() ERC721A("Digital Rights Maykr", "DRM") {}

    /** @dev Add expiration time of certificate?? */
    // We can try to use NFT Storage to get all created certs under similar tokenURI
    function mintNFT(string memory createdTokenURI) external {
        // Assigning 0 to first tokenId created
        uint256 newTokenId = totalSupply();
        Certificate storage cert = certs[newTokenId];

        // Minting NFT (Certificate)
        _mint(msg.sender, 1);

        // Assigning new tokenId to given tokenURI and to owner
        cert.s_tokenIdToURI = createdTokenURI;

        // Emiting all data associated with created NFT
        emit NFT_Minted(msg.sender, cert.s_tokenIdToURI, newTokenId);
    }

    // Assigning correct tokenURI per tokenId to function from ERC721A
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        Certificate storage cert = certs[tokenId];
        return cert.s_tokenIdToURI;
    }

    // Communicate with certificates owners, should be restricted to only existing on our service
    function sendMessage(address to, string calldata yourMessage) external {
        //message memory newMessage = message(msg.sender, block.timestamp, yourMessage);
    }

    // We can try to do it without below
    function readMessage() external {}
}
