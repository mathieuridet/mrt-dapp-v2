"use client";
import { useEffect, useState, useMemo } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, useChainId } from "wagmi";
import { formatUnits, type Abi } from "viem";
import MRTNFToken from "../../abi/MRTNFToken.json";
import NFTGrid from "../components/NFTGrid";
import { EmptyState } from "@/app/components/Helpers";
import { getChainConfig } from "@/app/config/chains";

const nftAbi = MRTNFToken.abi as unknown as Abi;
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as `0x${string}`;

export default function Page() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const chainConfig = getChainConfig(chainId);
  const nftAddress = chainConfig.contracts.nft;
  const isConfigured = Boolean(nftAddress);

  const [qty, setQty] = useState(1);

  useEffect(() => {
    setQty(1);
  }, [chainId]);

  const nftContract = (nftAddress ?? ZERO_ADDRESS) as `0x${string}`;

  const { data: price } = useReadContract({
    address: nftContract,
    abi: nftAbi,
    functionName: "i_mintPrice",
    query: { enabled: isConfigured },
  });
  const {
    data: max,
    error,
    isLoading,
    isError,
  } = useReadContract({
    address: nftContract,
    abi: nftAbi,
    functionName: "i_maxSupply",
    query: { enabled: isConfigured },
  });
    
  const { data: supply } = useReadContract({
    address: nftContract,
    abi: nftAbi,
    functionName: "totalSupply",
    query: { enabled: isConfigured },
  });
  
  const { writeContractAsync, data: txHash } = useWriteContract();
  const { isLoading: isPending, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const { data: balance, refetch: refetchBalance } = useReadContract({
      address: nftContract,
      abi: nftAbi,
      functionName: "balanceOf",
      args: address ? ([address] as const) : undefined,
      query: { enabled: !!address && isConnected && isConfigured },
    });

  const [nftRefreshKey, setNftRefreshKey] = useState(0);

  const { data: lastMint, refetch: refetchLastMint } = useReadContract({
    address: nftContract,
    abi: nftAbi,
    functionName: "lastMint",
    args: address ? ([address] as const) : undefined,
    query: { enabled: !!address && isConfigured },
  });  
  const lastMintTs = lastMint ? Number(lastMint) : 0;

  const { data: mintIntervalRaw } = useReadContract({
    address: nftContract,
    abi: nftAbi,
    functionName: "MINT_INTERVAL",
    query: { enabled: isConfigured },
  });
  const mintInterval = mintIntervalRaw ? Number(mintIntervalRaw) : 0;
  const canMint = !lastMintTs || (Date.now() / 1000 - lastMintTs) >= mintInterval;

  useEffect(() => {
    if (isSuccess) {
      refetchBalance();
      refetchLastMint();

      setNftRefreshKey((k) => k + 1);
    }
  }, [isSuccess, refetchBalance, refetchLastMint]);

  const mintPrice = useMemo(() => {
    if (!isConfigured) return 0n;
    if (typeof price === "bigint") return price;
    if (typeof price === "number") return BigInt(price);
    if (typeof price === "string") return BigInt(price);
    return 0n;
  }, [price, isConfigured]);

  const cost = useMemo(() => (mintPrice * BigInt(qty)).toString(), [mintPrice, qty]);

  const supplyDisplay = isConfigured && supply != null ? supply.toString() : "-";
  const maxDisplay = isConfigured && typeof max === "bigint" ? formatUnits(max, 18) : "-";

  async function onMint() {
    if (!isConfigured) return;
    await writeContractAsync({
      address: nftContract,
      abi: nftAbi,
      functionName: "mint",
      args: [BigInt(qty)] as const,
      value: BigInt(cost),
    });
  }



  return (
    <div className="min-h-screen bg-black text-zinc-200 py-10 px-4">
      <div className="max-w-xl mx-auto">
        <div className="mb-6">
          <h1 className="text-3xl font-extrabold tracking-tight">
            <span className="bg-gradient-to-r from-indigo-400 to-fuchsia-400 bg-clip-text text-transparent">
              Mint MRTNFT
            </span>
          </h1>
          <p className="text-zinc-400 mt-1">
            {isConfigured
              ? "Mint your MRT NFT directly from the contract."
              : `NFT contract not configured for ${chainConfig.label}.`}
          </p>
        </div>

        <div className="rounded-2xl border border-zinc-800 bg-zinc-900/70 shadow-2xl backdrop-blur-sm">
          <div className="p-5 sm:p-6 space-y-5">
            <div className="space-y-1 text-sm">
              <p className="truncate">
                <span className="text-zinc-400">Contract:</span>{" "}
                <span className="font-mono text-zinc-200">{nftContract}</span>
              </p>
              <p>
                <span className="text-zinc-400">Supply:</span>{" "}
                {supplyDisplay} / {maxDisplay}
              </p>
              <p>
                <span className="text-zinc-400">Price:</span>{" "}
                {mintPrice ? `${Number(mintPrice) / 1e18} ETH` : "-"}
              </p>
            </div>

            {!isConfigured && (
              <EmptyState
                title="Contract not configured"
                subtitle={`Set NEXT_PUBLIC_*_NFT_ADDRESS for ${chainConfig.label} to enable minting.`}
                tone="amber"
              />
            )}

            {isConfigured && !isConnected && (
              <EmptyState
                title="Connect your wallet"
                subtitle="You need to connect your wallet to mint NFTs."
              />
            )}

            {isConfigured && isConnected && (
              <>
                <div className="grid gap-3 sm:grid-cols-[auto,1fr,auto] items-center">
                  <label htmlFor="qty" className="text-sm text-zinc-400">
                    Quantity
                  </label>
                  <input
                    id="qty"
                    type="number"
                    min={1}
                    max={10}
                    value={qty}
                    onChange={(e) =>
                      setQty(Math.max(1, Number(e.target.value)))
                    }
                    className="w-24 rounded-xl border border-zinc-700 bg-zinc-900 px-3 py-2 text-right font-mono text-zinc-200 placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/60"
                  />
                  <button
                    disabled={!price || isPending || !canMint || !isConfigured}
                    onClick={onMint}
                    className="inline-flex items-center justify-center gap-2 rounded-xl px-5 py-2.5 text-sm font-semibold text-white shadow-sm disabled:opacity-60 bg-gradient-to-r from-indigo-500 to-fuchsia-600 hover:from-indigo-400 hover:to-fuchsia-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/60"
                    aria-busy={isPending}
                    title={!canMint ? "You can mint only once per hour" : "Mint a new NFT"}
                  >
                    {isPending ? "Minting…" : `Mint ${qty}`}
                  </button>
                </div>

                <p className="text-sm text-zinc-400">
                  Total cost:{" "}
                  <span className="font-mono text-zinc-200">
                    {Number(mintPrice) * qty / 1e18} ETH
                  </span>
                </p>

                <div className="pt-3 space-y-2 text-xs text-zinc-500">
                  <p className="text-zinc-400">
                    My NFTs ({(balance ?? 0).toString()})
                  </p>

                  <div className="relative">
                    <div className="overflow-x-auto">
                      <div className="flex gap-3 pb-2">
                        <NFTGrid
                          key={nftRefreshKey}
                          owner={address}
                          alchemyNetwork={chainConfig.alchemyNetwork}
                          contractAddress={isConfigured ? nftContract : undefined}
                        />
                      </div>
                    </div>

                    <div className="absolute inset-y-0 left-0 flex items-center">
                      <button
                        onClick={() => {
                          document.querySelector(".overflow-x-auto")?.scrollBy({ left: -200, behavior: "smooth" });
                        }}
                        className="p-2 rounded-full bg-zinc-800/80 hover:bg-zinc-700"
                      >
                        ◀
                      </button>
                    </div>
                    <div className="absolute inset-y-0 right-0 flex items-center">
                      <button
                        onClick={() => {
                          document.querySelector(".overflow-x-auto")?.scrollBy({ left: 200, behavior: "smooth" });
                        }}
                        className="p-2 rounded-full bg-zinc-800/80 hover:bg-zinc-700"
                      >
                        ▶
                      </button>
                    </div>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
