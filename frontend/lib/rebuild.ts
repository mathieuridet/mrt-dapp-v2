import fs from "node:fs";
import path from "node:path";
import { put } from "@vercel/blob";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import { ethers, JsonRpcProvider, Contract } from "ethers";

type RebuildOptions = {
  rpcUrl?: string;
  nft?: `0x${string}`;
  distributor?: `0x${string}`;
  blocksPerHour?: number;
  outPath?: string;
  blobKey?: string;
};

type RebuildResult = {
  ok: boolean;
  updated: boolean;
  reason?: "empty" | "unchanged" | "pushed";
  count: number;
  round: number;
  fileRoot: `0x${string}`;
  onchainRoot?: `0x${string}`;
  blobUrl?: string;
  localPath?: string;
  warn?: string[];
};

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

type Hex32 = `0x${string}`;

const DIST_ABI = [
  "function token() view returns (address)",
  "function merkleRoot() view returns (bytes32)",
  "function round() view returns (uint64)",
  "function rewardAmount() view returns (uint256)",
  "function setRoot(bytes32 newRoot, uint64 newRound) external",
] as const;

const TRANSFER_SIG = ethers.id("Transfer(address,address,uint256)");
const ZERO32: Hex32 = ("0x" + "0".repeat(64)) as Hex32;
const DUMMY_ROOT: Hex32 = ethers.keccak256(ethers.toUtf8Bytes("empty")) as Hex32;

function leafHash(account: `0x${string}`, amount: bigint, round: bigint) {
  return ethers.keccak256(
    ethers.solidityPacked(["address", "uint256", "uint64"], [account, amount, round])
  );
}
function toBuf(hex: string) {
  return Buffer.from(hex.slice(2), "hex");
}
function errorMessage(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === "string") return e;
  try { return JSON.stringify(e); } catch { return String(e); }
}

async function getLogsInChunks(
  provider: JsonRpcProvider,
  address: string,
  fromBlock: number,
  toBlock: number,
  topics: string[]
) {
  const logs: ethers.Log[] = [];
  const CHUNK_SIZE = 10;
  for (let start = fromBlock; start <= toBlock; start += CHUNK_SIZE) {
    const end = Math.min(start + CHUNK_SIZE - 1, toBlock);
    const chunkLogs = await provider.send("eth_getLogs", [
      {
        address,
        fromBlock: `0x${start.toString(16)}`,
        toBlock: `0x${end.toString(16)}`,
        topics,
      },
    ]);
    logs.push(...chunkLogs);
  }
  return logs;
}

