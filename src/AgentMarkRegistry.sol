// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal read interface of the SPACE ID Agent ID NFT (ERC-721) on BNB Chain.
/// @dev Only the two functions this registry relies on — both verified live on-chain
///      against 0x60b9262456de011f7d15a54cdd8c48baaa8b022f (see RESEARCH.md).
///      The Agent ID contract does NOT implement ERC-721 Enumerable, so
///      tokenOfOwnerByIndex must never be used; a tokenId is derived from the
///      name label as uint256(keccak256(bytes(label))) and proven via ownerOf.
interface IAgentId {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title AgentMarkRegistry
/// @notice On-chain service registry and endorsement ledger where every identity
///         is a SPACE ID Agent ID. Only Agent ID holders can register a service
///         listing or endorse another Agent ID, so listings and reputation are
///         sybil-resistant (one verified human = one Agent ID, non-transferable).
///
/// @dev OWNER PERMISSIONS — stated openly, as required:
///      This contract has NO owner and NO admin. There is no mint function, no
///      tax, no pause, no freeze, and no function that can move or withdraw
///      user funds. Every state-changing function is nonpayable: the contract
///      never receives or holds BNB or tokens. The Agent ID contract address
///      is fixed forever as an `immutable` at deployment. Nobody — including
///      the deployer — can change the rules after deployment.
contract AgentMarkRegistry {
    /// @notice The Agent ID (SPACE ID ".ai") NFT contract on BNB Chain.
    IAgentId public immutable agentId;

    struct Listing {
        address owner; // wallet that owns the Agent ID tokenId and registered
        bytes32 category; // e.g. keccak256("research"), keccak256("dev")…
        string metadataURI; // off-chain JSON: service name, description, contact
        uint64 updatedAt; // last register/update block timestamp
        bool active;
    }

    mapping(uint256 => Listing) private _listings; // agentTokenId => listing
    mapping(address => uint256) private _tokenIdByOwner; // registrant => agentTokenId
    mapping(uint256 => uint256) private _endorsementTotal; // agentTokenId => count
    mapping(uint256 => mapping(bytes32 => uint256)) private _endorsementByTag;
    mapping(bytes32 => bool) private _endorsementGiven; // uniqueness guard

    uint256 public totalListings;
    uint256 public totalEndorsements;

    event ServiceRegistered(uint256 indexed agentTokenId, address indexed owner, bytes32 category);
    event ServiceRemoved(uint256 indexed agentTokenId, address indexed owner);
    event Endorsed(uint256 indexed endorserTokenId, uint256 indexed targetTokenId, bytes32 skillTag);

    error NoAgentId(address caller);
    error NotTokenOwner(uint256 tokenId, address caller);
    error SelfEndorsement(uint256 tokenId);
    error AlreadyEndorsed(uint256 endorserTokenId, uint256 targetTokenId, bytes32 skillTag);
    error NoActiveListing(address caller);
    error EmptyMetadata();

    constructor(address agentIdContract) {
        agentId = IAgentId(agentIdContract);
    }

    /// @notice True if `user` holds at least one Agent ID.
    function hasAgentId(address user) public view returns (bool) {
        return agentId.balanceOf(user) > 0;
    }

    /// @notice Register (or update) the service listing bound to your Agent ID.
    /// @param agentTokenId Your Agent ID tokenId (= uint256(keccak256(bytes(label)))).
    /// @param category Coarse service category tag.
    /// @param metadataURI Pointer to a JSON describing the service offered.
    function registerService(uint256 agentTokenId, bytes32 category, string calldata metadataURI) external {
        if (!hasAgentId(msg.sender)) revert NoAgentId(msg.sender);
        if (agentId.ownerOf(agentTokenId) != msg.sender) revert NotTokenOwner(agentTokenId, msg.sender);
        if (bytes(metadataURI).length == 0) revert EmptyMetadata();

        Listing storage listing = _listings[agentTokenId];
        if (!listing.active) {
            totalListings += 1;
        }
        listing.owner = msg.sender;
        listing.category = category;
        listing.metadataURI = metadataURI;
        listing.updatedAt = uint64(block.timestamp);
        listing.active = true;
        _tokenIdByOwner[msg.sender] = agentTokenId;

        emit ServiceRegistered(agentTokenId, msg.sender, category);
    }

    /// @notice Remove your own service listing.
    function removeService() external {
        uint256 agentTokenId = _tokenIdByOwner[msg.sender];
        Listing storage listing = _listings[agentTokenId];
        if (!listing.active || listing.owner != msg.sender) revert NoActiveListing(msg.sender);
        listing.active = false;
        listing.metadataURI = "";
        totalListings -= 1;
        emit ServiceRemoved(agentTokenId, msg.sender);
    }

    /// @notice Endorse another Agent ID for a skill. Both sides must be Agent IDs.
    /// @param endorserTokenId Your own Agent ID tokenId (proven via ownerOf).
    /// @param targetTokenId The Agent ID being endorsed.
    /// @param skillTag The skill being endorsed, e.g. keccak256("research").
    function endorse(uint256 endorserTokenId, uint256 targetTokenId, bytes32 skillTag) external {
        if (!hasAgentId(msg.sender)) revert NoAgentId(msg.sender);
        if (agentId.ownerOf(endorserTokenId) != msg.sender) revert NotTokenOwner(endorserTokenId, msg.sender);
        // Reverts inside the Agent ID contract if the target token does not exist.
        address targetOwner = agentId.ownerOf(targetTokenId);
        if (targetOwner == msg.sender) revert SelfEndorsement(targetTokenId);

        bytes32 key = keccak256(abi.encode(endorserTokenId, targetTokenId, skillTag));
        if (_endorsementGiven[key]) revert AlreadyEndorsed(endorserTokenId, targetTokenId, skillTag);
        _endorsementGiven[key] = true;

        _endorsementTotal[targetTokenId] += 1;
        _endorsementByTag[targetTokenId][skillTag] += 1;
        totalEndorsements += 1;

        emit Endorsed(endorserTokenId, targetTokenId, skillTag);
    }

    /// @notice Full listing for an Agent ID tokenId.
    function listingOf(uint256 agentTokenId) external view returns (Listing memory) {
        return _listings[agentTokenId];
    }

    /// @notice The Agent ID tokenId a wallet registered with (0 if none).
    function tokenIdOf(address owner) external view returns (uint256) {
        return _tokenIdByOwner[owner];
    }

    /// @notice Total endorsements received by an Agent ID.
    function endorsementCount(uint256 agentTokenId) external view returns (uint256) {
        return _endorsementTotal[agentTokenId];
    }

    /// @notice Endorsements received by an Agent ID for one skill tag.
    function endorsementCountByTag(uint256 agentTokenId, bytes32 skillTag) external view returns (uint256) {
        return _endorsementByTag[agentTokenId][skillTag];
    }

    /// @notice Whether `endorserTokenId` already endorsed `targetTokenId` for `skillTag`.
    function hasEndorsed(uint256 endorserTokenId, uint256 targetTokenId, bytes32 skillTag) external view returns (bool) {
        return _endorsementGiven[keccak256(abi.encode(endorserTokenId, targetTokenId, skillTag))];
    }
}
