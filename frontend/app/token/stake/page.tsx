"use client";

import * as React from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from "wagmi";
import type { Abi } from "viem";
import StakingAbi from "@/abi/StakingVault.json";
import { formatUnits, parseUnits } from "viem";
import { EmptyState, Stat, Banner } from "@/app/components/Helpers";
import { getChainConfig } from "@/app/config/chains";

const erc20Abi = [
  { name: "decimals", stateMutability: "view", type: "function", inputs: [], outputs: [{ type:"uint8" }] },
  { name: "balanceOf", stateMutability: "view", type: "function", inputs: [{name:"a",type:"address"}], outputs: [{type:"uint256"}] },
  { name: "allowance", stateMutability: "view", type: "function", inputs: [{name:"o",type:"address"},{name:"s",type:"address"}], outputs: [{type:"uint256"}] },
  { name: "approve", stateMutability: "nonpayable", type: "function", inputs: [{name:"s",type:"address"},{name:"a",type:"uint256"}], outputs: [{type:"bool"}] },
] as const;

const stakingViewAbi = [
  { name:"balanceOf", stateMutability:"view", type:"function", inputs:[{name:"a",type:"address"}], outputs:[{type:"uint256"}] },
  { name:"earned", stateMutability:"view", type:"function", inputs:[{name:"a",type:"address"}], outputs:[{type:"uint256"}] },
] as const;

const erc20AbiTyped = erc20Abi as unknown as Abi;
const stakingViewAbiTyped = stakingViewAbi as unknown as Abi;
const stakingAbi = StakingAbi as unknown as Abi;
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as `0x${string}`;

