import { sb } from "./supabase.js";
import { esc, coverFor, whenLabel, whenShort, recurTag } from "./ui.js";
import { eventFormHTML, bindEventForm, readEventForm, uploadCover } from "./eventform.js";

const view = document.getElementById("view");
const nav = document.getElementById("adminNav");
const toast = document.getElementById("toast");
let toastT;
function flash(m) {
  toast.textContent = m; toast.classList.add("show");
  clearTimeout(toastT); toastT = setTimeout(() => toast.classList.remove("show"), 2400);
}

const REDIRECT = window.location.origin + "/admin";
const state = { section: "queue", user: null };

async function currentUser() {
  const { data } = await sb.auth.getSession();
  return data.session?.user || null;
}

// ---------- auth screens ----------
function screenLogin() {
  nav.hidden = true;
  view.innerHTML = `
    <div class="center-wrap">
      <h1>LYNS admin</h1>
      <p>Sign in with your LYNS email. This area only works for accounts on the admin list.</p>
      <form id="loginForm">
        <div class="field"><label for="email">Email</label>
          <input id="email" type="email" required placeholder="you@lyns.co.za"></div>
        <button class="btn solid block" type="submit">Email me a sign-in link</button>
      </form>
    </div>`;
  document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = e.target.email.value.trim();
    if (!email) return;
    const btn = e.target.querySelector("button");
    btn.disabled = true; btn.textContent = "Sending…";
    const { error } = await sb.auth.signInWithOtp({ email, options: { emailRedirectTo: REDIRECT } });
    if (error) { flash(error.message); btn.disabled = false; btn.textContent = "Email me a sign-in link"; return; }
    view.innerHTML = `<div class="center-wrap"><h1>Check your email</h1>
      <p>Sign-in link sent to <strong>${esc(email)}</strong>. Open it on this device.</p></div>`;
  });
}

function screenNoAccess(user) {
  nav.hidden = true;
  view.innerHTML = `
    <div class="center-wrap">
      <h1>No access</h1>
      <p>You’re signed in as <strong>${esc(user.email)}</strong>, but this account isn’t on the LYNS admin list,
         so there’s nothing to see here.</p>
      <p class="muted-row"><button id="signout">Sign out</button></p>
    </div>`;
  document.getElementById("signout").addEventListener("click", signOut);
}

// ---------- admin sections ----------
function shell(inner) {
  return `<div class="view-head">
      <h1>${state.section === "queue" ? "Review queue" : state.section === "live" ? "Live events" : "Add an event"}</h1>
      <p>${state.section === "queue"
        ? "Nothing is public until you approve it."
        : state.section === "live"
        ? "Everything currently showing in the app."
        : "Posts straight to the app, no review."}</p>
      <button class="back" id="refresh" type="button">↻ Refresh</button>
    </div>${inner}`;
}

async function renderQueue() {
  view.innerHTML = shell(`<div id="q"><p class="q-plain" style="padding:14px 22px">Loading…</p></div>`);
  bindShell();
  const box = document.getElementById("q");

  const [orgRes, evRes] = await Promise.all([
    sb.from("organisers").select("*").order("created_at", { ascending: true }),
    sb.from("events").select("*").eq("status", "pending").order("created_at", { ascending: true }),
  ]);
  const allOrgs = orgRes.data || [];
  const orgs = allOrgs.filter((o) => o.status !== "approved");   // pending + suspended need action
  const liveOrgs = allOrgs.filter((o) => o.status === "approved");
  const evs = evRes.data || [];

  // organiser names for the event rows
  const ids = [...new Set(evs.map((e) => e.organiser_id))];
  let names = {};
  if (ids.length) {
    const { data } = await sb.from("organisers").select("id,name").in("id", ids);
    (data || []).forEach((o) => { names[o.id] = o.name; });
  }

  let html = `<div class="subhead">Organisers to action (${orgs.length})</div><div class="qlist">`;
  html += orgs.length ? orgs.map(orgRow).join("") : `<p class="q-plain">Nothing to action.</p>`;
  html += `</div>`;

  html += `<div class="subhead">Events waiting (${evs.length})</div><div class="qlist">`;
  html += evs.length ? evs.map((e) => eventRow(e, names[e.organiser_id] || "LYNS (direct)")).join("")
                     : `<p class="q-plain">No events to review.</p>`;
  html += `</div>`;

  html += `<div class="subhead">Approved organisers (${liveOrgs.length})</div><div class="qlist">`;
  html += liveOrgs.length ? liveOrgs.map(orgRow).join("") : `<p class="q-plain">None yet.</p>`;
  html += `</div>`;
  box.innerHTML = html;
}