export async function rebuildAndPush(opts: RebuildOptions = {}): Promise<RebuildResult> {
  const warns: string[] = [];

  const rpcUrl = opts.rpcUrl ?? process.env.NEXT_PUBLIC_RPC_URL ?? "";
  const nft = (opts.nft ?? process.env.NEXT_PUBLIC_NFT_ADDRESS) as `0x${string}`;
  const distributor = (opts.distributor ?? process.env.NEXT_PUBLIC_DISTRIBUTOR_ADDRESS) as `0x${string}`;
  const blocksPerHour = opts.blocksPerHour ?? Number(process.env.BLOCKS_PER_HOUR ?? 300);
  const outPath = opts.outPath ?? path.join(process.cwd(), "public", "claims", "current.json");
  const blobKey = opts.blobKey ?? "claims/current.json";

  if (!rpcUrl || !nft || !distributor) {
    return { ok: false, updated: false, count: 0, round: 0, fileRoot: ZERO32, warn: ["Missing RPC/NFT/DISTRIBUTOR env"] };
  }

  const provider = new JsonRpcProvider(rpcUrl);
  const code = await provider.getCode(distributor);
  if (code === "0x") {
    return { ok: false, updated: false, count: 0, round: 0, fileRoot: ZERO32, warn: [`No contract bytecode at ${distributor}`] };
  }

  const dist = new Contract(distributor, DIST_ABI, provider);
  const [onchainRoot, onchainRound, onchainReward] = await Promise.all([
    dist.merkleRoot(),
    dist.round(),
    dist.rewardAmount(),
  ]) as [`0x${string}`, bigint, bigint];

  let rewardAmount = onchainReward;
  if (rewardAmount === 0n) {
    const fallback = ethers.parseUnits(process.env.REWARD_AMOUNT || "5", 18);
    warns.push(`On-chain rewardAmount is 0; using fallback ${fallback.toString()}`);
    rewardAmount = fallback;
  }

  const toBlock = await provider.getBlockNumber();
  const fromBlock = Math.max(0, toBlock - blocksPerHour);
  const logs = await getLogsInChunks(provider, nft, fromBlock, toBlock, [TRANSFER_SIG, ZERO32]);

  const minters = new Set<string>();
  for (const log of logs) {
    const to = ethers.getAddress(("0x" + log.topics[2].slice(26)) as `0x${string}`);
    //minters.add(to.toLowerCase());
    minters.add(to);
  }

  const round = BigInt(Math.floor(Date.now() / 1000 / 3600));
  const addresses = Array.from(minters).sort();

  let fileRoot: Hex32;
  let claims: Claim[];

  if (addresses.length === 0) {
    fileRoot = DUMMY_ROOT;
    claims = [];
  } else {
    const leaves = addresses.map((a) =>
      toBuf(leafHash(a as `0x${string}`, rewardAmount, round))
    );
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    fileRoot = ("0x" + tree.getRoot().toString("hex")) as Hex32;
    claims = addresses.map((account, i) => ({
      account: ethers.getAddress(account) as `0x${string}`,
      amount: rewardAmount.toString(),
      proof: tree.getHexProof(leaves[i]).map((p) => p as `0x${string}`),
    }));
  }

  const payloadStr = JSON.stringify({ round: Number(round), root: fileRoot, claims }, null, 2);

  let blobUrl: string | undefined;
  let localPath: string | undefined;

  if (process.env.WRITE_LOCAL === "1" || !process.env.VERCEL || process.env.NODE_ENV !== "production") {
    try {
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, payloadStr);
      localPath = outPath;
    } catch (e) {
      warns.push(`Local write failed: ${errorMessage(e)}`);
    }
  }

  // Fetch latest blob content
  let current: ProofsPayload | undefined;
  const blobReadHost = process.env.BLOB_READ_HOST ?? "1knr7tukuhrzgbyl.public.blob.vercel-storage.com";
  try {
    const res = await fetch(`https://${blobReadHost}/${blobKey}`);
    if (res.ok) current = await res.json();
  } catch (e) {
    warns.push(`Could not fetch current blob: ${errorMessage(e)}`);
  }

  // Decide if upload is needed
  if (
    current &&
    current.root.toLowerCase() === fileRoot.toLowerCase() &&
    current.round === Number(round)
  ) {
    return {
      ok: true,
      updated: false,
      reason: addresses.length === 0 ? "empty" : "unchanged",
      count: addresses.length,
      round: Number(round),
      fileRoot,
      onchainRoot,
      blobUrl: `https://${blobReadHost}/${blobKey}`,
      localPath,
      warn: warns.length ? warns : undefined,
    };
  }

  let reason: "empty" | "unchanged" | "pushed" = "unchanged";
  try {
    const res = await put(blobKey, payloadStr, {
      access: "public",
      addRandomSuffix: false,
      contentType: "application/json",
      token: process.env.BLOB_READ_WRITE_TOKEN,
      allowOverwrite: true,
    });
    blobUrl = res.url;
    reason = "pushed";
  } catch (e) {
    warns.push(`Blob upload failed: ${errorMessage(e)}`);
  }

  const needUpdate =
    fileRoot.toLowerCase() !== (onchainRoot as string).toLowerCase() ||
    round > onchainRound;

  let txHash: string | undefined;
  if (needUpdate && process.env.PUBLISHER_PRIVATE_KEY) {
    try {
      const wallet = new ethers.Wallet(process.env.PUBLISHER_PRIVATE_KEY, provider);
      const distWithSigner = new Contract(distributor, DIST_ABI, wallet);
      const tx = await distWithSigner.setRoot(fileRoot, round);
      const receipt = await tx.wait();
      txHash = receipt.transactionHash;
    } catch (e) {
      warns.push(`On-chain setRoot failed: ${errorMessage(e)}`);
    }
  } else if (needUpdate) {
    warns.push("setRoot needed but no PUBLISHER_PRIVATE_KEY provided — skipping on-chain update");
  }

  return {
    ok: true,
    updated: needUpdate,
    reason: addresses.length === 0 ? "empty" : reason,
    count: addresses.length,
    round: Number(round),
    fileRoot,
    onchainRoot,
    blobUrl,
    localPath,
    warn: warns.length ? warns : undefined,
    ...(txHash ? { txHash } : {}),
  };
}
