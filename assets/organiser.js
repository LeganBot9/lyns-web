import { sb } from "./supabase.js";
import { esc, coverFor, whenShort, recurTag } from "./ui.js";
import { eventFormHTML, bindEventForm, readEventForm, uploadCover } from "./eventform.js";
import { photoField, bindPhotoField, uploadImage } from "./photo.js";

const view = document.getElementById("view");
const toast = document.getElementById("toast");
let toastT;
function flash(m) {
  toast.textContent = m; toast.classList.add("show");
  clearTimeout(toastT); toastT = setTimeout(() => toast.classList.remove("show"), 2600);
}

const REDIRECT = window.location.origin + "/organiser";

async function currentUser() {
  const { data } = await sb.auth.getSession();
  return data.session?.user || null;
}

// ---------- screens ----------
function screenLogin() {
  view.innerHTML = `
    <div class="center-wrap">
      <h1>Post your event on LYNS</h1>
      <p>LYNS is where students around town look for something to do. Listing is free.
         Every event is checked by us before it appears — it keeps the feed clean and worth opening.</p>
      <form id="loginForm">
        <div class="field">
          <label for="email">Your email</label>
          <input id="email" type="email" required placeholder="you@venue.co.za">
        </div>
        <button class="btn solid block" type="submit">Email me a sign-in link</button>
      </form>
      <p class="muted-row">Accounts are for organisers and venues only. There is no sign-up for people using the app.</p>
    </div>`;
  document.getElementById("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = e.target.email.value.trim();
    if (!email) return;
    const btn = e.target.querySelector("button");
    btn.disabled = true; btn.textContent = "Sending…";
    const { error } = await sb.auth.signInWithOtp({ email, options: { emailRedirectTo: REDIRECT } });
    if (error) { flash(error.message); btn.disabled = false; btn.textContent = "Email me a sign-in link"; return; }
    view.innerHTML = `<div class="center-wrap">
      <h1>Check your email</h1>
      <p>We sent a sign-in link to <strong>${esc(email)}</strong>. Open it on this device to continue.</p>
    </div>`;
  });
}

function screenProfile(user) {
  view.innerHTML = `
    <div class="view-head"><h1>Tell us who you are</h1>
      <p>One-time details so we can verify you. Signed in as ${esc(user.email)}.</p></div>
    <form class="stack" id="profileForm" novalidate>
      <div class="field"><label for="p-name">Name or venue</label>
        <input id="p-name" name="name" required maxlength="80" placeholder="Bohemia / Jane Smith"></div>
      ${photoField({ id: "logo", label: "Your photo or logo", hint: "(helps us verify you)" })}
      <div class="field"><label for="p-phone">Phone</label>
        <input id="p-phone" name="phone" type="tel" placeholder="072 000 0000"></div>
      <div class="field"><label for="p-ig">Instagram <span class="hint">(helps us verify you fast)</span></label>
        <input id="p-ig" name="instagram" placeholder="@yourvenue"></div>
      <div class="field"><label for="p-about">What kind of events do you run?</label>
        <textarea id="p-about" name="about" maxlength="240" placeholder="Weekly club nights at Bohemia."></textarea></div>
      <button class="btn solid" type="submit" style="align-self:flex-start">Submit for verification</button>
    </form>
    <p class="muted-row" style="padding:0 22px 40px"><button id="signout">Sign out</button></p>`;
  document.getElementById("signout").addEventListener("click", signOut);
  const logoField = bindPhotoField(view, "logo");
  document.getElementById("profileForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const f = e.target.elements;
    if (!f.name.value.trim()) return;
    const btn = e.target.querySelector("button[type=submit]");
    btn.disabled = true; btn.textContent = "Submitting…";
    let logo_url = null;
    if (logoField.file()) logo_url = await uploadImage(sb, "event-images", logoField.file(), user.id, "logo-");
    const { error } = await sb.from("organisers").insert({
      id: user.id,
      name: f.name.value.trim(),
      email: user.email,
      phone: f.phone.value.trim() || null,
      instagram: f.instagram.value.trim() || null,
      about: f.about.value.trim() || null,
      logo_url,
    });
    if (error) { flash(error.message); btn.disabled = false; btn.textContent = "Submit for verification"; return; }
    route();
  });
}

