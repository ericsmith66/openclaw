---

# JS Troubleshooting Playbook (Importmap / Turbo / Chartkick)

This document is a repeatable playbook for diagnosing **JavaScript not executing**, **modules failing to import**, and **Chartkick/Chart.js charts stuck on `Loading...`**.

It is based on the actual incident where:
- `window.Chartkick` was `undefined`
- charts stayed on Chartkick’s `Loading...`
- the dashboard Sector Weights chart rendered fine on `/net_worth/sectors` but not when loaded via a Turbo Frame
- the browser requested unexpected URLs like `/_/MwoWUuIu.js` (404)

The goal is to avoid a “whack‑a‑mole” cycle by **confirming the layer that’s broken first** (module execution, module resolution, runtime exceptions, Turbo frame issues, DOM id collisions).

---

## 0) Mental model: 4 layers

When JS “doesn’t work”, you’re almost always failing in one of these layers:

1. **Entry module execution**
   - The browser never successfully executes the `application` module.
2. **Module resolution / importmap**
   - `import` fails (missing pin, wrong path, ESM dependencies not pinned, wrong export shape).
3. **Runtime execution**
   - JS executes but throws an exception before doing what you expect.
4. **DOM/Turbo integration**
   - HTML is injected via Turbo Frames but scripts don’t run/redraw, or IDs collide.

This playbook walks the layers in order.

---

## 1) First step: prove the entry module executes

### Why
If the `application` module aborts, **everything downstream fails**, and symptoms like `window.Chartkick` being undefined are secondary.

### How (fast)
Add a single boot marker at the top of the entrypoint (temporary during debugging):

```js
window.__nextgen_application_booted = true
```

Then in the browser console:

```js
window.__nextgen_application_booted
```

Interpretation:
- `true` → the entry module executed; proceed to runtime / integration checks.
- `undefined` → the entry module never executed; go straight to **module resolution errors**.

**Tip:** put the boot marker *before* other imports so even import failures later are distinguishable from “module never loaded”.

---

## 2) If entry module doesn’t boot: check browser console for the FIRST error

Always focus on the **first red error**. Later errors are usually cascading.

Common importmap/module errors we saw:

### A) Missing pinned dependency
Example:
```
Uncaught TypeError: Failed to resolve module specifier "@kurkle/color".
Relative references must start with either "/", "./", or "../".
```

Meaning:
- A library is imported as ESM and it depends on another package that **is not pinned**.

Fix:
- Add an importmap pin for that dependency.
- Rebuild/reload.

### B) Export shape mismatch (UMD vs ESM)
Example:
```
Uncaught SyntaxError: The requested module 'chart.js' does not provide an export named 'Chart'
```

Meaning:
- The code expects ESM exports (`import { Chart } from "chart.js"`) but importmap points at a UMD build (no exports), or vice versa.

Fix:
- Make `config/importmap.rb` and the JS import style consistent.

---

## 3) Confirm what the browser is actually loading

### Why
You might have:
- stale assets
- different entrypoints (`app/javascript/application.js` vs `app/assets/javascripts/application.js`)
- precompiled `public/assets/application-*.js` being served

### How
1. View page source.
2. Find the importmap entries:
   - `"application"`
   - `"chartkick"`
   - `"chart.js"`

Then open the referenced JS file directly in the browser:
- `http://<host>/assets/application-<digest>.js`

Confirm it contains the code you think it does.

**Rule:** never assume “I changed the file” == “the browser is running it”. Always open the served asset.

---

## 4) Chartkick + Chart.js: choose a stable integration strategy

### The risk
Different Chart.js distributions behave differently:

- **UMD build**
  - sets `window.Chart`
  - does **not** provide ESM named exports
  - generally simplest with importmap

- **ESM build**
  - uses ESM exports (`Chart`, `registerables`, etc.)
  - may require additional dependency pins (e.g., `@kurkle/color`)
  - if you vendor a jspm ESM bundle, it may reference chunk URLs like `/_/XXXX.js`

### Recommendation
For this project (Importmap + Rails + minimal surprises):

- Pin Chart.js to the official UMD build (jsDelivr) in `config/importmap.rb`.
- In the JS entrypoint:

```js
import Chartkick from "chartkick"
import "chart.js" // UMD, sets window.Chart

Chartkick.use(window.Chart)
window.Chartkick = Chartkick
```

This avoids:
- missing ESM dependencies
- internal chunk URLs (`/_/XXXX.js`)

---

