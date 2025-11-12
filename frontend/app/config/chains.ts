import type { Address } from "viem";
import { sepolia, arbitrumSepolia, baseSepolia, zkSyncSepoliaTestnet } from "viem/chains";
import type { Chain } from "viem";

const ETH_SEP_RPC_URL = process.env.NEXT_PUBLIC_ETH_SEP_RPC_URL;
const ARB_SEP_RPC_URL = process.env.NEXT_PUBLIC_ARB_SEP_RPC_URL;
const BASE_SEP_RPC_URL = process.env.NEXT_PUBLIC_BAS_SEP_RPC_URL;
const ZKS_SEP_RPC_URL = process.env.NEXT_PUBLIC_ZKS_SEP_RPC_URL;

const ETH_SEP_CLAIMS_URL = process.env.NEXT_PUBLIC_ETH_SEP_CLAIMS_URL ?? process.env.NEXT_PUBLIC_CLAIMS_URL;
const ARB_SEP_CLAIMS_URL = process.env.NEXT_PUBLIC_ARB_SEP_CLAIMS_URL;
const BASE_SEP_CLAIMS_URL = process.env.NEXT_PUBLIC_BAS_SEP_CLAIMS_URL;
const ZKS_SEP_CLAIMS_URL = process.env.NEXT_PUBLIC_ZKS_SEP_CLAIMS_URL;

function envAddress(value?: string): Address | undefined {
  if (!value) return undefined;
  const normalized = value.startsWith("0x") ? value : `0x${value}`;
  return normalized as Address;
}

type ChainContracts = {
  nft?: Address;
  distributor?: Address;
  staking?: Address;
  token?: Address;
  claimsUrl?: string;
};

type ChainConfig = {
  id: number;
  label: string;
  wagmi: Chain;
  alchemyNetwork: string;
  rpcUrl?: string;
  contracts: ChainContracts;
};

export const DEFAULT_CHAIN_ID = sepolia.id;

export const CHAIN_CONFIGS: Record<number, ChainConfig> = {
  [sepolia.id]: {
    id: sepolia.id,
    label: "Ethereum Sepolia",
    wagmi: sepolia,
    alchemyNetwork: "eth-sepolia",
    rpcUrl: ETH_SEP_RPC_URL,
    contracts: {
      nft: envAddress(process.env.NEXT_PUBLIC_ETH_SEP_NFT_ADDRESS),
      distributor: envAddress(process.env.NEXT_PUBLIC_ETH_SEP_DISTRIBUTOR_ADDRESS),
      staking: envAddress(process.env.NEXT_PUBLIC_ETH_SEP_STAKING_ADDRESS),
      token: envAddress(process.env.NEXT_PUBLIC_ETH_SEP_TOKEN_ADDRESS),
      claimsUrl: ETH_SEP_CLAIMS_URL,
    },
  },
  /*[arbitrumSepolia.id]: {
    id: arbitrumSepolia.id,
    label: "Arbitrum Sepolia",
    wagmi: arbitrumSepolia,
    alchemyNetwork: "arb-sepolia",
    rpcUrl: ARB_SEP_RPC_URL,
    contracts: {
      nft: envAddress(process.env.NEXT_PUBLIC_ARB_SEP_NFT_ADDRESS),
      distributor: envAddress(process.env.NEXT_PUBLIC_ARB_SEP_DISTRIBUTOR_ADDRESS),
      staking: envAddress(process.env.NEXT_PUBLIC_ARB_SEP_STAKING_ADDRESS),
      token: envAddress(process.env.NEXT_PUBLIC_ARB_SEP_TOKEN_ADDRESS),
      claimsUrl: ARB_SEP_CLAIMS_URL,
    },
  },
  [baseSepolia.id]: {
    id: baseSepolia.id,
    label: "Base Sepolia",
    wagmi: baseSepolia,
    alchemyNetwork: "base-sepolia",
    rpcUrl: BASE_SEP_RPC_URL,
    contracts: {
      nft: envAddress(process.env.NEXT_PUBLIC_BASE_SEP_NFT_ADDRESS),
      distributor: envAddress(process.env.NEXT_PUBLIC_BASE_SEP_DISTRIBUTOR_ADDRESS),
      staking: envAddress(process.env.NEXT_PUBLIC_BASE_SEP_STAKING_ADDRESS),
      token: envAddress(process.env.NEXT_PUBLIC_BASE_SEP_TOKEN_ADDRESS),
      claimsUrl: BASE_SEP_CLAIMS_URL,
    },
  },
  [zkSyncSepoliaTestnet.id]: {
    id: zkSyncSepoliaTestnet.id,
    label: "zkSync Sepolia",
    wagmi: zkSyncSepoliaTestnet,
    alchemyNetwork: "zksync-sepolia",
    rpcUrl: ZKS_SEP_RPC_URL,
    contracts: {
      nft: envAddress(process.env.NEXT_PUBLIC_ZKS_SEP_NFT_ADDRESS),
      distributor: envAddress(process.env.NEXT_PUBLIC_ZKS_SEP_DISTRIBUTOR_ADDRESS),
      staking: envAddress(process.env.NEXT_PUBLIC_ZKS_SEP_STAKING_ADDRESS),
      token: envAddress(process.env.NEXT_PUBLIC_ZKS_SEP_TOKEN_ADDRESS),
      claimsUrl: ZKS_SEP_CLAIMS_URL,
    },
  },*/
};

export const CHAIN_LIST = Object.values(CHAIN_CONFIGS);

export function getChainConfig(chainId?: number): ChainConfig {
  return CHAIN_CONFIGS[chainId ?? DEFAULT_CHAIN_ID] ?? CHAIN_CONFIGS[DEFAULT_CHAIN_ID];
}
