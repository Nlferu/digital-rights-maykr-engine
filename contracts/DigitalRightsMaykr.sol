// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./EIPs/ERC4671.sol";
import "./DateAndTime/DateTime.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/// @dev Errors
error DRM__NotEnoughETH();
error DRM__NotTokenOwner();
error DRM__TokenNotValid();
error DRM__TokenNotBorrowable();
error DRM__AddressHasRightsAlready();
error DRM__TokenAlreadyAllowed();
error DRM__TokenAlreadyBlocked();
error DRM__LicenseDoesNotExistsForThisUser();
error DRM__LicenseNotExpiredYetForThisUser();
error DRM__NothingToWithdraw();
error DRM__TransferFailed();
error DRM__UpkeepNotNeeded();

contract DigitalRightsMaykr is ERC4671, Ownable, ReentrancyGuard, AutomationCompatibleInterface {
    /** @dev How it should work from start to end:
     
    @notice Below have to be done off-chain to receive cert image in order to create tokenURI
        1. User is filling certificate required fields (including file hash encoding)
        2. Certificate image is being created with all filled data
        3. Certificate image is being uploaded into IPFS
        4. We have now created tokenURI to use in order to create our certificate (NFT)
    @notice Below have to be done on-chain to create NFT, which will be our certificate
        5. User is minting NFT (tokenId) with assigned tokenURI (option will show up on front-end after creating certificate image)
        6. Owner of created certificate can allow lending it for some ETH for specified time
        7. Another user's can now borrow rights to use invention described under specific tokenId (for certain time)
        8. We as contract owner's have only right to revoke tokenId if it is confirmed as plagiarism

    @notice Function "revokeCertificate()"
        This in future can be restricted by voting system (DAO). Once major of DRM protocol users vote that specific certificate
        breaks plagiarism rule it will be revoked, which will provide fully decentralized user experience.

    @notice Function "mintNFT()"
        This function in future can be restricted with minting price to provide some profits for DRM protocol creators.

    */

    /// @dev Libraries
    using DateTime for uint256;

    /// @dev Variables
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /// @dev Structs
    struct Certificate {
        string tokenIdToURI;
        uint256 tokenIdToTime;
        uint256 tokenIdToPrice;
        bool tokenIdToBorrowable;
        address[] tokenIdToBorrowers;
        mapping(address => uint256) tokenIdToBorrowToEnd;
        mapping(address => string) tokenIdToBorrowerToClause;
        mapping(address => bool) tokenIdToBorrowerToValidity;
    }

    /// @dev Mappings
    mapping(uint256 => Certificate) private s_certs;
    mapping(address => uint256) private s_proceeds;

    /// @dev Events
    event TokenUriSet(string uri, uint256 indexed id);
    event ClauseCreated(address indexed owner, address indexed borrower, string statement, string expiration, uint256 indexed id);
    event LendingLicenseCreated(uint256 indexed end, bool validity, uint256 indexed id);
    event ProceedsWithdrawal(uint256 indexed amount, address indexed lender, bool indexed transfer);
    event LendingAllowed(uint256 indexed price, uint256 indexed lendingTime, uint256 indexed id);
    event LendingBlocked(uint256 indexed id);
    event ExpiredLicensesRemoved(bool indexed performed);
    event LicenseRemoved(address indexed borrower, uint256 indexed id);

    constructor(uint256 interval) ERC4671("Digital Rights Maykr", "DRM") {
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    /// @dev This function in future can be restricted with minting price to provide some profits for DRM protocol creators.
    /// @notice Mint a new certificate (Token/NFT)
    /// @param createdTokenURI URI to assign for minted certificate
    function mintNFT(string calldata createdTokenURI) external {
        // Counting s_certs from 0 per total created
        uint256 newTokenId = emittedCount();
        Certificate storage cert = s_certs[newTokenId];

        // Minting NFT (Certificate)
        _mint(msg.sender);
        // Assigning new tokenId to given tokenURI and to owner
        cert.tokenIdToURI = createdTokenURI;
        // Emiting all data associated with created NFT
        // emit Minted(owner, tokenId); (from ERC4671)
        emit TokenUriSet(cert.tokenIdToURI, newTokenId);
    }

    /// @notice URI to query to get the certificate's metadata
    /// @param tokenId Identifier of certificate
    /// @return URI for the certificate
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Checking if given tokenId exists
        _getTokenOrRevert(tokenId);
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToURI;
    }

    /// @notice Gives permission to borrower to use copyrights assigned to specific certificate marked by tokenId
    /// @param tokenId Identifier of certificate
    /// @param borrower address whom will receive permission
    function buyLicense(uint256 tokenId, address borrower) external payable nonReentrant {
        // Checking if given tokenId exists, not revoked and if owner posted it for lending
        Certificate storage cert = s_certs[tokenId];
        if (ownerOf(tokenId) == borrower || cert.tokenIdToBorrowerToValidity[borrower]) revert DRM__AddressHasRightsAlready();
        if (isValid(tokenId) == false) revert DRM__TokenNotValid();
        if (!cert.tokenIdToBorrowable) revert DRM__TokenNotBorrowable();
        if (cert.tokenIdToPrice > msg.value) revert DRM__NotEnoughETH();

        uint256 lendingTime = getLendingPeriod(tokenId);

        // Updating Certificate Struct
        cert.tokenIdToBorrowers.push(borrower);
        cert.tokenIdToBorrowToEnd[borrower] = (block.timestamp + lendingTime);
        cert.tokenIdToBorrowerToClause[borrower] = createClause(tokenId, lendingTime, borrower);
        cert.tokenIdToBorrowerToValidity[borrower] = true;
        s_proceeds[ownerOf(tokenId)] += msg.value;

        emit LendingLicenseCreated(cert.tokenIdToBorrowToEnd[borrower], cert.tokenIdToBorrowerToValidity[borrower], tokenId);
    }

    /// @notice Creates clause between NFT(Certificate) creator and borrower
    /// @param tokenId Identifier of certificate
    /// @param lendingTime Time period for, which copyrights will be lended
    /// @param borrower Address, which will get rights to use piece of art described in copyright
    /// @return Complete Clause Statement Filled With Correct Data
    function createClause(uint256 tokenId, uint256 lendingTime, address borrower) internal returns (string memory) {
        uint256 endPeriod = block.timestamp + lendingTime;
        (uint256 year, uint256 month, uint256 day) = DateTime.timestampToDate(endPeriod);

        string memory b = Strings.toHexString(uint256(uint160(ownerOf(tokenId))), 20);
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

        emit ClauseCreated(msg.sender, borrower, clauseStatement, expirationDate, tokenId);

        return clauseStatement;
    }

    /// @notice Allows owner of tokenId(Certificate) to make this token borrowable by other users
    /// @param tokenId Identifier of certificate
    /// @param lendingTime time for how long permission will persist expressed in days
    /// @param price Amount of ETH (in Wei), for which license for this tokenId can be bought
    function allowLending(uint256 tokenId, uint256 lendingTime, uint256 price) external {
        // Checking if given tokenId exists and if function is called by token owner
        _getTokenOrRevert(tokenId);
        if (isValid(tokenId) == false) revert DRM__TokenNotValid();
        Certificate storage cert = s_certs[tokenId];
        if (ownerOf(tokenId) != msg.sender) revert DRM__NotTokenOwner();
        if (cert.tokenIdToBorrowable == true) revert DRM__TokenAlreadyAllowed();

        /// @dev Below @param timeUnit in production should be changed into "1 days" to set min time per borrow
        /// @param timeUnit for testing purposes is set to 1 second
        uint256 timeUnit = 1;
        uint256 lendingPeriod = timeUnit * lendingTime;

        emit LendingAllowed(price, lendingPeriod, tokenId);

        cert.tokenIdToPrice = price;
        cert.tokenIdToTime = lendingPeriod;
        cert.tokenIdToBorrowable = true;
    }

    /// @notice Allows owner of tokenId(Certificate) to make this token unborrowable
    /// @param tokenId Identifier of certificate
    function blockLending(uint256 tokenId) external {
        // Checking if given tokenId exists and if function is called by token owner
        _getTokenOrRevert(tokenId);
        Certificate storage cert = s_certs[tokenId];

        if (ownerOf(tokenId) != msg.sender) revert DRM__NotTokenOwner();
        if (cert.tokenIdToBorrowable == false) revert DRM__TokenAlreadyBlocked();

        emit LendingBlocked(tokenId);

        cert.tokenIdToBorrowable = false;
    }

    /// @dev This function in future can be restricted by voting and used only if major of users vote that specific certificate is plagiarism
    /// @notice Allows contract owner to revoke token with copyrights plagiarism
    /// @param tokenId Identifier of certificate
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        // Throws error if tokenId does not exists
        _revoke(tokenId);
        // emit Revoked(token.owner, tokenId); (from ERC4671)
    }

    /// @notice This is the function that the Chainlink Keeper nodes call to check if performing upkeep is needed
    /// @param upkeepNeeded returns true or false depending on 4 conditions
    function checkUpkeep(bytes memory /* checkData */) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        uint256 tokenId = emittedCount();

        // Array to store borrowers amount per tokenId
        uint256[] memory borrowersLength = new uint256[](tokenId);

        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasCerts = tokenId > 0;
        bool hasBorrowable = false;
        bool hasBorrowers = false;
        bool hasCertsToExpire = false;

        for (uint i = 0; i < tokenId; i++) {
            Certificate storage cert = s_certs[i];
            borrowersLength[i] = cert.tokenIdToBorrowers.length;
            if (cert.tokenIdToBorrowable == true) {
                hasBorrowable = true;
            }

            if (cert.tokenIdToBorrowers.length > 0) {
                hasBorrowers = true;
            }

            for (uint borrower = 0; borrower < borrowersLength[i]; borrower++) {
                if (cert.tokenIdToBorrowToEnd[cert.tokenIdToBorrowers[borrower]] < block.timestamp) {
                    hasCertsToExpire = true;
                    break;
                }
            }

            if (hasBorrowable && hasBorrowers && hasCertsToExpire) break;
        }

        upkeepNeeded = (timePassed && hasCerts && hasBorrowable && hasBorrowers && hasCertsToExpire);

        return (upkeepNeeded, "0x0");
    }

    /// @notice Once checkUpkeep() returns "true" this function is called to execute licenseStatusUpdater() function
    /// @notice It iterates thru all tokenId's and borrowers per those tokens to remove all licenses that have expired
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) revert DRM__UpkeepNotNeeded();

        // Array to store borrowers amount per tokenId
        uint256[] memory borrowersLength = new uint256[](emittedCount());

        for (uint tokenId = 0; tokenId < emittedCount(); tokenId++) {
            Certificate storage cert = s_certs[tokenId];
            // Updating borrowers array length per tokenId
            borrowersLength[tokenId] = cert.tokenIdToBorrowers.length;

            if (cert.tokenIdToBorrowable == true && borrowersLength[tokenId] > 0) {
                for (uint borrower = borrowersLength[tokenId] - 1; borrower >= 0; borrower--) {
                    if (cert.tokenIdToBorrowToEnd[cert.tokenIdToBorrowers[borrower]] < block.timestamp) {
                        licenseStatusUpdater(tokenId, cert.tokenIdToBorrowers[borrower]);
                    }
                    // Preventing loop error with negative counter value
                    if (borrower == 0) break;
                }
            }
        }

        emit ExpiredLicensesRemoved(true);
    }

    /// @dev This function has to be called by chainlink keeper once a day
    /// @notice Checks if license is still valid for given borrower and if it is not, it updates license status and it's data
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art described in certificate
    // Chainlink Keeper to be added
    function licenseStatusUpdater(uint256 tokenId, address borrower) internal licenseExpirationCheck(tokenId, borrower) {
        _getTokenOrRevert(tokenId);
        Certificate storage cert = s_certs[tokenId];

        // Removing borrower from array of borrowers for given tokenId
        for (uint i = 0; i < cert.tokenIdToBorrowers.length; i++) {
            if (cert.tokenIdToBorrowers[i] == borrower) {
                emit LicenseRemoved(borrower, tokenId);
                // Swapping borrower to be removed with last borrower in array
                cert.tokenIdToBorrowers[i] = cert.tokenIdToBorrowers[cert.tokenIdToBorrowers.length - 1];
                cert.tokenIdToBorrowers.pop();
            }
        }

        cert.tokenIdToBorrowerToValidity[borrower] = false;
        s_lastTimeStamp = block.timestamp;
    }

    /// @notice Allows lenders to withdraw their proceeds
    function withdrawProceeds() external payable nonReentrant {
        uint256 amount = s_proceeds[msg.sender];

        if (amount > 0) {
            s_proceeds[msg.sender] = 0;
        } else {
            revert DRM__NothingToWithdraw();
        }

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            s_proceeds[msg.sender] = amount;
            revert DRM__TransferFailed();
        }

        emit ProceedsWithdrawal(amount, msg.sender, success);
    }

    /// @notice Modifiers

    /// @notice Checks if given tokenId and borrower exists and if lending time expired (if it did not, it reverts)
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art described in certificate
    modifier licenseExpirationCheck(uint256 tokenId, address borrower) {
        _getTokenOrRevert(tokenId);
        Certificate storage cert = s_certs[tokenId];

        if (cert.tokenIdToBorrowToEnd[borrower] == 0) revert DRM__LicenseDoesNotExistsForThisUser();
        if (cert.tokenIdToBorrowToEnd[borrower] > block.timestamp) revert DRM__LicenseNotExpiredYetForThisUser();

        _;
    }

    /// @notice Getters

    /// @notice Tells if given borrower is allowed to use given certificate(tokenId)
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art described in certificate
    function getLicenseValidity(uint256 tokenId, address borrower) external view returns (bool) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToBorrowerToValidity[borrower];
    }

    /// @notice Returns all active borrowers of specific certificate(tokenId)
    /// @param tokenId Identifier of certificate
    function getCertsBorrowers(uint256 tokenId) external view returns (address[] memory) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToBorrowers;
    }

    /// @notice Returns clause for certain tokenId and borrower
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art described in certificate
    function getClause(uint256 tokenId, address borrower) external view returns (string memory) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToBorrowerToClause[borrower];
    }

    /// @notice Tells if given certificate(tokenId) is allowed to be borrowed by other users
    /// @param tokenId Identifier of certificate
    function getLendingStatus(uint256 tokenId) external view returns (bool) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToBorrowable;
    }

    /// @notice Tells if given certificate(tokenId) is allowed to be borrowed by other users
    /// @param tokenId Identifier of certificate
    /// @param borrower Address, which has rights to use specific piece of art described in certificate
    function getExpirationTime(uint256 tokenId, address borrower) external view returns (uint256) {
        Certificate storage cert = s_certs[tokenId];

        return (cert.tokenIdToBorrowToEnd[borrower] < block.timestamp) ? 0 : (cert.tokenIdToBorrowToEnd[borrower] - block.timestamp);
    }

    /// @notice Gives certificate lending price
    /// @param tokenId Identifier of certificate
    function getCertificatePrice(uint256 tokenId) external view returns (uint256) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToPrice;
    }

    /// @notice Gives certificate lending price
    /// @param tokenId Identifier of certificate
    function getLendingPeriod(uint256 tokenId) internal view returns (uint256) {
        Certificate storage cert = s_certs[tokenId];

        return cert.tokenIdToTime;
    }

    /// @notice Gives amount of ETH available to withdraw by certificate lender
    /// @param lender Address, which we are checking
    function getProceeds(address lender) external view returns (uint256) {
        return s_proceeds[lender];
    }
}