## 5) If charts still show `Loading...` but JS is running

If `window.Chartkick` exists and the chart placeholder still shows `Loading...`, focus on:

### A) Inline createChart() script errors
Chartkick embeds inline scripts like:

```text
// Example (simplified)
var createChart = function() {
  new Chartkick["BarChart"]("chart-1", /* data */, /* options */)
}
```

If this throws, the placeholder stays.

Action:
- look for the first red error after the chart’s inline script.

### B) Turbo Frame insertion / redraw
Charts injected via Turbo Frames may need a redraw.

Recommendation:
Add a global redraw hook:

```js
const redrawChartkickCharts = () => {
  if (!window.Chartkick || typeof window.Chartkick.eachChart !== "function") return
  window.Chartkick.eachChart((chart) => chart.redraw())
}

document.addEventListener("turbo:load", redrawChartkickCharts)
document.addEventListener("turbo:frame-load", redrawChartkickCharts)
document.addEventListener("turbo:render", redrawChartkickCharts)
```

---

## 6) Dashboard-only failures: DOM id collisions (the subtle one)

### Symptom
- A chart renders fine on its own page (`/net_worth/sectors`)
- But on the dashboard, that same chart stays on `Loading...`
- Network requests are 200
- No obvious console errors

### Root cause
Chartkick auto-generates element IDs (`chart-1`, `chart-2`, ...). On a dashboard that already has charts:
- existing charts have already used `chart-1`, `chart-2`
- Turbo Frame content loads later and starts its own id sequence again
- Inline `createChart()` targets the wrong element ID

### Fix
Always set an explicit `id:` for charts that may be loaded into composite pages:

Example (ERB), shown escaped so markdown linters don’t try to parse it:

```text
<%= bar_chart data, id: "sector-weights-chart", ... %>
```

---

## 7) Turbo Frame troubleshooting checklist

If a Turbo Frame is stuck showing a skeleton/placeholder:

1. Network → check the frame request (`GET /net_worth/sectors`) status.
2. Open the frame URL directly in a tab.
3. Confirm the response contains:
   - `<turbo-frame id="sector-table-frame">`
4. Confirm it’s not redirecting to sign-in (302) or erroring (500).

---

## 8) Turbo Streams: “Message received but UI didn’t change” (missing target id)

### Symptom
- You can see Turbo Stream frames arriving over the `/cable` websocket (DevTools → Network → WS).
- The stream contains something like:
  - `<turbo-stream action="replace" target="sync-status"> ... </turbo-stream>`
- But the UI appears stuck (e.g., a “Syncing…” badge never flips to “Up to date”).
- In the browser console, `document.getElementById("sync-status")` returns `null`.

### What we initially suspected (but was NOT the root cause)
- Proxy/CDN/WebSocket instability (e.g., Cloudflare / a tunnel) because multiple `/cable` connections were visible and one closed shortly after opening.
  - That can cause missed updates, but in this incident the “complete” stream message was actually received.

### Root cause
The Turbo Stream `replace` targets an element by id. If the HTML you render **does not include the same `id` on the replacement root**, the first `replace` removes the target element from the DOM.

After that:
- subsequent broadcasts still arrive,
- but Turbo cannot apply them because there is no longer an element with `id="sync-status"`.

### Resolution
- Ensure the rendered partial/template being used as the replacement **contains** the target id on its root element.
  - Example: the partial should start with something like:

```text
<div id="sync-status" ...>
  ...
</div>
```

- Avoid wrapping the partial in an additional element that also uses the same id (duplicate IDs cause their own issues).

---

## 9) Warnings vs errors

These are usually safe to ignore:
- Safari “preloaded but not used” warnings for modulepreload
- CSS preload warnings

These matter:
- `Failed to resolve module specifier ...`
- `does not provide an export named ...`
- `Failed to fetch dynamically imported module`
- 404/500 for `/assets/application-*.js` or critical module dependencies

---

## 10) A faster isolation workflow (recommended)

When something breaks:

1. **Check boot marker** (`window.__nextgen_application_booted`).
2. If missing, fix **module resolution** (first console error) before touching UI code.
3. If present, verify `window.Chartkick` + `window.Chart`.
4. If chart works on standalone page but not dashboard, suspect **ID collisions** or Turbo redraw.

---

## 11) Post-incident cleanup

After fixing:
- Remove the boot marker line (or guard it behind a debug flag).
- Document the chosen Chart.js pin strategy in `config/importmap.rb` comments.
