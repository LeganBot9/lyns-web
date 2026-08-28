import { sb } from "./supabase.js";
import { CITY } from "./config.js";
import {
  CATS_WITH_ALL, feedCardHTML, esc, startOfTodayISO, effectiveStart,
  occursOn, fmtDate,
} from "./ui.js";

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

const view = document.getElementById("view");
const toast = document.getElementById("toast");
let toastT;
function flash(m) {
  toast.textContent = m; toast.classList.add("show");
  clearTimeout(toastT); toastT = setTimeout(() => toast.classList.remove("show"), 2400);
}

// saved events are stored whole, on this device only (no account)
function getSaved() {
  try { return JSON.parse(localStorage.getItem("lyns.saved")) || []; } catch { return []; }
}
function setSaved(a) {
  try { localStorage.setItem("lyns.saved", JSON.stringify(a)); } catch {}
}

const state = { tab: "discover", cat: "All", date: null, residence: null, open: null, events: [] };

const ICON_CAL = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4.5" width="18" height="16" rx="2"/><path d="M3 9h18M8 2.5v4M16 2.5v4"/></svg>`;
const ICON_SEARCH = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>`;
const ICON_BKM = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M6 4h12v16l-6-4-6 4z"/></svg>`;

function emptyHTML(icon, title, text) {
  return `<div class="empty"><div class="mark">${icon}</div><h2>${title}</h2><p>${text}</p></div>`;
}

function settle() {
  const feed = view.querySelector(".feed");
  if (feed) requestAnimationFrame(() => feed.classList.add("ready"));
  view.scrollTop = 0;
}

async function loadEvents() {
  // one-time events from today onward, plus every recurring event
  let { data, error } = await sb
    .from("events")
    .select("*")
    .eq("status", "approved")
    .or(`recurrence.neq.none,starts_at.gte.${startOfTodayISO()}`);
  if (error) {
    // recurrence column not migrated yet — fall back to plain upcoming
    ({ data, error } = await sb
      .from("events")
      .select("*")
      .eq("status", "approved")
      .gte("starts_at", startOfTodayISO()));
  }
  if (error) { console.error(error); return []; }
  return (data || []).sort((a, b) => effectiveStart(a) - effectiveStart(b));
}

function renderDiscover() {
  const savedIds = new Set(getSaved().map((e) => e.id));
  const onDate = state.date ? new Date(state.date + "T00:00:00") : null;
  const residences = [...new Set(state.events.map((e) => e.residence).filter(Boolean))].sort();
  if (state.residence && !residences.includes(state.residence)) state.residence = null;

  let list = state.events.filter((e) =>
    (state.cat === "All" || e.category === state.cat) &&
    (!state.residence || e.residence === state.residence) &&
    (!state.date || occursOn(e, state.date)));
  if (state.date) {
    list = list.slice().sort((a, b) =>
      (a.time_label || "").localeCompare(b.time_label || "") ||
      new Date(a.starts_at).toTimeString().localeCompare(new Date(b.starts_at).toTimeString()));
  }

  const chips = CATS_WITH_ALL.map((c) =>
    `<button class="chip" type="button" data-cat="${c}" aria-pressed="${state.cat === c}">${c}</button>`
  ).join("") +
    `<span class="chip chip-date${state.date ? " on" : ""}" id="dateChip" role="button" tabindex="0">
       ${ICON_CAL}<span class="cd-label">${state.date ? esc(fmtDate(onDate)) : "Day"}</span>
       ${state.date ? `<button type="button" id="dateClear" aria-label="Clear day">&times;</button>` : ""}
       <input type="date" id="datePick" min="${todayStr()}" value="${state.date || ""}" aria-label="Pick a day" tabindex="-1">
     </span>` +
    (residences.length
      ? `<select class="chip chip-select${state.residence ? " on" : ""}" id="resPick" aria-label="Residence">
           <option value="">Residence</option>
           ${residences.map((r) => `<option value="${esc(r)}"${state.residence === r ? " selected" : ""}>${esc(r)}</option>`).join("")}
         </select>`
      : "");

  const count = list.length;
  let sub;
  if (state.date || state.residence) {
    const where = state.residence ? ` at ${esc(state.residence)}` : "";
    const when = state.date ? ` on ${fmtDate(onDate)}` : "";
    sub = `${count} thing${count === 1 ? "" : "s"}${where}${when}`;
  } else {
    sub = `${state.events.length} thing${state.events.length === 1 ? "" : "s"} coming up around ${esc(CITY)}`;
  }

  view.innerHTML =
    `<section class="hero"><h1>What do you want to <em>do</em>?</h1><p>${sub}</p></section>
     <div class="chips">${chips}</div>` +
    (list.length
      ? `<div class="feed">${list.map((e, i) => feedCardHTML(e, { saved: savedIds.has(e.id), open: state.open === e.id, index: i, onDate })).join("")}</div>`
      : emptyHTML(ICON_SEARCH,
          (state.date || state.residence) ? "Nothing to show" : "Nothing here yet",
          (state.date || state.residence) ? "Try clearing a filter to see more of what's on." : "Try another category — new things are added through the week."));

  const dp = document.getElementById("datePick");
  const chipEl = document.getElementById("dateChip");
  if (dp) dp.addEventListener("change", () => { state.date = dp.value || null; state.open = null; renderDiscover(); });
  if (chipEl) {
    const openPicker = (e) => {
      if (e.target.closest("#dateClear")) return;
      try { dp.showPicker(); } catch { dp.focus(); }
    };
    chipEl.addEventListener("click", openPicker);
    chipEl.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); openPicker(e); } });
  }
  const dc = document.getElementById("dateClear");
  if (dc) dc.addEventListener("click", (e) => { e.stopPropagation(); state.date = null; state.open = null; renderDiscover(); });

  const rp = document.getElementById("resPick");
  if (rp) rp.addEventListener("change", () => { state.residence = rp.value || null; state.open = null; renderDiscover(); });

  settle();
}

