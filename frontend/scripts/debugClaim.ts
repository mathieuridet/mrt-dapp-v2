import { JsonRpcProvider, Contract, ethers } from "ethers";
import fs from "node:fs";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
// Adjust the path so it points correctly to your abi folder
const DistributorArtifact = require("../abi/MerkleDistributor.json");

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

async function main() {
  const rpcUrl = "https://eth-sepolia.g.alchemy.com/v2/J06uSeaFOqBPaG4YT9fSB";
  const distributor = "0xB1189B60C224AD88C3d6330FdF39be866dE2D484";
  const jsonPath = process.argv[2];
  const account = process.argv[3] as `0x${string}`;

  console.log("[debug] rpcUrl:", rpcUrl);
  console.log("[debug] distributor:", distributor);
  console.log("[debug] jsonPath:", jsonPath);
  console.log("[debug] account:", account);

  if (!rpcUrl || !distributor || !jsonPath || !account) {
    console.error("Usage: RPC_URL=... DISTRIBUTOR=... ts-node debugClaim.ts <jsonPath> <account>");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const dist = new ethers.Contract(distributor, DistributorArtifact.abi, provider);

  const raw = fs.readFileSync(jsonPath, "utf8");
  const data = JSON.parse(raw) as ProofsPayload;

  const claim = data.claims.find(
    (c) => c.account.toLowerCase() === account.toLowerCase()
  );
  if (!claim) {
    console.error("No claim for account", account);
    process.exit(1);
  }

  const round = BigInt(data.round);

  console.log("[debug] round:", round.toString());
  console.log("[debug] account:", account);
  console.log("[debug] proof length:", claim.proof.length);

  try {
    // static call: simulate the tx, don't send it
    const res = await dist.claimV2.staticCall(round, account, claim.proof);
    console.log("staticCall succeeded, result:", res);
  } catch (e: any) {
    console.error("staticCall reverted");
    console.error("message:", e.message);
    // ethers v6 custom error info:
    if (e.errorName) console.error("errorName:", e.errorName);
    if (e.errorArgs) console.error("errorArgs:", e.errorArgs);
    if (e.reason) console.error("reason:", e.reason);
  }
}

main().catch(console.error);
