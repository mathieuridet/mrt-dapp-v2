import fs from "node:fs";
import path from "node:path";
import { put } from "@vercel/blob";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import { ethers, JsonRpcProvider, Contract } from "ethers";
import { CHAIN_CONFIGS, DEFAULT_CHAIN_ID } from "@/app/config/chains";
import DistributorArtifact from "@/abi/MerkleDistributor.json";

type RebuildOptions = {
  chainId?: number;
  rpcUrl?: string;
  nft?: `0x${string}`;
  distributor?: `0x${string}`;
  blocksPerHour?: number;
  outPath?: string;
  blobKey?: string;
};

type RebuildResult = {
  ok: boolean;
  updated: boolean; // on-chain updated (tx mined)
  reason?: "empty" | "unchanged" | "pushed"; // keep your existing union for API compat
  count: number;
  round: number;
  fileRoot: `0x${string}`;
  onchainRoot?: `0x${string}`;
  blobUrl?: string;
  localPath?: string;
  warn?: string[];
  txHash?: string;
};

type RebuildBatchItem = {
  chainId: number;
  chainSlug: string;
  label: string;
  result: RebuildResult;
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

const TRANSFER_SIG = ethers.id("Transfer(address,address,uint256)");
const ZERO32: Hex32 = ("0x" + "0".repeat(64)) as Hex32;
const DUMMY_ROOT: Hex32 = ethers.keccak256(ethers.toUtf8Bytes("empty")) as Hex32;
const DIST_ABI = DistributorArtifact.abi;

// EIP-1967 implementation slot
const IMPL_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

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
  try {
    return JSON.stringify(e);
  } catch {
    return String(e);
  }
}

async function getLogsInChunks(
  provider: JsonRpcProvider,
  address: string,
  fromBlock: number,
  toBlock: number,
  topics: string[]
) {
  const logs: ethers.Log[] = [];
  const CHUNK_SIZE = 10_000; // larger chunk for fewer RPC roundtrips; tune as needed
  for (let start = fromBlock; start <= toBlock; start += CHUNK_SIZE) {
    const end = Math.min(start + CHUNK_SIZE - 1, toBlock);
    // 🔎 LOG: chunk window
    console.log("[logs] chunk", { from: start, to: end });
    const chunkLogs = await provider.send("eth_getLogs", [
      {
        address,
        fromBlock: `0x${start.toString(16)}`,
        toBlock: `0x${end.toString(16)}`,
        topics,
      },
    ]);
    console.log("[logs] fetched", chunkLogs.length);
    logs.push(...chunkLogs);
  }
  return logs;
}