function screenPending() {
  view.innerHTML = `
    <div class="center-wrap">
      <h1>Thanks — you’re in the queue</h1>
      <p>We’re checking your details. You’ll get an email when your account is approved,
         and then you can post events. This usually takes a day or less.</p>
      <p class="muted-row"><button id="signout">Sign out</button></p>
    </div>`;
  document.getElementById("signout").addEventListener("click", signOut);
}

function screenSuspended() {
  view.innerHTML = `
    <div class="center-wrap">
      <h1>Account paused</h1>
      <p>Your organiser account is on hold. Reach out to LYNS on Instagram and we’ll sort it out.</p>
      <p class="muted-row"><button id="signout">Sign out</button></p>
    </div>`;
  document.getElementById("signout").addEventListener("click", signOut);
}

const PILL = (s) => `<span class="status-pill ${esc(s)}">${s === "approved" ? "live" : esc(s)}</span>`;

async function screenApproved(user) {
  view.innerHTML = `
    <div class="view-head"><h1>Post an event</h1>
      <p>It goes into review and appears in the app once we approve it.</p></div>
    <div id="formHost"></div>
    <div class="subhead">Your events</div>
    <div id="mine" class="qlist"><p class="q-plain">Loading…</p></div>
    <p class="muted-row" style="padding:0 22px 40px">
      Signed in as ${esc(user.email)} &nbsp;·&nbsp; <button id="signout">Sign out</button></p>`;
  document.getElementById("signout").addEventListener("click", signOut);

  const host = document.getElementById("formHost");
  host.innerHTML = eventFormHTML({ submitLabel: "Submit for review" });
  const form = host.querySelector("#eventForm");
  bindEventForm(form);

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const parsed = readEventForm(form);
    if (parsed.error) { flash(parsed.error); return; }
    const btn = form.querySelector("#ef-submit");
    btn.disabled = true; btn.textContent = "Submitting…";
    let image_url = null;
    if (parsed.file) image_url = await uploadCover(parsed.file, user.id);
    const { error } = await sb.from("events").insert({
      organiser_id: user.id, status: "pending", image_url, ...parsed.values,
    });
    btn.disabled = false; btn.textContent = "Submit for review";
    if (error) { flash(error.message); return; }
    form.reset(); bindEventForm(form);
    flash("Submitted for review");
    loadMine(user);
  });

  loadMine(user);
}

async function loadMine(user) {
  const box = document.getElementById("mine");
  const { data, error } = await sb.from("events").select("*")
    .eq("organiser_id", user.id).order("created_at", { ascending: false });
  if (error) { box.innerHTML = `<p class="q-plain">${esc(error.message)}</p>`; return; }
  if (!data.length) { box.innerHTML = `<p class="q-plain">Nothing yet. Your first event will show here.</p>`; return; }
  box.innerHTML = data.map((ev) => `
    <div class="qitem">
      <img src="${coverFor(ev)}" alt="">
      <div>
        <div class="q-cat">${esc(ev.category)}${recurTag(ev) ? " &middot; " + recurTag(ev) : ""} &nbsp; ${PILL(ev.status)}</div>
        <div class="q-title">${esc(ev.title)}</div>
        <div class="q-meta">${esc(whenShort(ev))} &middot; ${esc(ev.venue)} &middot; ${esc(ev.price)}</div>
      </div>
    </div>`).join("");
}

async function signOut() { await sb.auth.signOut(); route(); }

// ---------- routing ----------
async function route() {
  const user = await currentUser();
  if (!user) { screenLogin(); return; }
  const { data: prof, error } = await sb.from("organisers").select("*").eq("id", user.id).maybeSingle();
  if (error) { flash(error.message); }
  if (!prof) { screenProfile(user); return; }
  if (prof.status === "pending") { screenPending(); return; }
  if (prof.status === "suspended") { screenSuspended(); return; }
  screenApproved(user);
}

sb.auth.onAuthStateChange((event) => {
  if (event === "SIGNED_IN" || event === "SIGNED_OUT") route();
});
route();
