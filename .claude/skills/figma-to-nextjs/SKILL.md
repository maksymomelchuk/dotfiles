---
name: figma-to-nextjs
description: Use when implementing a UI redesign or new component from a Figma file into a Next.js + Tailwind codebase. Covers Figma MCP workflow, design token mapping, asset handling, icon reuse, responsive layout, visual verification with Playwright, and hydration edge cases for time-dependent components.
argument-hint: "Figma URL or node ID to implement"
---

A workflow for translating Figma designs into production-quality,
maintainable code in any Next.js + Tailwind codebase. Covers style
mapping, asset handling, responsive layout, icon reuse, verification,
and hydration edge cases.

---

## 1. Read the design before touching code

Use the Figma MCP tools in this order to build a complete picture
before writing a single line:

**Step 1 — Get a screenshot first.**
`mcp__figma__get_screenshot` on the target node gives you the full
visual immediately. Use this as your reference throughout the session.

**Step 2 — Get design context on major sections.**
`mcp__figma__get_design_context` returns exact measurements, font
specs, spacing, and auto-generated reference code. Call it separately
on each major visual region (e.g. left column, right column, footer
strip) rather than the whole page at once — the output is more precise
and easier to reason about.

**Step 3 — Use metadata only for discovery.**
`mcp__figma__get_metadata` returns node IDs and positions in XML.
Use it only when you need to find child node IDs you don't have yet.
Always follow it with `get_design_context` on the nodes you care about.

**Step 3a — Handle truncated responses incrementally.**
`get_design_context` can return truncated output on complex or deeply-nested
designs. If the response appears cut off or a section is missing detail:
1. Call `get_metadata` on the truncated node to get its child node IDs.
2. Call `get_design_context` separately on each child node.
3. Repeat down the tree until you have complete specs for every region
   you need to implement.

Never infer missing values from partial output — fetch the actual data.

**Step 4 — Always get the mobile design separately.**
If the Figma frame is desktop-width, ask for the mobile Figma URL
before starting. Mobile designs routinely differ in:
- Stacking order (columns collapse, order may change)
- Image substitutions (desktop: layered HTML elements; mobile: single
  flattened composite image)
- Typography scale (smaller sizes, different weights or families)
- Gaps and padding (tighter on mobile)
- Components that are hidden entirely on one breakpoint

Never infer mobile layout from a desktop frame alone.

---

## 2. Explore the codebase in parallel

While Figma MCP calls are in-flight, explore the codebase so you
arrive at implementation with both sides understood simultaneously.

**What to always read:**

- **The Tailwind config** — read it fully. You need the complete list
  of custom colors, font families, border radii, screen breakpoints,
  spacing, and any custom animations/keyframes before mapping a single
  Figma value.

- **The target component and its neighbours** — read the file(s)
  being replaced and any components they import. Understand what
  currently exists before deciding what to keep, change, or delete.

- **The icon system** — find where icons live (a single large file,
  a directory of SVGs, a component library import). Knowing the
  available icons before you start prevents adding unnecessary assets.

- **Shared UI primitives** — find button, dialog, badge, and link
  components that the project already has. Reach for these before
  writing new ones.

---

## 3. Map Figma values to existing design tokens

Figma's dev panel surfaces raw hex values and pixel numbers. Translate
those raw values into whatever the codebase already has before writing
any class.

### Colors
For every color in the Figma spec:
1. Search the Tailwind config for the hex value.
2. Search the Tailwind config for likely token names based on the
   Figma layer name (e.g. Figma says "Green/700" → search for
   `green-700`).
3. If both match, use the Tailwind token class.
4. If only partially match (slightly different shade), decide with the
   user whether to: use the closest existing token, add a new token,
   or update the existing one.
5. Only use arbitrary Tailwind color classes (`text-[#014A1B]`) for
   values that genuinely have no token — typically one-off border or
   shadow colors on specific cards.

