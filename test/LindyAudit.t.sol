// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {LindyAudit} from "../src/LindyAudit.sol";

contract LindyAuditTest is Test {
    LindyAudit audit;
    address owner = address(0xA);
    address auditor = address(0xB);
    address target = address(0xC);
    address nobody = address(0xD);

    function setUp() public {
        // tx.origin must be set before deployment for the constructor
        vm.prank(owner, owner);
        audit = new LindyAudit();
    }

    // ── Deployment ──────────────────────────────────────────────────

    function test_ownerSetToTxOrigin() public view {
        assertEq(audit.owner(), owner);
    }

    function test_nameAndSymbol() public view {
        assertEq(audit.name(), "Lindy Audit");
        assertEq(audit.symbol(), "LAUDIT");
    }

    function test_supportsERC721Interface() public view {
        assertTrue(audit.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(audit.supportsInterface(0x01ffc9a7)); // ERC165
    }

    // ── Factory deployment (tx.origin != msg.sender) ────────────────

    function test_factoryDeploy() public {
        address factory = address(0xF);
        // msg.sender = factory, tx.origin = owner
        vm.prank(factory, owner);
        LindyAudit factoryAudit = new LindyAudit();
        assertEq(factoryAudit.owner(), owner);
    }

    // ── Role management ─────────────────────────────────────────────

    function test_ownerCanSetAuditor() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);
        assertTrue(audit.isAuditor(auditor));
    }

    function test_nonOwnerCannotSetAuditor() public {
        vm.prank(nobody);
        vm.expectRevert();
        audit.setAuditor(auditor, true);
    }

    function test_auditorCannotSetAuditor() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);

        vm.prank(auditor);
        vm.expectRevert();
        audit.setAuditor(nobody, true);
    }

    function test_revokeAuditor() public {
        vm.startPrank(owner);
        audit.setAuditor(auditor, true);
        audit.setAuditor(auditor, false);
        vm.stopPrank();

        assertFalse(audit.isAuditor(auditor));

        vm.prank(auditor);
        vm.expectRevert(LindyAudit.NotAuthorized.selector);
        audit.mint(target, "ipfs://QmFail");
    }

    // ── Minting ─────────────────────────────────────────────────────

    function test_ownerCanMint() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmOwnerReport");

        uint256 tokenId = audit.tokenIdOf(target);
        assertEq(audit.ownerOf(tokenId), target);
        assertEq(audit.balanceOf(target), 1);
        assertEq(audit.tokenURI(tokenId), "ipfs://QmOwnerReport");
    }

    function test_auditorCanMint() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);

        vm.prank(auditor);
        audit.mint(target, "ipfs://QmAuditReport");

        uint256 tokenId = audit.tokenIdOf(target);
        assertEq(audit.ownerOf(tokenId), target);
        assertEq(audit.tokenURI(tokenId), "ipfs://QmAuditReport");
    }

    function test_nobodyCannotMint() public {
        vm.prank(nobody);
        vm.expectRevert(LindyAudit.NotAuthorized.selector);
        audit.mint(target, "ipfs://QmBad");
    }

    function test_cannotDoubleMint() public {
        vm.startPrank(owner);
        audit.mint(target, "ipfs://QmFirst");
        vm.expectRevert(LindyAudit.AlreadyMinted.selector);
        audit.mint(target, "ipfs://QmSecond");
        vm.stopPrank();
    }

    function test_mintEmitsAudited() public {
        vm.expectEmit(true, true, false, true);
        emit LindyAudit.Audited(owner, target, "ipfs://QmReport");
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");
    }

    function test_mintEmitsAuditedWithAuditorAddress() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);

        vm.expectEmit(true, true, false, true);
        emit LindyAudit.Audited(auditor, target, "ipfs://QmReport");
        vm.prank(auditor);
        audit.mint(target, "ipfs://QmReport");
    }

    function test_mintWithEmptyURI() public {
        vm.prank(owner);
        audit.mint(target, "");
        assertEq(audit.tokenURI(audit.tokenIdOf(target)), "");
    }

    // ── Update URI ──────────────────────────────────────────────────

    function test_ownerCanUpdateURI() public {
        vm.startPrank(owner);
        audit.mint(target, "ipfs://QmOld");
        audit.updateURI(audit.tokenIdOf(target), "ipfs://QmNew");
        vm.stopPrank();

        assertEq(audit.tokenURI(audit.tokenIdOf(target)), "ipfs://QmNew");
    }

    function test_auditorCanUpdateURI() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);

        vm.prank(owner);
        audit.mint(target, "ipfs://QmOld");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.prank(auditor);
        audit.updateURI(tokenId, "ipfs://QmUpdated");

        assertEq(audit.tokenURI(tokenId), "ipfs://QmUpdated");
    }

    function test_nobodyCannotUpdateURI() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmOld");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.prank(nobody);
        vm.expectRevert(LindyAudit.NotAuthorized.selector);
        audit.updateURI(tokenId, "ipfs://QmHack");
    }

    function test_updateURINonExistentReverts() public {
        vm.prank(owner);
        vm.expectRevert();
        audit.updateURI(999, "ipfs://QmGhost");
    }

    function test_updateURIEmitsEvent() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmOld");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.expectEmit(true, false, false, true);
        emit LindyAudit.URIUpdated(tokenId, "ipfs://QmNew");
        vm.prank(owner);
        audit.updateURI(tokenId, "ipfs://QmNew");
    }

    // ── Burn ────────────────────────────────────────────────────────

    function test_ownerCanBurn() public {
        vm.startPrank(owner);
        audit.mint(target, "ipfs://QmReport");
        uint256 tokenId = audit.tokenIdOf(target);
        audit.burn(tokenId);
        vm.stopPrank();

        assertEq(audit.balanceOf(target), 0);
        vm.expectRevert();
        audit.ownerOf(tokenId);
    }

    function test_auditorCanBurn() public {
        vm.prank(owner);
        audit.setAuditor(auditor, true);

        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.prank(auditor);
        audit.burn(tokenId);

        assertEq(audit.balanceOf(target), 0);
    }

    function test_nobodyCannotBurn() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.prank(nobody);
        vm.expectRevert(LindyAudit.NotAuthorized.selector);
        audit.burn(tokenId);
    }

    function test_burnNonExistentReverts() public {
        vm.prank(owner);
        vm.expectRevert();
        audit.burn(999);
    }

    function test_burnClearsURI() public {
        vm.startPrank(owner);
        audit.mint(target, "ipfs://QmReport");
        uint256 tokenId = audit.tokenIdOf(target);
        audit.burn(tokenId);
        vm.stopPrank();

        vm.expectRevert();
        audit.tokenURI(tokenId);
    }

    function test_canRemintAfterBurn() public {
        vm.startPrank(owner);
        audit.mint(target, "ipfs://QmV1");
        audit.burn(audit.tokenIdOf(target));
        audit.mint(target, "ipfs://QmV2");
        vm.stopPrank();

        assertEq(audit.tokenURI(audit.tokenIdOf(target)), "ipfs://QmV2");
        assertEq(audit.balanceOf(target), 1);
    }

    // ── tokenURI ────────────────────────────────────────────────────

    function test_tokenURINonExistentReverts() public {
        vm.expectRevert();
        audit.tokenURI(999);
    }

    // ── Soulbound ───────────────────────────────────────────────────

    function test_transferFromReverts() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");
        uint256 tokenId = audit.tokenIdOf(target);

        vm.prank(target);
        vm.expectRevert("SOULBOUND");
        audit.transferFrom(target, nobody, tokenId);
    }

    function test_safeTransferFromReverts() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");
        uint256 tokenId = audit.tokenIdOf(target);

        vm.prank(target);
        vm.expectRevert("SOULBOUND");
        audit.safeTransferFrom(target, nobody, tokenId);
    }

    function test_safeTransferFromWithDataReverts() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");
        uint256 tokenId = audit.tokenIdOf(target);

        vm.prank(target);
        vm.expectRevert("SOULBOUND");
        audit.safeTransferFrom(target, nobody, tokenId, "");
    }

    function test_approveReverts() public {
        vm.prank(owner);
        audit.mint(target, "ipfs://QmReport");

        uint256 tokenId = audit.tokenIdOf(target);
        vm.prank(target);
        vm.expectRevert("SOULBOUND");
        audit.approve(nobody, tokenId);
    }

    function test_setApprovalForAllReverts() public {
        vm.prank(target);
        vm.expectRevert("SOULBOUND");
        audit.setApprovalForAll(nobody, true);
    }

    // ── Token ID mapping ────────────────────────────────────────────

    function test_tokenIdMatchesAddress() public view {
        assertEq(audit.tokenIdOf(target), uint256(uint160(target)));
    }

    function test_tokenIdDeterministic() public view {
        assertEq(audit.tokenIdOf(address(0x1)), 1);
        assertEq(audit.tokenIdOf(address(0xFF)), 255);
    }

    // ── setAuditor event ────────────────────────────────────────────

    function test_setAuditorEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit LindyAudit.AuditorSet(auditor, true);
        vm.prank(owner);
        audit.setAuditor(auditor, true);
    }
}
