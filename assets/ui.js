// Shared helpers: categories, date/time formatting, generated cover images,
// and the event-card markup used on the public feed.

export const CATS = ["Music", "Nightlife", "Outdoors", "Sport", "Arts", "Markets"];
export const CATS_WITH_ALL = ["All", ...CATS];

const DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const DOW_PLURAL = ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"];
const MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export function fmtDate(iso) {
  const d = new Date(iso);
  return `${DOW[d.getDay()]} ${d.getDate()} ${MON[d.getMonth()]}`;
}
export function fmtTime(iso) {
  const d = new Date(iso);
  return d.toTimeString().slice(0, 5);
}

function midnight(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x; }

// The date an event next actually happens. For weekly/monthly events this rolls
// the stored starts_at forward to the next occurrence (keeping time of day).
export function effectiveStart(ev) {
  const base = new Date(ev.starts_at);
  const rec = ev.recurrence || "none";
  const today = midnight(new Date());
  if (rec === "none" || base >= today) return base;
  const d = new Date(base);
  if (rec === "weekly") {
    const WEEK = 7 * 86400000;
    const steps = Math.ceil((today - d) / WEEK);
    return new Date(d.getTime() + steps * WEEK);
  }
  if (rec === "monthly") {
    while (d < today) d.setMonth(d.getMonth() + 1);
    return d;
  }
  return base;
}

export function timeOf(ev) {
  return ev.time_label || fmtTime(ev.starts_at);
}

function relDay(d) {
  const diff = Math.round((midnight(d) - midnight(new Date())) / 86400000);
  if (diff === 0) return "today";
  if (diff === 1) return "tomorrow";
  return fmtDate(d);
}

// compact label for the collapsed card and list rows
export function whenShort(ev) {
  const rec = ev.recurrence || "none";
  if (rec === "weekly") return DOW_PLURAL[new Date(ev.starts_at).getDay()];
  if (rec === "monthly") return "Monthly";
  return relDay(effectiveStart(ev));
}

// full label for the expanded card
export function whenLabel(ev) {
  const rec = ev.recurrence || "none";
  const t = timeOf(ev);
  if (rec === "none") return `${fmtDate(effectiveStart(ev))}, ${t}`;
  const rd = relDay(effectiveStart(ev));
  const next = rd === "today" || rd === "tomorrow" ? rd : `next ${rd}`;
  const head = rec === "weekly" ? DOW_PLURAL[new Date(ev.starts_at).getDay()] : "Monthly";
  return `${head}, ${t} · ${next}`;
}

export function recurTag(ev) {
  const rec = ev.recurrence || "none";
  return rec === "weekly" ? "weekly" : rec === "monthly" ? "monthly" : "";
}

export function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]
  ));
}

export function startOfTodayISO() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  // no milliseconds — the "." breaks PostgREST .or() filter parsing
  return d.toISOString().replace(/\.\d+Z$/, "Z");
}

// Half-hour + quarter-hour options for the time dropdown, 06:00 -> 03:45 next day
export function timeOptions() {
  const out = [];
  for (let i = 0; i < 96; i++) {
    const mins = (6 * 60 + i * 15) % (24 * 60);
    const h = String(Math.floor(mins / 60)).padStart(2, "0");
    const m = String(mins % 60).padStart(2, "0");
    out.push(`${h}:${m}`);
  }
  return out;
}