function orgRow(o) {
  const tag = o.status === "approved" ? ` &middot; <span class="q-live">approved</span>`
            : o.status === "suspended" ? ` &middot; <span class="tag-bad">paused</span>`
            : ` &middot; <span class="tag-pending">pending</span>`;
  const actions = o.status === "approved"
    ? `<button class="btn line mini" data-act="org-suspend">Pause</button>`
    : o.status === "suspended"
    ? `<button class="btn solid mini" data-act="org-approve">Reinstate</button>`
    : `<button class="btn solid mini" data-act="org-approve">Approve</button>
       <button class="btn danger mini" data-act="org-decline">Decline</button>`;
  return `<div class="qitem" data-org="${esc(o.id)}">
    <img src="${o.logo_url || coverFor({ id: o.id, category: "Arts" })}" alt="">
    <div>
      <div class="q-cat">Organiser${tag}${o.logo_url ? "" : " &middot; no photo"}</div>
      <div class="q-title">${esc(o.name)}</div>
      <div class="q-meta">${esc(o.email || "")}${o.phone ? " &middot; " + esc(o.phone) : ""}${o.instagram ? " &middot; " + esc(o.instagram) : ""}</div>
      ${o.about ? `<div class="q-meta" style="margin-top:4px">${esc(o.about)}</div>` : ""}
    </div>
    <div class="q-actions">${actions}</div>
  </div>`;
}

function eventRow(ev, orgName) {
  return `<div class="qitem" data-ev="${esc(ev.id)}">
    <img src="${coverFor(ev)}" alt="">
    <div>
      <div class="q-cat">${esc(ev.category)} &middot; ${esc(orgName)}</div>
      <div class="q-title">${esc(ev.title)}</div>
      <div class="q-meta">${esc(whenLabel(ev))} &middot; ${esc(ev.venue)} &middot; ${esc(ev.price)}</div>
      ${ev.description ? `<div class="q-meta" style="margin-top:4px">${esc(ev.description)}</div>` : ""}
      ${ev.ticket_url ? `<div class="q-meta" style="margin-top:4px"><a href="${esc(ev.ticket_url)}" target="_blank" rel="noopener">${esc(ev.ticket_url)}</a></div>` : ""}
    </div>
    <div class="q-actions">
      <button class="btn solid mini" data-act="ev-approve">Approve</button>
      <button class="btn danger mini" data-act="ev-decline">Decline</button>
    </div>
  </div>`;
}

async function renderLive() {
  view.innerHTML = shell(`<div id="q"><p class="q-plain" style="padding:14px 22px">Loading…</p></div>`);
  bindShell();
  const { data, error } = await sb.from("events").select("*")
    .eq("status", "approved").order("starts_at", { ascending: true });
  const box = document.getElementById("q");
  if (error) { box.innerHTML = `<p class="q-plain" style="padding:14px 22px">${esc(error.message)}</p>`; return; }
  if (!data.length) { box.innerHTML = `<p class="q-plain" style="padding:14px 22px">Nothing live right now.</p>`; return; }
  box.innerHTML = `<div class="qlist">${data.map((ev) => `
    <div class="qitem" data-ev="${esc(ev.id)}">
      <img src="${coverFor(ev)}" alt="">
      <div>
        <div class="q-cat">${esc(ev.category)}${recurTag(ev) ? " &middot; " + recurTag(ev) : ""} <span class="q-live">live</span></div>
        <div class="q-title">${esc(ev.title)}</div>
        <div class="q-meta">${esc(whenShort(ev))} &middot; ${esc(ev.venue)}</div>
      </div>
      <div class="q-actions"><button class="btn line mini" data-act="ev-archive">Take down</button></div>
    </div>`).join("")}</div>`;
}