function renderSaved() {
  const saved = getSaved();
  view.innerHTML =
    `<section class="view-head"><h1>Saved</h1><p>${saved.length} thing${saved.length === 1 ? "" : "s"} on this device</p></section>` +
    (saved.length
      ? `<div class="feed">${saved.map((e, i) => feedCardHTML(e, { saved: true, open: state.open === e.id, index: i })).join("")}</div>`
      : emptyHTML(ICON_BKM, "Nothing saved yet", "Tap the bookmark on anything you like the look of. Your list stays on this device — no account, no sign-up."));
  settle();
}

function render() {
  if (state.tab === "saved") renderSaved();
  else renderDiscover();
  document.querySelectorAll(".tabbar .tab").forEach((t) =>
    t.classList.toggle("active", t.dataset.tab === state.tab));
}

view.addEventListener("click", (e) => {
  const saveBtn = e.target.closest("[data-save]");
  if (saveBtn) {
    const card = saveBtn.closest(".card");
    const id = card?.dataset.id;
    if (!id) return;
    let saved = getSaved();
    if (saved.some((x) => x.id === id)) {
      saved = saved.filter((x) => x.id !== id);
      flash("Removed from saved");
    } else {
      const ev = state.events.find((x) => x.id === id) || getSaved().find((x) => x.id === id);
      if (ev) { saved.push(ev); flash("Saved to this device"); }
    }
    setSaved(saved);
    render();
    return;
  }
  const head = e.target.closest(".card-head");
  if (head) {
    const card = head.closest(".card");
    const id = card.dataset.id;
    state.open = state.open === id ? null : id;
    view.querySelectorAll(".card.open").forEach((el) => {
      if (el !== card) { el.classList.remove("open"); el.querySelector(".card-head").setAttribute("aria-expanded", "false"); }
    });
    card.classList.toggle("open", state.open === id);
    head.setAttribute("aria-expanded", String(state.open === id));
    return;
  }
  const chip = e.target.closest(".chip");
  if (chip && chip.dataset.cat) { state.cat = chip.dataset.cat; state.open = null; renderDiscover(); }
});

document.querySelectorAll(".tabbar .tab[data-tab]").forEach((t) =>
  t.addEventListener("click", () => { state.tab = t.dataset.tab; state.open = null; render(); }));

document.getElementById("loc").addEventListener("click", () => flash("More areas are coming soon"));

(async function init() {
  render(); // paint shell immediately
  state.events = await loadEvents();
  render();
})();