async function rebuildSingleChain(opts: RebuildOptions = {}): Promise<RebuildBatchItem> {
  const warns: string[] = [];

  const targetChainId = opts.chainId ?? DEFAULT_CHAIN_ID;
  const chainConfig = CHAIN_CONFIGS[targetChainId] ?? CHAIN_CONFIGS[DEFAULT_CHAIN_ID];
  const resolvedChainId = chainConfig.id;
  const chainSlug = chainConfig.alchemyNetwork || `chain-${chainConfig.id}`;

  const wrap = (result: RebuildResult): RebuildBatchItem => ({
    chainId: resolvedChainId,
    chainSlug,
    label: chainConfig.label,
    result,
  });

  const rpcUrl = opts.rpcUrl ?? chainConfig.rpcUrl ?? "";
  const nft = opts.nft ?? chainConfig.contracts.nft;
  const distributor = opts.distributor ?? chainConfig.contracts.distributor;
  const blocksPerHour = opts.blocksPerHour ?? Number(process.env.BLOCKS_PER_HOUR ?? 300);
  const outPath = opts.outPath ?? path.join(process.cwd(), "public", "claims", `${chainSlug}.json`);
  const blobKey = opts.blobKey ?? `claims/${chainSlug}.json`;

  // 🔎 LOG: resolved configuration (no secrets)
  console.log("[cfg]", {
    chainId: resolvedChainId,
    chainSlug,
    label: chainConfig.label,
    rpcUrl: rpcUrl ? `${rpcUrl.slice(0, 30)}…` : "",
    nft,
    distributor,
    blocksPerHour,
    outPath,
    blobKey,
    vercel: !!process.env.VERCEL,
    nodeEnv: process.env.NODE_ENV,
  });

  if (!rpcUrl || !nft || !distributor) {
    return wrap({
      ok: false,
      updated: false,
      count: 0,
      round: 0,
      fileRoot: ZERO32,
      warn: [`Missing RPC/NFT/DISTRIBUTOR configuration for ${chainConfig.label}.`],
    });
  }

  const provider = new JsonRpcProvider(rpcUrl);
  const distributorAddress = distributor as `0x${string}`;
  const nftAddress = nft as `0x${string}`;

  // Validate distributor code exists
  const code = await provider.getCode(distributorAddress);
  console.log("[dist] codeLen", code.length);
  if (code === "0x") {
    return wrap({
      ok: false,
      updated: false,
      count: 0,
      round: 0,
      fileRoot: ZERO32,
      warn: [`No contract bytecode at ${distributorAddress}`],
    });
  }

  // Optional: read the UUPS impl slot for debugging wiring
  try {
    const raw = await provider.send("eth_getStorageAt", [distributorAddress, IMPL_SLOT, "latest"]);
    const impl = ("0x" + raw.slice(26)) as `0x${string}`;
    console.log("[dist] impl(EIP-1967)", impl);
  } catch (e) {
    console.log("[dist] impl slot read failed (non-fatal):", (e as Error).message);
  }

  const dist = new Contract(distributorAddress, DIST_ABI, provider);

  // Read distributor state WITH detailed logging
  let onchainRoot: `0x${string}` | undefined;
  let onchainRound: bigint | undefined;
  let onchainReward: bigint | undefined;
  try {
    console.log("[dist] reading state", { distributorAddress });

    onchainRoot = (await dist.s_merkleRoot()) as `0x${string}`;
    console.log("[dist] s_merkleRoot ->", onchainRoot);

    onchainRound = (await dist.s_round()) as bigint;
    console.log("[dist] s_round ->", onchainRound?.toString());

    onchainReward = (await dist.i_rewardAmount()) as bigint;
    console.log("[dist] i_rewardAmount ->", onchainReward?.toString());
  } catch (err) {
    console.error("Error reading distributor state", { distributorAddress, err });
    throw err;
  }

  let rewardAmount = onchainReward!;
  if (rewardAmount === 0n) {
    const fallback = ethers.parseUnits(process.env.REWARD_AMOUNT || "5", 18);
    console.warn("[dist] rewardAmount=0 on-chain, using fallback", fallback.toString());
    rewardAmount = fallback;
  }

  // 1-hour scan window
  const toBlock = await provider.getBlockNumber();
  const fromBlock = Math.max(0, toBlock - blocksPerHour);

  // 🔎 LOG: numeric window + timestamps (helps correlate to “1h”)
  const [fromHeader, toHeader] = await Promise.all([
    provider.getBlock(fromBlock),
    provider.getBlock(toBlock),
  ]);
  console.log("[builder] chain=eth-sepolia");
  console.log("[builder] fromBlock", fromBlock);
  console.log("[builder] toBlock  ", toBlock);
  console.log("[builder] fromTs   ", Number(fromHeader?.timestamp ?? 0));
  console.log("[builder] toTs     ", Number(toHeader?.timestamp ?? 0));
  console.log("[builder] nftAddress", nftAddress);

  const logs = await getLogsInChunks(provider, nftAddress, fromBlock, toBlock, [TRANSFER_SIG, ZERO32]);
  console.log("[builder] logs.length", logs.length);
  if (logs.length) {
    const peek = logs[0];
    const bnRaw = peek.blockNumber;
    const bn =
      typeof bnRaw === "string" ? parseInt(bnRaw, 16)
      : typeof bnRaw === "bigint" ? Number(bnRaw)
      : Number(bnRaw ?? 0);
  
    console.log("[builder] firstLog", {
      blockNumber: bn,
      txHash: peek.transactionHash,
      topics: peek.topics,
    });
  }

  // Derive minters
  const minters = new Set<string>();
  for (const log of logs) {
    const to = ethers.getAddress(("0x" + log.topics[2].slice(26)) as `0x${string}`);
    minters.add(to);
  }
  console.log("[builder] minters", Array.from(minters));

  // Round: hour-bucket (as before)
  const round = BigInt(Math.floor(Date.now() / 1000 / 3600));
  console.log("[builder] round(hourBucket)", Number(round));

  const addresses = Array.from(minters).sort();
  console.log("[builder] addresses.count", addresses.length);

  let fileRoot: Hex32;
  let claims: Claim[];

  if (addresses.length === 0) {
    fileRoot = DUMMY_ROOT;
    claims = [];
  } else {
    const leaves = addresses.map((a) => toBuf(leafHash(a as `0x${string}`, rewardAmount, round)));
    console.log("[builder] leaves(count)", leaves.length);

    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    fileRoot = ("0x" + tree.getRoot().toString("hex")) as Hex32;

    claims = addresses.map((account, i) => ({
      account: ethers.getAddress(account) as `0x${string}`,
      amount: rewardAmount.toString(),
      proof: tree.getHexProof(leaves[i]).map((p) => p as `0x${string}`),
    }));
  }

  console.log("[builder] fileRoot", fileRoot);
  console.log("[builder] claims.length", addresses.length);

  const payloadStr = JSON.stringify({ round: Number(round), root: fileRoot, claims }, null, 2);

  // Local write (skip on Vercel unless WRITE_LOCAL=1)
  let blobUrl: string | undefined;
  let localPath: string | undefined;

  if (process.env.WRITE_LOCAL === "1" || !process.env.VERCEL || process.env.NODE_ENV !== "production") {
    try {
      fs.mkdirSync(path.dirname(outPath), { recursive: true });
      fs.writeFileSync(outPath, payloadStr);
      localPath = outPath;
      console.log("[io] wrote local file", outPath);
    } catch (e) {
      const msg = `Local write failed: ${errorMessage(e)}`;
      console.warn("[io]", msg);
      warns.push(msg);
    }
  } else {
    console.log("[io] skipping local write on Vercel (prod)");
  }

  // Fetch latest blob content to compare
  let current: ProofsPayload | undefined;
  const blobReadHost =
    process.env.BLOB_READ_HOST ?? "1knr7tukuhrzgbyl.public.blob.vercel-storage.com";
  try {
    const url = `https://${blobReadHost}/${blobKey}`;
    console.log("[blob:get]", url);
    const res = await fetch(url);
    if (res.ok) {
      current = (await res.json()) as ProofsPayload;
      console.log("[blob:get] ok round", current.round, "root", current.root);
    } else {
      console.log("[blob:get] http", res.status);
    }
  } catch (e) {
    const msg = `Could not fetch current blob: ${errorMessage(e)}`;
    console.warn("[blob:get]", msg);
    warns.push(msg);
  }

  // Decide if we need to upload to Blob
  console.log("[decide:blob]", {
    existingRound: current?.round,
    existingRoot: current?.root,
    newRound: Number(round),
    newRoot: fileRoot,
    claimCount: claims.length,
  });

  if (
    current &&
    current.root.toLowerCase() === fileRoot.toLowerCase() &&
    current.round === Number(round)
  ) {
    console.log("[blob] skip upload (unchanged)");
    return wrap({
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
    });
  }

  let reason: "empty" | "unchanged" | "pushed" = "unchanged";
  try {
    console.log("[blob:put]", blobKey);
    const res = await put(blobKey, payloadStr, {
      access: "public",
      addRandomSuffix: false,
      contentType: "application/json",
      token: process.env.BLOB_READ_WRITE_TOKEN,
      allowOverwrite: true,
    });
    blobUrl = res.url;
    reason = "pushed";
    console.log("[blob:put] ok", blobUrl);
  } catch (e) {
    const msg = `Blob upload failed: ${errorMessage(e)}`;
    console.error("[blob:put]", msg);
    warns.push(msg);
  }

  // On-chain publish decision
  const needUpdate =
    fileRoot.toLowerCase() !== (onchainRoot as string).toLowerCase() ||
    round > (onchainRound as bigint);

  console.log("[decide:onchain]", {
    onchainRoot,
    onchainRound: onchainRound?.toString(),
    newRoot: fileRoot,
    newRound: Number(round),
    needUpdate,
  });

  let txHash: string | undefined;
  if (needUpdate && process.env.PUBLISHER_PRIVATE_KEY) {
    try {
      console.log("[publish] setRoot() sending tx…");
      const wallet = new ethers.Wallet(process.env.PUBLISHER_PRIVATE_KEY, provider);
      const distWithSigner = new Contract(distributorAddress, DIST_ABI, wallet);
      const tx = await distWithSigner.setRoot(fileRoot, round);
      console.log("[publish] sent", tx.hash);
      const receipt = await tx.wait();
      console.log("[publish] mined", receipt.transactionHash, "status", receipt.status);
      txHash = receipt.transactionHash;
    } catch (e) {
      const msg = `On-chain setRoot failed: ${errorMessage(e)}`;
      console.error("[publish]", msg);
      warns.push(msg);
    }
  } else if (needUpdate) {
    const msg = "setRoot needed but no PUBLISHER_PRIVATE_KEY provided — skipping on-chain update";
    console.warn("[publish]", msg);
    warns.push(msg);
  } else {
    console.log("[publish] no on-chain update needed");
  }

  return wrap({
    ok: true,
    updated: Boolean(txHash), // reflect actual on-chain update
    reason: addresses.length === 0 ? "empty" : reason, // keep API-compatible reason
    count: addresses.length,
    round: Number(round),
    fileRoot,
    onchainRoot,
    blobUrl,
    localPath,
    warn: warns.length ? warns : undefined,
    ...(txHash ? { txHash } : {}),
  });
}

export async function rebuildAndPush(): Promise<RebuildBatchItem[]> {
  const entries = Object.values(CHAIN_CONFIGS);
  const results: RebuildBatchItem[] = [];

  for (const config of entries) {
    try {
      console.log("[runner] start", { chainId: config.id, label: config.label });
      const result = await rebuildSingleChain({ chainId: config.id });
      console.log("[runner] done", { chainId: config.id, label: config.label, ok: result.result.ok });
      results.push(result);
    } catch (e) {
      console.error("[runner] chain failed", { chainId: config.id, label: config.label, error: errorMessage(e) });
      results.push({
        chainId: config.id,
        chainSlug: config.alchemyNetwork || `chain-${config.id}`,
        label: config.label,
        result: {
          ok: false,
          updated: false,
          count: 0,
          round: 0,
          fileRoot: ZERO32,
          warn: [`chain failed: ${errorMessage(e)}`],
        },
      });
    }
  }

  return results;
}