function renderAdd() {
  view.innerHTML = shell(`<div id="formHost"></div>`);
  bindShell();
  const host = document.getElementById("formHost");
  host.innerHTML = eventFormHTML({ submitLabel: "Publish now" });
  const form = host.querySelector("#eventForm");
  bindEventForm(form);
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const parsed = readEventForm(form);
    if (parsed.error) { flash(parsed.error); return; }
    const btn = form.querySelector("#ef-submit");
    btn.disabled = true; btn.textContent = "Publishing…";
    let image_url = null;
    if (parsed.file) image_url = await uploadCover(parsed.file, state.user.id);
    const { error } = await sb.from("events").insert({
      organiser_id: state.user.id,
      status: "approved",
      reviewed_at: new Date().toISOString(),
      reviewed_by: state.user.id,
      image_url,
      ...parsed.values,
    });
    btn.disabled = false; btn.textContent = "Publish now";
    if (error) { flash(error.message); return; }
    form.reset(); bindEventForm(form);
    flash("Published to the app");
  });
}

function bindShell() {
  document.getElementById("refresh")?.addEventListener("click", renderSection);
}

function renderSection() {
  nav.hidden = false;
  nav.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.section === state.section));
  if (state.section === "queue") renderQueue();
  else if (state.section === "live") renderLive();
  else renderAdd();
}

// ---------- actions ----------
view.addEventListener("click", async (e) => {
  const b = e.target.closest("[data-act]");
  if (!b) return;
  const act = b.dataset.act;
  const row = b.closest("[data-ev],[data-org]");
  b.disabled = true;
  try {
    if (act === "org-approve" || act === "org-decline" || act === "org-suspend") {
      const id = row.dataset.org;
      const status = act === "org-approve" ? "approved" : "suspended";
      const { error } = await sb.from("organisers").update({ status }).eq("id", id);
      if (error) throw error;
      flash(act === "org-approve" ? "Organiser approved" : act === "org-suspend" ? "Organiser paused" : "Organiser declined");
    } else {
      const id = row.dataset.ev;
      const map = { "ev-approve": "approved", "ev-decline": "declined", "ev-archive": "archived" };
      const status = map[act];
      const patch = { status };
      if (act === "ev-approve") { patch.reviewed_at = new Date().toISOString(); patch.reviewed_by = state.user.id; }
      const { error } = await sb.from("events").update(patch).eq("id", id);
      if (error) throw error;
      flash(act === "ev-approve" ? "Approved — it’s live" : act === "ev-decline" ? "Declined" : "Taken down");
    }
    row.style.opacity = "0.35";
    setTimeout(renderSection, 350);
  } catch (err) {
    flash(err.message || "Something went wrong");
    b.disabled = false;
  }
});

nav.querySelectorAll(".tab").forEach((t) =>
  t.addEventListener("click", () => { state.section = t.dataset.section; renderSection(); }));

async function signOut() { await sb.auth.signOut(); route(); }

// ---------- routing ----------
async function route() {
  const user = await currentUser();
  state.user = user;
  if (!user) { screenLogin(); return; }
  const { data: isAdmin, error } = await sb.rpc("is_admin");
  if (error) { flash(error.message); }
  if (!isAdmin) { screenNoAccess(user); return; }
  renderSection();
}

sb.auth.onAuthStateChange((event) => {
  if (event === "SIGNED_IN" || event === "SIGNED_OUT") route();
});
route();
