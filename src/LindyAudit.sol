// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @notice On-chain audit registry. Each audited address gets a non-transferable
///         NFT whose tokenId = uint256(uint160(address)). Auditors (assigned by
///         owner) and the owner can mint, update metadata, and burn entries.
contract LindyAudit is ERC721, Ownable {
    mapping(address => bool) public isAuditor;
    mapping(uint256 => string) _tokenURIs;

    error NotAuthorized();
    error AlreadyMinted();

    event Audited(address indexed auditor, address indexed auditedAddress, string uri);
    event AuditorSet(address indexed account, bool status);
    event URIUpdated(uint256 indexed tokenId, string uri);

    modifier onlyAuthorized() {
        if (msg.sender != owner() && !isAuditor[msg.sender]) revert NotAuthorized();
        _;
    }

    constructor() payable {
        _initializeOwner(tx.origin);
    }

    function name() public pure override(ERC721) returns (string memory) {
        return "Lindy Audit";
    }

    function symbol() public pure override(ERC721) returns (string memory) {
        return "LAUDIT";
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        return _tokenURIs[tokenId];
    }

    // ── Role management ──────────────────────────────────────────────

    function setAuditor(address account, bool status) public onlyOwner {
        isAuditor[account] = status;
        emit AuditorSet(account, status);
    }

    // ── Mint / update / burn ─────────────────────────────────────────

    function mint(address auditedAddress, string calldata uri) public onlyAuthorized {
        uint256 tokenId = _tokenIdOf(auditedAddress);
        if (_exists(tokenId)) revert AlreadyMinted();
        _mint(auditedAddress, tokenId);
        _tokenURIs[tokenId] = uri;
        emit Audited(msg.sender, auditedAddress, uri);
    }

    function updateURI(uint256 tokenId, string calldata uri) public onlyAuthorized {
        if (!_exists(tokenId)) revert TokenDoesNotExist();
        _tokenURIs[tokenId] = uri;
        emit URIUpdated(tokenId, uri);
    }

    function burn(uint256 tokenId) public onlyAuthorized {
        _burn(tokenId);
        delete _tokenURIs[tokenId];
    }

    // ── Soulbound: disable all transfers ─────────────────────────────

    function approve(address, uint256) public payable override(ERC721) {
        revert("SOULBOUND");
    }

    function setApprovalForAll(address, bool) public pure override(ERC721) {
        revert("SOULBOUND");
    }

    function transferFrom(address, address, uint256) public payable override(ERC721) {
        revert("SOULBOUND");
    }

    // ── Helpers ──────────────────────────────────────────────────────

    function _tokenIdOf(address addr) internal pure returns (uint256) {
        return uint256(uint160(addr));
    }

    function tokenIdOf(address addr) public pure returns (uint256) {
        return _tokenIdOf(addr);
    }
}
