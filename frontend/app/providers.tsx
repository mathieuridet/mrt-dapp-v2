"use client";

import "@rainbow-me/rainbowkit/styles.css";
import { getDefaultConfig, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { WagmiProvider, http } from "wagmi";
import type { Chain } from "viem";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { CHAIN_LIST } from "@/app/config/chains";

const wagmiChains = CHAIN_LIST.map((chain) => chain.wagmi) as [Chain, ...Chain[]];

const transports = CHAIN_LIST.reduce<Record<number, ReturnType<typeof http>>>((acc, chain) => {
  if (!chain.rpcUrl) {
    throw new Error(`Missing RPC URL for ${chain.label}. Set the appropriate NEXT_PUBLIC_*_RPC_URL env variable.`);
  }
  acc[chain.id] = http(chain.rpcUrl);
  return acc;
}, {});

const config = getDefaultConfig({
  appName: "MRTNFT Mint",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID!, // from Reown/WalletConnect
  chains: wagmiChains,
  transports,
  ssr: true, // optional but recommended for Next.js App Router
});

const queryClient = new QueryClient();

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
