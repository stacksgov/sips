import { describe, it, expect, beforeEach } from "vitest";
import { initSimnet, Simnet } from "@hirosystems/clarinet-sdk";
import { Cl, ClarityType, serializeCV } from "@stacks/transactions";

// Initialize simnet once
let simnet: Simnet;

beforeEach(async () => {
    // Reinitialize simnet before each test for clean state
    simnet = await initSimnet();
});

// =============================================================================
// CONSTANTS (must match contract)
// =============================================================================

const ERR = {
    UNAUTHORIZED: 100,
    NOT_FOUND: 101,
    INVALID_STATE: 102,
    INVALID_SIGNATURE: 103,
    NOT_PARTICIPANT: 104,
    ALREADY_ACCEPTED: 105,
    INTENT_EXPIRED: 106,
    NONCE_TOO_LOW: 107,
    INVALID_PARTICIPANTS: 108,
    ACCEPTANCE_EXPIRED: 109,
    PAYLOAD_MISMATCH: 110,
    SERIALIZATION_FAILED: 111,
    DUPLICATE_INTENT: 112,
};

// Clarity types
const CV_OK = ClarityType.ResponseOk;      // 7
const CV_ERR = ClarityType.ResponseErr;    // 8
const CV_UINT = ClarityType.UInt;          // 1
const CV_TUPLE = ClarityType.Tuple;        // 12

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function buff32(str: string): Uint8Array {
    const bytes = new TextEncoder().encode(str);
    const buffer = new Uint8Array(32);
    buffer.set(bytes.slice(0, 32));
    return buffer;
}

// Sort principals by consensus buffer (matches Clarity's to-consensus-buff?)
function sortPrincipals(principals: string[]): string[] {
    return [...principals].sort((a, b) => {
        const bufA = serializeCV(Cl.principal(a));
        const bufB = serializeCV(Cl.principal(b));
        const minLen = Math.min(bufA.length, bufB.length);
        for (let i = 0; i < minLen; i++) {
            if (bufA[i] !== bufB[i]) return bufA[i] - bufB[i];
        }
        return bufA.length - bufB.length;
    });
}

function isOk(result: any): boolean {
    return result.type === CV_OK;
}

function isErr(result: any): boolean {
    return result.type === CV_ERR;
}

function getErrCode(result: any): number {
    if (result.type === CV_ERR && result.value.type === CV_UINT) {
        return Number(result.value.value);
    }
    return -1;
}

// =============================================================================
// PROPOSE COORDINATION TESTS
// =============================================================================

describe("propose-coordination", () => {

    it("successfully creates a new coordination", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const participants = sortPrincipals([wallet1, wallet2]);
        const payloadHash = buff32("rps-game-payload");
        const coordinationType = buff32("RPS-GAME");

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(payloadHash),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(coordinationType),
                Cl.uint(1000),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(result)).toBe(true);
    });

    it("fails if agent not in participants", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        const wallet3 = accounts.get("wallet_3")!;

        const participants = sortPrincipals([wallet2, wallet3]);

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("test")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isErr(result)).toBe(true);
        expect(getErrCode(result)).toBe(ERR.INVALID_PARTICIPANTS);
    });

    it("fails if expiry is in the past", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        simnet.mineEmptyBlocks(10);
        const participants = sortPrincipals([wallet1, wallet2]);

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("test-past")),
                Cl.uint(5),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isErr(result)).toBe(true);
        expect(getErrCode(result)).toBe(ERR.INTENT_EXPIRED);
    });

    it("fails if nonce not increasing", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const participants = sortPrincipals([wallet1, wallet2]);

        // First proposal with nonce 5
        simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("test1")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(5),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        // Second proposal with nonce 3 (lower) should fail
        const { result } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("test2")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(3),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isErr(result)).toBe(true);
        expect(getErrCode(result)).toBe(ERR.NONCE_TOO_LOW);
    });
});

// =============================================================================
// CANCEL COORDINATION TESTS
// =============================================================================

