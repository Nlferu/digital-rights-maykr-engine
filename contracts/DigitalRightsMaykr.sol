// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./EIPs/ERC4671.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DateTime.sol";

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

    /// @dev Libraries
    using DateTime for uint256;

    /// @dev NFT Structs
    struct Certificate {
        string s_tokenIdToURI;
        string s_tokenIdToClause;
        address[] s_tokenIdToBorrower;
        uint256[] s_tokenIdToBorrowStart;
        uint256[] s_tokenIdToBorrowFinish;
        mapping(address => bool) s_tokenIdToBorrowerToValidity;
    }

    /// @dev NFT Mappings
    mapping(uint256 => Certificate) private certs;

    /// @dev NFT Events
    event NFT_TokenUriSet(string uri, uint256 indexed id);
    event NFT_ClauseCreated(address indexed owner, address indexed borrower, string statement, string expiration, uint256 indexed id);
    event NFT_CopyrightLended(uint256[] start, uint256[] end, bool validity, uint256 indexed id);

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
        // emit Minted(owner, tokenId); (from ERC4671)
        emit NFT_TokenUriSet(cert.s_tokenIdToURI, newTokenId);
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
        /// @dev caller should not be owner as this should be available for others
        /// @dev to call this you have to pay some LINK's
        /// @dev create function for creator to set his copyright borrowing price!
        if (ownerOf(tokenId) != msg.sender) revert DRM__NotOwnerOfToken();
        if (isValid(tokenId) == false) revert DRM__TokenNotValid();

        Certificate storage cert = certs[tokenId];

        // Updating Certificate Struct
        cert.s_tokenIdToBorrower.push(borrower);
        cert.s_tokenIdToBorrowStart.push(block.timestamp);
        cert.s_tokenIdToBorrowFinish.push(block.timestamp + lendingTime);
        cert.s_tokenIdToClause = clause(tokenId, lendingTime, borrower);
        cert.s_tokenIdToBorrowerToValidity[borrower] = true;

        emit NFT_CopyrightLended(cert.s_tokenIdToBorrowStart, cert.s_tokenIdToBorrowFinish, cert.s_tokenIdToBorrowerToValidity[borrower], tokenId);
    }

    /// @notice Creates clause between NFT(Certificate) creator and borrower
    /// @param tokenId Identifier of the copyright
    /// @param lendingTime Time period for, which copyrights will be lended
    /// @param borrower Address, which will get rights to use piece of art described in copyright
    function clause(uint256 tokenId, uint256 lendingTime, address borrower) internal returns (string memory) {
        uint256 endPeriod = block.timestamp + lendingTime;
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(endPeriod);

        string memory b = Strings.toHexString(uint256(uint160(msg.sender)), 20);
        string memory d = Strings.toHexString(uint256(uint160(borrower)), 20);
        string memory f = Strings.toString(tokenId);
        string memory h = Strings.toString(year);
        string memory i = Strings.toString(month);
        string memory j = Strings.toString(day);

        string memory clauseStatement = string(
            abi.encodePacked(
                "The Artist: ",
                b,
                " hereby grant the Borrower: ",
                d,
                " full and unrestricted rights to use piece of work described under tokenId: ",
                f,
                ". This clause will be valid until end of ",
                j,
                " ",
                i,
                " ",
                h,
                " DDMMYYYY"
            )
        );
        string memory expirationDate = string(abi.encodePacked("DDMMYYYY: ", j, " ", i, " ", h));

        emit NFT_ClauseCreated(msg.sender, borrower, clauseStatement, expirationDate, tokenId);

        return clauseStatement;
    }

    /// @notice Allows contract owner to revoke token with copyrights plagiarism
    /// @param tokenId Identifier of the copyright
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        _revoke(tokenId);
        // emit Revoked(token.owner, tokenId); (from ERC4671)
    }

    /// @notice Getters
    function getCertsBorrowers(uint256 tokenId) external view returns (address[] memory) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrower;
    }

    function getValidity(uint256 tokenId, address borrower) external view returns (bool) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowerToValidity[borrower];
    }

    function getClause(uint256 tokenId) external view returns (string memory) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToClause;
    }
}
