"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useChainId, useSwitchChain } from "wagmi";
import { CHAIN_LIST, getChainConfig } from "@/app/config/chains";

const links = [
  { href: "/nft", label: "NFT" },
  { href: "/token/claim", label: "Claim" },
  { href: "/token/stake", label: "Stake" },
];

const chainOptions = CHAIN_LIST.map(({ id, label }) => ({ id, label }));

export default function NavBar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [chainMenuOpen, setChainMenuOpen] = useState(false);
  const chainId = useChainId();
  const { switchChainAsync, isPending: isSwitching } = useSwitchChain();

  const isActive = (href: string) =>
    pathname === href || (href !== "/nft" && pathname?.startsWith(href));

  const activeChain = getChainConfig(chainId);

  async function onSelectChain(targetId: number) {
    setChainMenuOpen(false);
    if (targetId === chainId || !switchChainAsync) return;
    try {
      await switchChainAsync({ chainId: targetId });
    } catch (error) {
      console.error("Failed to switch chain", error);
    }
  }

  return (
    <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/70 backdrop-blur supports-[backdrop-filter]:bg-white/60">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 lg:px-6">
        <Link href="/" className="flex items-center gap-2 text-base font-semibold tracking-tight lg:text-lg">
          <span className="rounded-full bg-black px-2 py-1 text-xs font-bold uppercase text-white">MRT</span>
          <span className="hidden text-sm text-slate-600 sm:inline">Multi-chain dApp Dashboard</span>
        </Link>

        <nav className="hidden items-center gap-1 rounded-full border border-slate-200 bg-white/80 px-2 py-1 text-sm shadow-sm md:flex">
          {links.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className={`rounded-full px-3 py-1 font-medium transition-colors ${
                isActive(href)
                  ? "bg-black text-white shadow"
                  : "text-slate-600 hover:bg-slate-100"
              }`}
            >
              {label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-3">
          <div className="relative hidden items-center gap-2 md:flex">
            <button
              onClick={() => setChainMenuOpen((v) => !v)}
              className="inline-flex items-center gap-2 rounded-full border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-600 shadow-sm transition-colors hover:bg-slate-100"
              aria-haspopup="listbox"
              aria-expanded={chainMenuOpen}
              disabled={isSwitching}
            >
              <span className="h-2 w-2 rounded-full bg-emerald-500" aria-hidden />
              {activeChain.label}
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                className={`h-3 w-3 transition-transform ${chainMenuOpen ? "rotate-180" : ""}`}
              >
                <path
                  fillRule="evenodd"
                  d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.25a.75.75 0 01-1.06 0L5.21 8.27a.75.75 0 01.02-1.06z"
                  clipRule="evenodd"
                />
              </svg>
            </button>
            {chainMenuOpen && (
              <ul
                className="absolute right-0 top-full z-40 mt-2 w-60 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-lg"
                role="listbox"
              >
                {chainOptions.map((chain) => (
                  <li key={chain.id}>
                    <button
                      onClick={() => onSelectChain(chain.id)}
                      className={`flex w-full items-center justify-between px-4 py-2 text-sm transition-colors ${
                        chain.id === activeChain.id
                          ? "bg-black text-white"
                          : "text-slate-600 hover:bg-slate-100"
                      }`}
                      role="option"
                      aria-selected={chain.id === activeChain.id}
                    >
                      {chain.label}
                      {chain.id === activeChain.id && (
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                          className="h-4 w-4"
                        >
                          <path
                            fillRule="evenodd"
                            d="M16.704 5.29a1 1 0 010 1.42l-7 7a1 1 0 01-1.408 0l-3.5-3.5a1 1 0 111.408-1.42l2.796 2.793 6.296-6.293a1 1 0 011.408 0z"
                            clipRule="evenodd"
                          />
                        </svg>
                      )}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="flex items-center gap-2 md:hidden">
            <ConnectButton accountStatus="address" chainStatus="icon" showBalance={false} />
            <button
              className="inline-flex items-center justify-center rounded-full border border-slate-300 bg-white p-2 text-slate-600 transition-colors hover:bg-slate-100"
              onClick={() => setOpen((v) => !v)}
              aria-label="Toggle menu"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                className="h-5 w-5"
              >
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {open && (
        <div className="md:hidden border-t border-slate-200 bg-white/95 backdrop-blur">
          <div className="flex items-center justify-between px-4 py-3">
            <span className="text-sm font-medium text-slate-600">Network</span>
            <select
              className="rounded-lg border border-slate-300 px-3 py-2 text-sm"
              value={activeChain.id}
              onChange={(event) => onSelectChain(Number(event.target.value))}
              disabled={isSwitching}
            >
              {chainOptions.map((chain) => (
                <option key={chain.id} value={chain.id}>
                  {chain.label}
                </option>
              ))}
            </select>
          </div>
          <nav className="flex flex-col px-4 py-3">
            {links.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                onClick={() => setOpen(false)}
                className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                  isActive(href)
                    ? "bg-black text-white"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                {label}
              </Link>
            ))}
          </nav>
        </div>
      )}
    </header>
  );
}