### Typography
For each text style in Figma, check the Tailwind config for:
- **Font family** — Figma shows the full font name (e.g. "Inter
  SemiBold"). The codebase likely has a shorter alias (`font-inter`).
  Grep the config for the alias, not the full name.
- **Font size** — check if a named size exists (`text-sm`, `text-xl`,
  custom sizes in `fontSize`) before using `text-[20px]`.
- **Font weight** — use standard Tailwind weight utilities
  (`font-medium`, `font-semibold`, `font-bold`), not inline
  `style={{ fontWeight: 500 }}`.
- **Line height and letter spacing** — check for named values in the
  config before using arbitrary values.

### Spacing, radius, shadows
- Map Figma padding/gap/margin values to the nearest Tailwind spacing
  step. Use arbitrary values only for positioning of absolutely-placed
  elements where no Tailwind step fits.
- Map border radius to Tailwind's rounded scale or custom tokens in
  the config.
- For box shadows, compare Figma's shadow spec to the config's
  `boxShadow` entries before writing `shadow-[0px_2px_15px_...]`.

---

## 4. Resolve unknowns before implementing

Before writing code, surface and resolve every decision that could
require a rework. Ask the user about:

- **Live vs. static content** — any number, counter, countdown, or
  rating that appears dynamic. Is it real-time, hardcoded, or fetched?
  If real-time, what is the data source or deadline?

- **CTA behavior** — for every button and link: what route, modal,
  or action does it trigger? Check existing code first; only ask if
  you cannot determine it from the codebase.

- **Image assets** — does the project already have the image, or does
  it need to be sourced? If from Figma, confirm it's acceptable to
  download from the Figma MCP server.

- **Icon matching** — before asking about icons, search the existing
  icon system for relevant keywords. Only raise it with the user if
  no match is found.

- **Brand color discrepancies** — when a Figma color value differs
  from the nearest Tailwind token, explicitly flag it and ask whether
  to accept the nearest token, add a new one, or update the existing
  one.

- **Cleanup scope** — for every component, image, or file the redesign
  makes obsolete: explicitly confirm deletion vs. keeping. Verify
  nothing else imports it before deleting.

- **Mobile layout** — if the user provides a mobile Figma link, study
  it. If not, ask. Never invent mobile layout from a desktop frame.

---

## 5. Downloading and using image assets

The Figma MCP server serves assets locally while the Figma app is open:

```bash
curl -s "http://localhost:3845/assets/<hash>.<ext>" \
  -o public/images/<descriptive-name>.<ext>
```

Name files descriptively after the page/feature and what the image
represents, not after Figma internals.

**Using images in Next.js:**
Always use `next/image` — never raw `<img>`. Import local assets as
static imports so Next.js infers dimensions:

```tsx
import heroPhoto from "@/public/images/hero-photo.png";
// <Image src={heroPhoto} alt="..." priority />
```

For `fill` mode, the parent must have `position: relative` and
explicit dimensions:

```tsx
<div className="relative h-[57px] w-full">
  <Image src={chart} alt="" fill className="object-contain" />
</div>
```

**When desktop and mobile need different images:**
Use responsive visibility classes to show the correct asset per
breakpoint:

```tsx
{/* Desktop: separate layered elements */}
<div className="hidden lg:block ...">
  <Image src={desktopPhoto} ... />
  <div className="absolute ...">{/* floating card */}</div>
</div>

{/* Mobile: single flattened composite */}
<div className="lg:hidden w-full">
  <Image src={mobileComposite} width={W} height={H} ... />
</div>
```

---

## 6. Reusing existing icons

Before importing any new SVG or adding a new icon, always search the
project's icon system:

```bash
grep -n "play\|headset\|support\|star\|arrow\|check" \
  path/to/icons.tsx | head -20
```

Match icons by concept, not by exact Figma name. The Figma icon might
be named "vuesax/linear/support" but the codebase has `Icons.headset`
or `Icons.support` — search by the concept the icon represents.

Only add a new icon when no existing one matches. Follow the project's
established icon pattern when adding.

---

## 7. Implementing responsive layout

### Establish the column structure first
Before adding content, decide the layout skeleton:
- How many columns at each breakpoint?
- Do columns stack or remain side by side?
- What is the breakpoint threshold?

### Responsive gaps
When Figma specifies different gaps at different breakpoints, encode
both in a single utility:

```tsx
className="flex flex-col gap-8 lg:gap-16"
// mobile: 32px   desktop: 64px
```

When a child needs extra margin to hit a specific target gap on one
breakpoint:

```tsx
<div className="mt-10 lg:mt-0 ...">
```

### Absolutely positioned elements (floating cards, badges, stickers)
When Figma uses absolute positioning for decorative elements overlaid
on content, calculate positions relative to the nearest positioned
container. Use the Figma pixel values directly as `left-[Npx]`,
`top-[Npx]`. Use `style={{ width: N, height: N }}` for the container
when Figma dimensions don't align with Tailwind's spacing scale:

```tsx
<div
  className="relative hidden flex-shrink-0 lg:block"
  style={{ width: 710, height: 579 }}
>
  <div className="absolute left-[81px] top-0 size-[520px] ...">
    {/* main image */}
  </div>
  <div className="absolute right-0 top-[94px] w-[277px] ...">
    {/* floating card */}
  </div>
</div>
```

### Text alignment per breakpoint
Figma mobile designs are typically center-aligned; desktop
left-aligned. Encode both:

```tsx
className="text-center lg:text-left items-center lg:items-start"
```

---

## 8. Visual verification with Playwright

After every significant change, verify with screenshots before moving on.
The Figma comparison at the two canvas widths is necessary but not
sufficient — also sweep the intermediate viewports where breakpoints
transition, because that's where horizontal overflow and layout breakage
typically appear.

### The viewport sweep
Test these widths at minimum:

| Width | Why |
|---|---|
| 375 | iPhone-class mobile |
| 768 | Tablet, common mobile-landscape |
| 1024 | Common `lg` breakpoint boundary |
| 1280 | Common `xl`/desktop activation |
| 1439 | One pixel below a 1440 breakpoint — single column should still be clean |
| 1440 | Figma's typical desktop canvas |
| 1920 | Wide displays — check for centered max-width vs left-aligned with empty space |

Adjust the list to whatever breakpoints your layout uses, but always
include **one pixel below** each layout breakpoint and **the breakpoint
itself** — that's where layout transitions snap.

### Programmatic overflow detection
Don't eyeball overflow — measure it. After each resize:

```js
mcp__playwright__browser_evaluate(() => ({
  viewport: window.innerWidth,
  scrollWidth: document.documentElement.scrollWidth,
  overflow: document.documentElement.scrollWidth > window.innerWidth,
}))
```

If `overflow: true`, enumerate the elements whose right edge is past
the viewport:

```js
() => {
  const out = [];
  for (const el of document.body.querySelectorAll('*')) {
    const r = el.getBoundingClientRect();
    if (r.right > window.innerWidth + 1 && r.width > 0) {
      out.push({
        tag: el.tagName,
        className: typeof el.className === 'string' ? el.className.slice(0, 100) : '',
        right: r.right,
        width: r.width,
        left: r.left,
      });
    }
  }
  return out.slice(0, 10);
}
```

The first few results are almost always the culprit — usually a
decorative element with negative `right-[...]`, an absolutely-positioned
sticker, or a fixed-width grid column that doesn't fit at the current
breakpoint.

### Reliable scrolling in Playwright
The page may have CSS `scroll-behavior: smooth` or a scroll-blocking
hook. `window.scrollTo(0, N)` can silently no-op or return the wrong
value. The reliable form:

```js
// Direct assignment skips smooth-scroll
document.documentElement.scrollTop = 600;

// Or scroll a specific element into view
const el = document.querySelector('.my-target');
el.scrollIntoView({ block: 'start' });
```

To screenshot a specific section deep in the page, find it by content
or a stable selector, not by raw scroll position — the page's height
changes as images load:

```js
const target = [...document.querySelectorAll('section')]
  .find(el => el.textContent?.toLowerCase().includes('the heading you want'));
target.scrollIntoView({ block: 'center' });
```

### Comparison loop with Figma
For each test width:

1. `mcp__playwright__browser_resize(width, height)`
2. Measure overflow programmatically
3. If the section sits below the fold at this width, scroll it into view
4. `mcp__playwright__browser_take_screenshot({ fullPage: false })`
5. Compare to the Figma screenshot (`mcp__figma__get_screenshot`)
   for that breakpoint
6. Read the relevant element's `getBoundingClientRect()` to confirm it
   matches the Figma's intended dimensions

### Reading console output
Playwright saves console logs to `.playwright-output/console-<timestamp>.log`.
Filter by your component's name to isolate your errors from pre-existing
third-party noise (analytics, auth SDKs, cookie banners):

```bash
grep -i "YourComponentName\|hydration\|text content" \
  .playwright-output/console-<timestamp>.log
```

### When to re-sweep
Re-run the full width sweep after:
- Any breakpoint change
- Any layout change (grid columns, padding, max-width, flex direction)
- Adding/repositioning any absolutely-positioned decorative element
- Before declaring the task complete

A change that fixes one width often breaks another — the sweep is what
catches it.

### Cleanup
Add `.playwright-output/` and `.playwright-mcp/` to `.gitignore` so
generated logs and screenshot artifacts don't get committed.

---

## 9. Hydration handling for time-dependent content

Any component that renders `Date.now()` in its initial state produces
a mismatch between server HTML and client HTML in Next.js App Router,
because `"use client"` components are still server-rendered for the
initial HTML.

### The pragmatic pattern
Initialize with `null`. Render a stable placeholder until `useEffect`
fires. Apply `suppressHydrationWarning` to the element that displays
the changing value:

```tsx
const [value, setValue] = useState<T | null>(null);

useEffect(() => {
  setValue(computeLiveValue());
  const id = setInterval(() => setValue(computeLiveValue()), interval);
  return () => clearInterval(id);
}, []);

// In JSX:
<span suppressHydrationWarning className="...">
  {value ? format(value) : placeholder}
</span>
```

### What does NOT work in Next.js App Router
| Approach | Why it fails |
|---|---|
| `useSyncExternalStore` with `getServerSnapshot` | Not called during client hydration for `"use client"` boundary components in App Router |
| `next/dynamic` with `ssr: false`, no `loading` | Server renders nothing → structural element mismatch |
| `next/dynamic` with `ssr: false` + `loading: <X>` | `loading` only renders on the client while JS downloads; server still renders nothing |

### Verify in production before over-engineering
React's hydration errors are stricter in development. Check whether
the warning appears in a production build before investing further:

```bash
pnpm build && pnpm start
```

If absent in production, it is a dev-mode artefact — leave it with a
brief code comment explaining the pattern.

---

## 10. Cleanup

**Verify nothing else imports what you are deleting:**
```bash
grep -rn "ComponentName\|filename" src/ --include="*.tsx" --include="*.ts"
```

Safe to delete if the only matches are the component's own export and
the file you just rewrote.

**Check for dead imports** in every file you edited.

**Run the project's quality checks:**
```bash
pnpm typecheck   # zero errors required
pnpm lint        # no new warnings in your files
```

---

## Implementation checklist

- [ ] Figma desktop screenshot captured for comparison
- [ ] Figma mobile screenshot captured for comparison
- [ ] All Figma color values mapped to existing Tailwind tokens
- [ ] All Figma font families matched to existing config keys
- [ ] All icons sourced from existing system where possible
- [ ] All image assets saved to `/public` (or project equivalent)
- [ ] Playwright viewport sweep run at the project's mobile, tablet,
      desktop, and wide widths, plus one pixel below each layout
      breakpoint and the breakpoint itself
- [ ] `document.documentElement.scrollWidth <= window.innerWidth` at
      every width tested (no horizontal overflow)
- [ ] Absolutely-positioned decorative elements (stickers, badges, floating
      cards) do not extend past the viewport at any width
- [ ] Desktop layout matches Figma at the canvas width
- [ ] Mobile layout matches Figma at the canvas width
- [ ] Browser console: no new errors beyond pre-existing third-party scripts
- [ ] Dynamic/live content works correctly after client mount
- [ ] All CTA destinations verified
- [ ] Dead components/files deleted after confirming no other imports
- [ ] `.playwright-output/` and `.playwright-mcp/` added to `.gitignore`
- [ ] TypeScript: zero errors
- [ ] Lint: no new warnings
