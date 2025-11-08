import React, { useEffect, useState } from "react";

import type { Address } from "viem";

type NFT = {
  contract: { address: string };
  tokenId: string;
  title?: string;
  // v3 fields
  image?: { cachedUrl?: string; thumbnailUrl?: string; pngUrl?: string; originalUrl?: string };
  tokenUri?: { raw?: string; gateway?: string };
  // legacy/v2-ish fields
  media?: { gateway?: string; raw?: string }[];
  metadata?: { image?: string; name?: string; image_url?: string };
};

function resolveIpfs(u?: string) {
  if (!u) return "";
  // handles ipfs://CID/... and ipfs://ipfs/CID/...
  return u.startsWith("ipfs://")
    ? `https://nftstorage.link/ipfs/${u.replace("ipfs://", "").replace(/^ipfs\//, "")}`
    : u;
}

function pickImage(nft: NFT): string {
  return (
    // Alchemy v3 preferred
    nft.image?.cachedUrl ||
    nft.image?.pngUrl ||
    nft.image?.originalUrl ||
    nft.image?.thumbnailUrl ||
    // Legacy / normalized media
    nft.media?.[0]?.gateway ||
    // Metadata image fields
    resolveIpfs(nft.metadata?.image || nft.metadata?.image_url) ||
    // Token URI fallbacks
    resolveIpfs(nft.tokenUri?.gateway || nft.tokenUri?.raw) ||
    ""
  );
}

export default function NFTGrid({
  owner,
  alchemyNetwork,
  contractAddress,
}: {
  owner?: string;
  alchemyNetwork: string;
  contractAddress?: Address;
}) {
  const [nfts, setNfts] = useState<NFT[]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!owner || !contractAddress) return;
    (async () => {
      setLoading(true);
      setErr(null);
      try {
        const apiKey = process.env.NEXT_PUBLIC_ALCHEMY_API_KEY!;
        const url = `https://${alchemyNetwork}.g.alchemy.com/nft/v3/${apiKey}/getNFTsForOwner?owner=${owner}&withMetadata=true&contractAddresses[]=${contractAddress}`;
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setNfts(data.ownedNfts || data.nfts || []);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        setErr(msg);
      } finally {
        setLoading(false);
      }
    })();
  }, [owner, alchemyNetwork, contractAddress]);

  if (err) return <div style={{ color: "crimson" }}>Error: {err}</div>;

  if (!contractAddress) {
    return <div className="text-sm text-red-400">Missing NFT contract address for this network.</div>;
  }

  return (
    <div className="p-4">
      {loading && <div>Loading NFTs…</div>}
      {!loading && nfts.length === 0 && <div>No NFTs found.</div>}

      {/* Horizontally scrollable row */}
      <div
        className="flex gap-4 overflow-x-auto pb-2"
        style={{ scrollSnapType: "x mandatory" }}
      >
        {nfts.map((nft, i) => {
          const img = pickImage(nft);
          const name =
            nft.metadata?.name ||
            nft.title ||
            `${nft.contract.address.slice(0, 6)}… #${nft.tokenId}`;

          return (
            <figure
              key={`${nft.contract.address}-${nft.tokenId}-${i}`}
              className="shrink-0 snap-center"
              style={{
                width: 180,
                borderRadius: 12,
                overflow: "hidden",
                boxShadow: "0 4px 12px rgba(0,0,0,.08)",
                background: "#fff",
              }}
            >
              {img ? (
                <img
                  src={img}
                  alt={name}
                  style={{
                    width: "100%",
                    height: 220,
                    objectFit: "cover",
                  }}
                  loading="lazy"
                />
              ) : (
                <div
                  style={{
                    height: 220,
                    display: "grid",
                    placeItems: "center",
                    background: "#f3f4f6",
                  }}
                >
                  No image
                </div>
              )}
            </figure>
          );
        })}
      </div>
    </div>
  );
}

