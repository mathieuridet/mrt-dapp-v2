export function EmptyState({ title, subtitle, tone = "slate" }: { title: string; subtitle?: string; tone?: "slate" | "amber"; }) {
  const dot = tone === "amber" ? "bg-amber-400" : "bg-zinc-500";
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 text-center">
      <div className={`mx-auto mb-3 size-2 rounded-full ${dot}`} />
      <h3 className="font-semibold text-zinc-100">{title}</h3>
      {subtitle && <p className="mt-1 text-sm text-zinc-400">{subtitle}</p>}
    </div>
  );
}

export function Spinner() {
  return (
    <svg className="size-4 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4A4 4 0 008 12H4z"/>
    </svg>
  );
}

export function StatusBadge({ status }: { status: "idle" | "loading" | "not_eligible" | "claimed" | "claiming" | "ready" }) {
  const map = {
    idle:         { text: "Idle",          cls: "bg-zinc-800/60 text-zinc-300 border-zinc-700" },
    loading:      { text: "Loading data",  cls: "bg-indigo-500/10 text-indigo-300 border-indigo-500/30" },
    not_eligible: { text: "Not eligible",  cls: "bg-amber-500/10 text-amber-300 border-amber-500/30" },
    claimed:      { text: "Claimed",       cls: "bg-emerald-500/10 text-emerald-300 border-emerald-500/30" },
    claiming:     { text: "Claiming…",     cls: "bg-indigo-500/10 text-indigo-300 border-indigo-500/30" },
    ready:        { text: "Ready",         cls: "bg-emerald-500/10 text-emerald-300 border-emerald-500/30" },
  } as const;
  const { text, cls } = map[status];
  return <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium ${cls}`}>{text}</span>;
}

export function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-zinc-400">{label}</div>
      <div className="mt-1 text-lg font-semibold text-zinc-100">{value}</div>
    </div>
  );
}

export function Banner({ children, tone = "info" as "info" | "success" | "error" } : { children: React.ReactNode; tone?: "info" | "success" | "error"; }) {
  const toneMap = {
    info:    "bg-sky-500/10 text-sky-300 border-sky-500/30",
    success: "bg-emerald-500/10 text-emerald-300 border-emerald-500/30",
    error:   "bg-rose-500/10 text-rose-300 border-rose-500/30",
  } as const;
  return <div className={`rounded-xl border px-3 py-2 text-sm ${toneMap[tone]}`}>{children}</div>;
}
  

export function SkeletonBlock() {
  return (
    <div className="space-y-3">
      <div className="h-5 w-40 animate-pulse rounded bg-zinc-800" />
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="h-16 animate-pulse rounded-xl bg-zinc-800" />
        <div className="h-16 animate-pulse rounded-xl bg-zinc-800" />
      </div>
      <div className="h-10 w-28 animate-pulse rounded-xl bg-zinc-800" />
    </div>
  );
}