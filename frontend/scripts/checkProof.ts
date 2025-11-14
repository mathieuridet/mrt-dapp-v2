import fs from "node:fs";
import { ethers } from "ethers";

type Claim = {
  account: `0x${string}`;
  amount: string;
  proof: `0x${string}`[];
};

type ProofsPayload = {
  round: number;
  root: `0x${string}`;
  claims: Claim[];
};

function leafHash(account: `0x${string}`, amount: bigint, round: bigint) {
  return ethers.keccak256(
    ethers.solidityPacked(["address", "uint256", "uint64"], [account, amount, round])
  );
}

// JS version of OpenZeppelin's MerkleProof.processProof
function processProof(leaf: string, proof: string[]): string {
  let computed = leaf;

  for (const p of proof) {
    const [a, b] =
      BigInt(computed) <= BigInt(p)
        ? [computed, p]
        : [p, computed];

    computed = ethers.keccak256(
      ethers.solidityPacked(["bytes32", "bytes32"], [a, b])
    );
  }

  return computed;
}

function verify(leaf: string, proof: string[], root: string): boolean {
  return processProof(leaf, proof).toLowerCase() === root.toLowerCase();
}

function main() {
  const file = process.argv[2];
  const addr = (process.argv[3] ?? "").toLowerCase();
  if (!file || !addr) {
    console.error("Usage: ts-node checkProof.ts <jsonPath> <address>");
    process.exit(1);
  }

  const raw = fs.readFileSync(file, "utf8");
  const data = JSON.parse(raw) as ProofsPayload;

  const claim = data.claims.find(
    (c) => c.account.toLowerCase() === addr
  );
  if (!claim) {
    console.error("No claim for address", addr);
    process.exit(1);
  }

  const round = BigInt(data.round);
  const amount = BigInt(claim.amount);
  const leaf = leafHash(claim.account, amount, round);

  console.log("root:", data.root);
  console.log("leaf:", leaf);
  console.log("proof:", claim.proof);

  const ok = verify(leaf, claim.proof, data.root);
  console.log("MerkleProof.verify(...) =", ok ? "✅ true" : "❌ false");
}

main();
