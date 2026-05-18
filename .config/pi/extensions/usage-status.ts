/**
 * Pi usage-status footer — single line, always pinned at bottom.
 *
 *   ~/dotfiles (main)  64k · 5h: 13% · 18:20 · ⠸ working…   claude-sonnet-4-6 · thinking off
 *
 * Pi's built-in loading-indicator row is hidden so line count stays constant
 * between working/idle states (that's what was causing the footer to jump).
 * A braille spinner + "working…" appears inline while the agent is busy.
 *
 * Rate-limit data from Anthropic response headers:
 *   anthropic-ratelimit-unified-5h-utilization  → 5h%
 *   anthropic-ratelimit-unified-5h-reset        → reset clock (Unix seconds)
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const SPINNER = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"];

function fmt(n: number): string {
	if (n < 1_000)     return `${n}`;
	if (n < 10_000)    return `${(n / 1_000).toFixed(1)}k`;
	if (n < 1_000_000) return `${Math.round(n / 1_000)}k`;
	if (n < 10_000_000)return `${(n / 1_000_000).toFixed(1)}M`;
	return `${Math.round(n / 1_000_000)}M`;
}

function hhmm(ts: number): string {
	const d = new Date(ts);
	return `${String(d.getHours()).padStart(2,"0")}:${String(d.getMinutes()).padStart(2,"0")}`;
}

function pickHeader(h: Record<string,string>, ...names: string[]): string | undefined {
	for (const n of names) { const v = h[n] ?? h[n.toLowerCase()]; if (v) return v; }
}

export default function (pi: ExtensionAPI) {
	let fiveHourPct:   number | null = null;
	let resetAt:       number | null = null;
	let thinkingLevel  = "off";
	let tuiRef:        any           = null;
	let isWorking      = false;
	let spinnerIdx     = 0;
	let spinnerTimer:  ReturnType<typeof setInterval> | null = null;

	pi.on("agent_start", async (_e, ctx) => {
		isWorking = true;
		ctx.ui.setWorkingVisible(false); // hide Pi's loading row to keep line count stable
		if (!spinnerTimer) spinnerTimer = setInterval(() => {
			spinnerIdx = (spinnerIdx + 1) % SPINNER.length;
			tuiRef?.requestRender();
		}, 100);
	});

	pi.on("agent_end", async () => {
		isWorking = false;
		if (spinnerTimer) { clearInterval(spinnerTimer); spinnerTimer = null; spinnerIdx = 0; }
		tuiRef?.requestRender();
	});

	pi.on("turn_end", async () => { tuiRef?.requestRender(); });

	pi.on("thinking_level_select", async (event) => {
		thinkingLevel = event.level;
		tuiRef?.requestRender();
	});

	pi.on("after_provider_response", (event) => {
		const h = event.headers as Record<string, string>;
		const util = pickHeader(h, "anthropic-ratelimit-unified-5h-utilization");
		if (util) { const u = Number(util); if (!isNaN(u)) fiveHourPct = Math.min(100, u * 100); }
		const reset = pickHeader(h, "anthropic-ratelimit-unified-5h-reset", "anthropic-ratelimit-unified-reset");
		if (reset) { const s = Number(reset); if (!isNaN(s) && s > 1e9) resetAt = s * 1_000; }
		// Fallback: estimate reset as first-call + 5 h when headers absent
		if (resetAt === null) resetAt = Date.now() + 5 * 60 * 60 * 1_000;
	});

	pi.on("session_start", async (e, ctx) => {
		if (e.reason === "new" || e.reason === "startup") {
			fiveHourPct = null; resetAt = null; thinkingLevel = "off";
		}
		ctx.ui.setWorkingVisible(false);
		attachFooter(ctx);
	});

	pi.on("session_shutdown", async () => {
		if (spinnerTimer) { clearInterval(spinnerTimer); spinnerTimer = null; }
	});

	function attachFooter(ctx: ExtensionContext) {
		ctx.ui.setFooter((tui, theme, footerData) => {
			tuiRef = tui;
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// Left: pwd · git · session name
					let pwd = ctx.cwd;
					const home = process.env.HOME ?? process.env.USERPROFILE ?? "";
					if (home && pwd.startsWith(home)) pwd = `~${pwd.slice(home.length)}`;
					const branch = footerData.getGitBranch();
					if (branch) pwd += ` (${branch})`;
					const sname = ctx.sessionManager.getSessionName?.();
					if (sname) pwd += ` \u2022 ${sname}`;

					// Stats: tokens · 5h% · reset · spinner
					let tokens = 0;
					for (const e of ctx.sessionManager.getEntries()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							tokens += (m.usage?.input ?? 0) + (m.usage?.output ?? 0);
						}
					}
					const parts: string[] = [];
					if (tokens > 0) parts.push(fmt(tokens));
					if (fiveHourPct !== null) {
						const p = Math.round(fiveHourPct);
						parts.push(theme.fg(p >= 80 ? "error" : p >= 50 ? "warning" : "success", `5h: ${p}%`));
					}
					if (resetAt !== null) parts.push(hhmm(resetAt));
					if (isWorking) parts.push(theme.fg("accent", SPINNER[spinnerIdx]) + theme.fg("dim", " working\u2026"));
					const stats = parts.join(" \u00b7 ");

					// Right: (provider) model · thinking
					const model = ctx.model;
					const mname = model?.id ?? "no-model";
					let right = model?.reasoning
						? `${mname} \u2022 ${thinkingLevel === "off" ? "thinking off" : thinkingLevel}`
						: mname;
					if (footerData.getAvailableProviderCount() > 1 && model)
						right = `(${model.provider}) ${right}`;

					// Layout: [pwd  stats] ··· [right]
					const left  = pwd + (stats ? "  " : "");
					const leftW = visibleWidth(left) + visibleWidth(stats);
					const rightW = visibleWidth(right);
					let line: string;
					if (leftW + 2 + rightW <= width) {
						line = theme.fg("dim", left) + stats + theme.fg("dim", " ".repeat(width - leftW - rightW) + right);
					} else if (width - leftW - 2 > 0) {
						const r = truncateToWidth(right, width - leftW - 2, "");
						line = theme.fg("dim", left) + stats + theme.fg("dim", " ".repeat(Math.max(0, width - leftW - visibleWidth(r))) + r);
					} else {
						line = theme.fg("dim", left) + stats;
					}

					return [truncateToWidth(line, width, theme.fg("dim", "..."))];
				},
			};
		});
	}
}