// ---- generated cover image (deterministic from the event id) ----------------
const PALETTES = {
  Music:     ["#3a1d29", "#7d3350", "#c9748a", "#f2c8ad"],
  Nightlife: ["#120e2b", "#3b1d6b", "#7b2f8f", "#cf5aa0"],
  Outdoors:  ["#0b2230", "#1f4d46", "#3f7d5f", "#a6c78d"],
  Sport:     ["#0a1e3a", "#1e4f8a", "#3f8fd0", "#f0a24b"],
  Arts:      ["#281812", "#6b3a2b", "#b0673f", "#e8cca9"],
  Markets:   ["#221c0d", "#5c4a1f", "#9c8332", "#e2cb78"],
};
function hashStr(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function rng(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function rgba(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}
const _cache = new Map();
export function generatedCover(seed, category) {
  const key = category + "|" + seed;
  if (_cache.has(key)) return _cache.get(key);
  const W = 760, H = 507;
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const x = c.getContext("2d");
  const pal = PALETTES[category] || PALETTES.Arts;
  const r = rng(hashStr(String(seed)));

  const g = x.createLinearGradient(0, 0, W * (0.25 + r() * 0.7), H);
  g.addColorStop(0, pal[0]); g.addColorStop(0.55, pal[1]); g.addColorStop(1, pal[2]);
  x.fillStyle = g; x.fillRect(0, 0, W, H);

  x.globalCompositeOperation = "lighter";
  for (let i = 0; i < 5; i++) {
    const bx = r() * W, by = r() * H, rad = 110 + r() * 230, col = pal[2 + (i % 2)];
    const rg = x.createRadialGradient(bx, by, 0, bx, by, rad);
    rg.addColorStop(0, rgba(col, 0.5)); rg.addColorStop(1, rgba(col, 0));
    x.fillStyle = rg; x.beginPath(); x.arc(bx, by, rad, 0, Math.PI * 2); x.fill();
  }
  x.globalCompositeOperation = "source-over";

  const vg = x.createRadialGradient(W / 2, H / 2, H * 0.28, W / 2, H / 2, H * 0.95);
  vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(5,9,18,0.5)");
  x.fillStyle = vg; x.fillRect(0, 0, W, H);

  const id = x.getImageData(0, 0, W, H), d = id.data;
  for (let p = 0; p < d.length; p += 4) {
    const n = (r() - 0.5) * 16;
    d[p] += n; d[p + 1] += n; d[p + 2] += n;
  }
  x.putImageData(id, 0, 0);

  const url = c.toDataURL("image/jpeg", 0.82);
  _cache.set(key, url);
  return url;
}
export function coverFor(ev) {
  return ev.image_url || generatedCover(ev.id, ev.category);
}

// ---- public feed card ------------------------------------------------------
const BKM = `<svg viewBox="0 0 24 24" aria-hidden="true">
  <path class="stroke" d="M6 4h12v16l-6-4-6 4z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>
  <path class="fill" d="M6 4h12v16l-6-4-6 4z" fill="currentColor"/></svg>`;

export function feedCardHTML(ev, { saved = false, open = false, index = 0 } = {}) {
  const ticket = ev.ticket_url
    ? `<a class="btn solid" href="${esc(ev.ticket_url)}" target="_blank" rel="noopener">Get tickets</a>`
    : `<span class="btn ghost">Free &mdash; just show up</span>`;
  const rt = recurTag(ev);
  const eyebrow = esc(ev.category) + (rt ? ` &middot; <span class="recur">${rt}</span>` : "");
  return `<article class="card${open ? " open" : ""}" data-id="${esc(ev.id)}" style="--i:${index}">
    <button class="card-head" type="button" aria-expanded="${open}">
      <img class="card-media" src="${coverFor(ev)}" alt="" loading="lazy">
      <span class="card-copy">
        <span class="cat">${eyebrow}</span>
        <span class="card-title">${esc(ev.title)}</span>
        <span class="card-sub">${esc(whenShort(ev))} &middot; ${esc(ev.venue)}</span>
      </span>
    </button>
    <button class="bkm${saved ? " on" : ""}" type="button" data-save
      aria-pressed="${saved}" aria-label="${saved ? "Remove from saved" : "Save this"}">${BKM}</button>
    <div class="card-body"><div><div class="card-body-inner">
      <p class="blurb">${esc(ev.description) || "No description yet."}</p>
      <dl class="facts">
        <div><dt>When</dt><dd>${esc(whenLabel(ev))}</dd></div>
        <div><dt>Cost</dt><dd>${esc(ev.price)}</dd></div>
        <div><dt>Where</dt><dd>${esc(ev.venue)}, ${esc(ev.area)}</dd></div>
      </dl>
      <div class="actions">
        ${ticket}
        <button class="btn line" type="button" data-save>${saved ? "Saved" : "Save"}</button>
      </div>
    </div></div></div>
  </article>`;
}