export default function StakePage() {
  const { address } = useAccount();
  const chainId = useChainId();
  const chainConfig = getChainConfig(chainId);
  const stakingAddress = chainConfig.contracts.staking;
  const tokenAddress = chainConfig.contracts.token;
  const isConfigured = Boolean(stakingAddress && tokenAddress);

  const [amount, setAmount] = React.useState("0");

  React.useEffect(() => {
    setAmount("0");
  }, [chainId]);

  const staking = (stakingAddress ?? ZERO_ADDRESS) as `0x${string}`;
  const token = (tokenAddress ?? ZERO_ADDRESS) as `0x${string}`;

  const { data: decimals } = useReadContract({
    address: token,
    abi: erc20AbiTyped,
    functionName: "decimals",
    query: { enabled: isConfigured },
  });

  const decimalsNumber = decimals != null ? Number(decimals) : undefined;

  const formatBalance = (value: unknown) => {
    if (decimalsNumber === undefined) return "…";
    const normalized = typeof value === "bigint" ? value : 0n;
    return `${Number(formatUnits(normalized, decimalsNumber)).toLocaleString(undefined, {
      minimumFractionDigits: 0,
      maximumFractionDigits: 3,
    })} MRT`;
  };

  const { data: walletBal, refetch: refetchWallet } = useReadContract({
    address: token,
    abi: erc20AbiTyped,
    functionName: "balanceOf",
    args: address ? ([address] as const) : undefined,
    query: { enabled: !!address && isConfigured }
  });

  const { data: stakedBal, refetch: refetchStaked } = useReadContract({
    address: staking,
    abi: stakingViewAbiTyped,
    functionName: "balanceOf",
    args: address ? ([address] as const) : undefined, query: { enabled: !!address && isConfigured }
  });
  const { data: earned, refetch: refetchEarned } = useReadContract({
    address: staking,
    abi: stakingViewAbiTyped,
    functionName: "earned",
    args: address ? ([address] as const) : undefined, query: { enabled: !!address && isConfigured, refetchInterval: 5000 }
  });
  const { data: allowance } = useReadContract({
    address: token,
    abi: erc20AbiTyped,
    functionName: "allowance",
    args: address ? ([address, staking] as const) : undefined, query: { enabled: !!address && isConfigured }
  });

  const { writeContract, data: txHash, isPending, error: writeError } = useWriteContract();
  const { isLoading: waiting, isSuccess, isError, error: txError } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  React.useEffect(() => {
  if (isSuccess) {
    refetchWallet();
    refetchStaked();
    refetchEarned();
  }
}, [isSuccess, refetchWallet, refetchStaked, refetchEarned]);

  const needsApprove =
    isConfigured &&
    decimalsNumber !== undefined &&
    parseUnits(amount || "0", decimalsNumber) > (allowance as bigint ?? 0n);

  const doApprove = () => {
    if (!isConfigured || decimalsNumber === undefined) return;
    writeContract({
      address: token,
      abi: erc20AbiTyped,
      functionName: "approve",
      args: [staking, parseUnits(amount, decimalsNumber)] as const
    });
  };

  const doStake = () => {
    if (!isConfigured || decimalsNumber === undefined) return;
    writeContract({
      address: staking,
      abi: stakingAbi,
      functionName: "stake",
      args: [parseUnits(amount, decimalsNumber)] as const
    });
  };

  const doUnstake = () => {
    if (!isConfigured || decimalsNumber === undefined) return;
    writeContract({
      address: staking,
      abi: stakingAbi,
      functionName: "withdraw",
      args: [parseUnits(amount, decimalsNumber)] as const
    });
  };

  const doClaim = () => {
    if (!isConfigured) return;
    writeContract({ address: staking, abi: stakingAbi, functionName: "getReward", args: [] });
  };

  return (
    <div className="min-h-screen bg-black text-zinc-200 py-10 px-4">
      <div className="max-w-xl mx-auto">
        {/* Header */}
        <div className="mb-6">
          <h1 className="text-3xl font-extrabold tracking-tight">
            <span className="bg-gradient-to-r from-indigo-400 to-fuchsia-400 bg-clip-text text-transparent">
              Stake MRT
            </span>
          </h1>
          <p className="text-zinc-400 mt-1">
            {isConfigured
              ? "Stake your tokens to earn rewards. You can unstake or claim rewards anytime."
              : `Staking/token addresses not configured for ${chainConfig.label}.`}
          </p>
        </div>

        {/* Card */}
        <div className="rounded-2xl border border-zinc-800 bg-zinc-900/70 shadow-2xl backdrop-blur-sm">
          <div className="p-5 sm:p-6 space-y-5">
            {!isConfigured && (
              <EmptyState
                title="Contract not configured"
                subtitle={`Set NEXT_PUBLIC_* staking/token addresses for ${chainConfig.label} to enable staking.`}
                tone="amber"
              />
            )}

            {/* Wallet connection state */}
            {isConfigured && !address && (
              <EmptyState
                title="Connect your wallet"
                subtitle="You need to connect your wallet to stake tokens."
              />
            )}

            {isConfigured && address && (
              <>
                {/* Balances */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <Stat label="Wallet" value={formatBalance(walletBal)} />
                  <Stat label="Staked" value={formatBalance(stakedBal)} />
                  <Stat label="Earned" value={formatBalance(earned)} />
                </div>

                {/* Stake form */}
                <div className="space-y-4 pt-2">
                  <input
                    className="w-full rounded-xl border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm text-zinc-200 placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    placeholder="Amount to (un)stake"
                    value={amount}
                    onChange={(e) => {
                      const val = e.target.value;

                      if (val === "") {
                        setAmount("");
                        return;
                      }

                      if (/^\d+$/.test(val)) {
                        const normalized = String(parseInt(val, 10));
                        setAmount(normalized);
                      }
                    }}
                    inputMode="numeric"
                    pattern="[0-9]*"
                  />

                  {needsApprove ? (
                    <button
                      onClick={doApprove}
                      disabled={!isConfigured || isPending || waiting}
                      className="inline-flex items-center justify-center gap-2 rounded-xl px-5 py-2.5 text-sm font-semibold text-white shadow-sm disabled:opacity-60 bg-gradient-to-r from-indigo-500 to-fuchsia-600 hover:from-indigo-400 hover:to-fuchsia-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/60"
                      aria-busy={waiting || isPending}
                    >
                      {isPending || waiting ? "Approving…" : "Approve"}
                    </button>
                  ) : (
                    <button
                      onClick={doStake}
                      disabled={!isConfigured || Number(amount) === 0 || isPending || waiting}
                      className="inline-flex items-center justify-center gap-2 rounded-xl px-5 py-2.5 text-sm font-semibold text-white shadow-sm disabled:opacity-60 bg-gradient-to-r from-indigo-500 to-fuchsia-600 hover:from-indigo-400 hover:to-fuchsia-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/60"
                      aria-busy={waiting || isPending}
                    >
                      {isPending || waiting ? "Staking…" : "Stake"}
                    </button>
                  )}

                  <div className="flex gap-3">
                    <button
                      onClick={doUnstake}
                      disabled={!isConfigured || (stakedBal ?? 0n) === 0n || Number(amount) === 0 || isPending || waiting}
                      className="flex-1 rounded-xl border border-zinc-700 bg-zinc-800 px-4 py-2 text-sm font-medium text-zinc-200 hover:bg-zinc-700 disabled:opacity-50"
                    >
                      Unstake
                    </button>
                    <button
                      onClick={doClaim}
                      disabled={!isConfigured || (earned ?? 0n) === 0n || isPending || waiting}
                      className="flex-1 rounded-xl border border-zinc-700 bg-zinc-800 px-4 py-2 text-sm font-medium text-zinc-200 hover:bg-zinc-700 disabled:opacity-50"
                    >
                      Claim rewards
                    </button>
                  </div>

                  {/* Success / Error */}
                  {isSuccess && (
                    <Banner tone="success">✅ Transaction confirmed: {txHash?.slice(0, 10)}…</Banner>
                  )}

                  {writeError && (
                    <Banner tone="error">
                      <b>Error:</b> {writeError.message}
                    </Banner>
                  )}

                  {isError && (
                    <Banner tone="error">
                      <b>Tx failed:</b> {txError?.message || "Unknown error"}
                    </Banner>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );

}
