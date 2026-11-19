// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentMarkRegistry} from "../src/AgentMarkRegistry.sol";
import {MockAgentId} from "./MockAgentId.sol";

/// @dev Minimal cheatcode interface (avoids a forge-std dependency).
interface Vm {
    function prank(address msgSender) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
}

contract AgentMarkRegistryTest {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MockAgentId private agentId;
    AgentMarkRegistry private registry;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant NOBODY = address(0xDEAD);

    // tokenIds derived exactly like the real contract: uint256(keccak256(label))
    uint256 private aliceToken = uint256(keccak256(bytes("aliceagent")));
    uint256 private bobToken = uint256(keccak256(bytes("bobagent")));

    bytes32 private catResearch = keccak256("research");
    bytes32 private catDev = keccak256("dev");
    bytes32 private tagData = keccak256("data-analysis");

    function setUp() public {
        agentId = new MockAgentId();
        registry = new AgentMarkRegistry(address(agentId));
        agentId.mint(ALICE, aliceToken);
        agentId.mint(BOB, bobToken);
    }

    // --- helpers -------------------------------------------------------------
    function assertTrue(bool cond, string memory msg_) internal pure {
        if (!cond) revert(msg_);
    }

    function assertEq(uint256 a, uint256 b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }

    function assertEq(address a, address b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }

    // --- registration ----------------------------------------------------------
    function testRegisterSuccess() public {
        vm.prank(ALICE);
        registry.registerService(aliceToken, catResearch, "ipfs://alice-service.json");

        AgentMarkRegistry.Listing memory l = registry.listingOf(aliceToken);
        assertEq(l.owner, ALICE, "owner mismatch");
        assertTrue(l.category == catResearch, "category mismatch");
        assertTrue(l.active, "listing must be active");
        assertEq(registry.tokenIdOf(ALICE), aliceToken, "tokenIdOf mismatch");
        assertEq(registry.totalListings(), 1, "totalListings must be 1");
        assertTrue(registry.hasAgentId(ALICE), "hasAgentId must be true");
    }

    function testRegisterWithoutAgentIdReverts() public {
        vm.prank(NOBODY);
        vm.expectRevert();
        registry.registerService(12345, catResearch, "ipfs://x.json");
    }

    function testRegisterWithSomeoneElsesTokenReverts() public {
        vm.prank(ALICE); // Alice holds aliceToken, tries to register Bob's
        vm.expectRevert();
        registry.registerService(bobToken, catResearch, "ipfs://stolen.json");
    }

    function testRegisterEmptyMetadataReverts() public {
        vm.prank(ALICE);
        vm.expectRevert();
        registry.registerService(aliceToken, catResearch, "");
    }

    function testUpdateListingKeepsCount() public {
        vm.prank(ALICE);
        registry.registerService(aliceToken, catResearch, "ipfs://v1.json");
        vm.prank(ALICE);
        registry.registerService(aliceToken, catDev, "ipfs://v2.json");

        AgentMarkRegistry.Listing memory l = registry.listingOf(aliceToken);
        assertTrue(l.category == catDev, "category must be updated");
        assertEq(registry.totalListings(), 1, "update must not double-count");
    }

    function testRemoveService() public {
        vm.prank(ALICE);
        registry.registerService(aliceToken, catResearch, "ipfs://a.json");
        vm.prank(ALICE);
        registry.removeService();

        AgentMarkRegistry.Listing memory l = registry.listingOf(aliceToken);
        assertTrue(!l.active, "listing must be inactive after removal");
        assertEq(registry.totalListings(), 0, "totalListings must drop to 0");
    }

    function testRemoveByNonOwnerReverts() public {
        vm.prank(ALICE);
        registry.registerService(aliceToken, catResearch, "ipfs://a.json");
        vm.prank(BOB); // Bob has an Agent ID but no listing of his own here
        vm.expectRevert();
        registry.removeService();
    }

    // --- endorsements ----------------------------------------------------------
    function testEndorseSuccess() public {
        vm.prank(BOB);
        registry.endorse(bobToken, aliceToken, tagData);

        assertEq(registry.endorsementCount(aliceToken), 1, "count must be 1");
        assertEq(registry.endorsementCountByTag(aliceToken, tagData), 1, "tag count must be 1");
        assertEq(registry.totalEndorsements(), 1, "totalEndorsements must be 1");
        assertTrue(registry.hasEndorsed(bobToken, aliceToken, tagData), "hasEndorsed must be true");
    }

    function testEndorseSelfReverts() public {
        vm.prank(ALICE);
        vm.expectRevert();
        registry.endorse(aliceToken, aliceToken, tagData);
    }

    function testEndorseTwiceReverts() public {
        vm.prank(BOB);
        registry.endorse(bobToken, aliceToken, tagData);
        vm.prank(BOB);
        vm.expectRevert();
        registry.endorse(bobToken, aliceToken, tagData);
    }

    function testEndorseDifferentTagAllowed() public {
        vm.prank(BOB);
        registry.endorse(bobToken, aliceToken, tagData);
        vm.prank(BOB);
        registry.endorse(bobToken, aliceToken, keccak256("writing"));
        assertEq(registry.endorsementCount(aliceToken), 2, "two tags must count twice");
    }

    function testEndorseWithoutAgentIdReverts() public {
        vm.prank(NOBODY);
        vm.expectRevert();
        registry.endorse(999, aliceToken, tagData);
    }

    function testEndorseWithSomeoneElsesTokenReverts() public {
        vm.prank(BOB); // Bob tries to endorse "as" Alice
        vm.expectRevert();
        registry.endorse(aliceToken, bobToken, tagData);
    }

    function testEndorseNonexistentTargetReverts() public {
        vm.prank(BOB);
        vm.expectRevert(); // ownerOf reverts inside the Agent ID contract
        registry.endorse(bobToken, uint256(keccak256(bytes("ghost"))), tagData);
    }
}