describe("cancel-coordination", () => {

    it("agent can cancel before expiry", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const participants = sortPrincipals([wallet1, wallet2]);

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("cancel-test")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
        const intentHash = proposeResult.value;

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("Changed my mind")],
            wallet1
        );

        expect(isOk(result)).toBe(true);
    });

    it("non-agent cannot cancel before expiry", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const participants = sortPrincipals([wallet1, wallet2]);

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("cancel-test-2")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
        const intentHash = proposeResult.value;

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("I want out")],
            wallet2
        );

        expect(isErr(result)).toBe(true);
        expect(getErrCode(result)).toBe(ERR.UNAUTHORIZED);
    });

    it("anyone can cancel after expiry", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        const wallet3 = accounts.get("wallet_3")!;

        const participants = sortPrincipals([wallet1, wallet2]);
        const expiry = simnet.blockHeight + 10;

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("expire-test")),
                Cl.uint(expiry),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
        const intentHash = proposeResult.value;

        // Mine blocks past expiry
        simnet.mineEmptyBlocks(15);

        const { result } = simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("Cleanup")],
            wallet3
        );

        expect(isOk(result)).toBe(true);
    });

    it("cannot cancel already cancelled coordination", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const participants = sortPrincipals([wallet1, wallet2]);

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("double-cancel")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(buff32("TEST")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        const intentHash = proposeResult.value;

        // First cancel
        simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("First cancel")],
            wallet1
        );

        // Second cancel should fail
        const { result } = simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("Second cancel")],
            wallet1
        );

        expect(isErr(result)).toBe(true);
        expect(getErrCode(result)).toBe(ERR.INVALID_STATE);
    });
});

// =============================================================================
// READ-ONLY FUNCTION TESTS
// =============================================================================

describe("read-only functions", () => {

    it("get-agent-nonce returns 0 initially", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;

        const result = simnet.callReadOnlyFn(
            "erc-8001",
            "get-agent-nonce",
            [Cl.principal(wallet1)],
            wallet1
        );

        expect(result.result.type).toBe(CV_UINT);
        expect(result.result.value).toBe(0n);
    });

    it("get-signing-domain returns domain info", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;

        const result = simnet.callReadOnlyFn(
            "erc-8001",
            "get-signing-domain",
            [],
            wallet1
        );

        expect(result.result.type).toBe(CV_TUPLE);
    });

    it("get-coordination-status returns NOT_FOUND for non-existent intent", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;

        const fakeIntentHash = buff32("does-not-exist");

        const result = simnet.callReadOnlyFn(
            "erc-8001",
            "get-coordination-status",
            [Cl.buffer(fakeIntentHash)],
            wallet1
        );

        expect(isErr(result.result)).toBe(true);
        expect(getErrCode(result.result)).toBe(ERR.NOT_FOUND);
    });
});

// =============================================================================
// RPS GAME USER STORY
// =============================================================================

describe("RPS Game: User Story", () => {

    it("full coordination flow: propose -> query -> cancel", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;

        const gamePayload = buff32("ROCK:PAPER:secret123");
        const participants = sortPrincipals([wallet1, wallet2]);
        const coordinationType = buff32("RPS-GAME");

        // Step 1: Propose
        const { result: proposeResult, events } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(gamePayload),
                Cl.uint(simnet.blockHeight + 144),
                Cl.uint(1),
                Cl.buffer(coordinationType),
                Cl.uint(1000),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
        expect(events.length).toBeGreaterThan(0);

        const intentHash = proposeResult.value;

        // Step 2: Query status
        const statusResult = simnet.callReadOnlyFn(
            "erc-8001",
            "get-coordination-status",
            [intentHash],
            wallet1
        );
        expect(isOk(statusResult.result)).toBe(true);

        // Step 3: Cancel
        const { result: cancelResult } = simnet.callPublicFn(
            "erc-8001",
            "cancel-coordination",
            [intentHash, Cl.stringAscii("Game cancelled")],
            wallet1
        );
        expect(isOk(cancelResult)).toBe(true);
    });
});

// =============================================================================
// EDGE CASES
// =============================================================================

describe("Edge Cases", () => {

    it("single participant coordination", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;

        const participants = [wallet1];

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("self-task")),
                Cl.uint(simnet.blockHeight + 100),
                Cl.uint(1),
                Cl.buffer(buff32("SELF-COORD")),
                Cl.uint(0),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
    });

    it("multi-party coordination with 5 participants", async () => {
        const accounts = simnet.getAccounts();
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        const wallet3 = accounts.get("wallet_3")!;
        const wallet4 = accounts.get("wallet_4")!;
        const wallet5 = accounts.get("wallet_5")!;

        const participants = sortPrincipals([
            wallet1, wallet2, wallet3, wallet4, wallet5
        ]);

        const { result: proposeResult } = simnet.callPublicFn(
            "erc-8001",
            "propose-coordination",
            [
                Cl.buffer(buff32("multi-party")),
                Cl.uint(simnet.blockHeight + 1000),
                Cl.uint(1),
                Cl.buffer(buff32("MULTI-SIG")),
                Cl.uint(50000),
                Cl.list(participants.map(p => Cl.principal(p))),
            ],
            wallet1
        );

        expect(isOk(proposeResult)).toBe(true);
    });
});