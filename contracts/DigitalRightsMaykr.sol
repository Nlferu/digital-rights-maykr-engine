// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @dev Check contract on Remix and fix bugs with lending certificates!

import "./EIPs/ERC4671.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DateTime.sol";

error DRM__NotEnoughETH();
error DRM__NotTokenOwner();
error DRM__TokenNotValid();
error DRM__TokenNotBorrowable();
error DRM__AddressHasRightsAlready();
error DRM__TokenAlreadyAllowed();
error DRM__TokenAlreadyBlocked();
error DRM__LicenseDoesNotExistsForThisUser();
error DRM__LicenseExpiredForThisUser();

contract DigitalRightsMaykr is ERC4671, Ownable {
    /** @dev How it should work from start to end:
     
    @notice Below have to be done off-chain to receive cert image in order to create tokenURI
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
        bool s_tokenIdToBorrowable;
        address[] s_tokenIdToBorrowers;
        //mapping(address => uint256) s_tokenIdToBorrowToStart;
        // mapping(address => uint256[]) s_tokenIdToBorrowerToCerts; -> create to read all borrowed tokenId's
        mapping(address => uint256) s_tokenIdToBorrowToEnd;
        mapping(address => string) s_tokenIdToBorrowerToClause;
        mapping(address => bool) s_tokenIdToBorrowerToValidity;
    }

    /// @dev NFT Mappings
    mapping(uint256 => Certificate) private certs;

    /// @dev NFT Events
    event NFT_TokenUriSet(string uri, uint256 indexed id);
    event NFT_ClauseCreated(address indexed owner, address indexed borrower, string statement, string expiration, uint256 indexed id);
    event NFT_LendingLicenseCreated(uint256 indexed end, bool validity, uint256 indexed id);

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
    /// @param tokenId Identifier of certificate
    /// @return URI for the token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Checking if given tokenId exists
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToURI;
    }

    /// @notice Gives permission to borrower to use copyrights assigned to specific certificate marked by tokenId
    /// @param tokenId Identifier of certificate
    /// @param lendingTime time for how long permission will persist
    /// @param borrower address whom will receive permission
    function buyLicense(uint256 tokenId, uint256 lendingTime, address borrower) external {
        // Checking if given tokenId exists, not revoked and if owner posted it for lending
        /// @dev caller should not be owner as this should be available for others
        /// @dev to call this you have to pay some LINK's, ower can lend copyrights
        /// @dev create function for creator to set his copyright borrowing price!
        Certificate storage cert = certs[tokenId];
        if (ownerOf(tokenId) == borrower || cert.s_tokenIdToBorrowerToValidity[borrower]) revert DRM__AddressHasRightsAlready();
        if (!cert.s_tokenIdToBorrowable) revert DRM__TokenNotBorrowable();
        if (isValid(tokenId) == false) revert DRM__TokenNotValid();

        // Updating Certificate Struct
        cert.s_tokenIdToBorrowers.push(borrower);
        //cert.s_tokenIdToBorrowToStart[borrower] = block.timestamp;
        cert.s_tokenIdToBorrowToEnd[borrower] = (block.timestamp + lendingTime);
        cert.s_tokenIdToBorrowerToClause[borrower] = createClause(tokenId, lendingTime, borrower);
        cert.s_tokenIdToBorrowerToValidity[borrower] = true;

        emit NFT_LendingLicenseCreated(cert.s_tokenIdToBorrowToEnd[borrower], cert.s_tokenIdToBorrowerToValidity[borrower], tokenId);
    }

    /// @notice Creates clause between NFT(Certificate) creator and borrower
    /// @param tokenId Identifier of certificate
    /// @param lendingTime Time period for, which copyrights will be lended
    /// @param borrower Address, which will get rights to use piece of art described in copyright
    /// @return Complete Clause Statement Filled With Correct Data
    function createClause(uint256 tokenId, uint256 lendingTime, address borrower) internal returns (string memory) {
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

    /// @notice Allows owner of tokenId(Certificate) to make this token borrowable by other users
    /// @param tokenId Identifier of certificate
    function allowLending(uint256 tokenId) external {
        // Checking if given tokenId exists and if function is called by token owner
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];

        if (ownerOf(tokenId) != msg.sender) revert DRM__NotTokenOwner();
        if (cert.s_tokenIdToBorrowable == true) revert DRM__TokenAlreadyAllowed();

        cert.s_tokenIdToBorrowable = true;
    }

    /// @notice Allows owner of tokenId(Certificate) to make this token unborrowable
    /// @param tokenId Identifier of certificate
    function blockLending(uint256 tokenId) external {
        // Checking if given tokenId exists and if function is called by token owner
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];

        if (ownerOf(tokenId) != msg.sender) revert DRM__NotTokenOwner();
        if (cert.s_tokenIdToBorrowable == false) revert DRM__TokenAlreadyBlocked();

        cert.s_tokenIdToBorrowable = false;
    }

    /// @notice Allows contract owner to revoke token with copyrights plagiarism
    /// @param tokenId Identifier of certificate
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        // Throws error if tokenId does not exists
        _revoke(tokenId);
        // emit Revoked(token.owner, tokenId); (from ERC4671)
    }

    /// @dev This function has to be called by chainlink keeper
    // Function is not setting false at 2nd time -> tests required
    function licenseStatusUpdater(uint256 tokenId, address borrower) external {
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];

        if (cert.s_tokenIdToBorrowToEnd[borrower] < block.timestamp) {
            cert.s_tokenIdToBorrowerToValidity[borrower] = false;
            //revert NFT_LicenseUpdated();
        }
    }

    /// @notice Modifiers
    /// @dev This can be probably removed
    modifier licenseExpirationCheck(uint256 tokenId, address borrower) {
        _getTokenOrRevert(tokenId);
        Certificate storage cert = certs[tokenId];
        //if(cert.s_tokenIdToBorrower is borrower) revert DRM__LicenseDoesNotExistsForThisUser();

        if (cert.s_tokenIdToBorrowToEnd[borrower] < block.timestamp) {
            revert DRM__LicenseExpiredForThisUser();
        }
        _;
    }

    /// @notice Getters
    /// @notice Returns all active borrowers of specific certificate(tokenId)
    /// @param tokenId Identifier of certificate
    function getCertsBorrowers(uint256 tokenId) external view returns (address[] memory) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowers;
    }

    /// @notice Tells if given borrower is allowed to use given certificate(tokenId)
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art
    function getValidity(uint256 tokenId, address borrower) external view returns (bool) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowerToValidity[borrower];
    }

    /// @notice Returns clause for certain tokenId and borrower
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art
    function getClause(uint256 tokenId, address borrower) external view returns (string memory) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowerToClause[borrower];
    }

    /// @notice Tells if given certificate(tokenId) is allowed to be borrowed by other users
    /// @param tokenId Identifier of certificate
    function getLicenseStatus(uint256 tokenId) external view returns (bool) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowable;
    }

    // function getStart(uint256 tokenId, address borrower) external view returns (uint256) {
    //     Certificate storage cert = certs[tokenId];

    //     return cert.s_tokenIdToBorrowToStart[borrower];
    // }

    function getEnd(uint256 tokenId, address borrower) external view returns (uint256) {
        Certificate storage cert = certs[tokenId];

        return cert.s_tokenIdToBorrowToEnd[borrower];
    }

    function getExpirationTime(uint256 tokenId, address borrower) external view returns (uint256) {
        Certificate storage cert = certs[tokenId];

        return (cert.s_tokenIdToBorrowToEnd[borrower] < block.timestamp) ? 0 : (cert.s_tokenIdToBorrowToEnd[borrower] - block.timestamp);
    }
}
