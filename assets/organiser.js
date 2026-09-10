import { sb } from "./supabase.js";
import { esc, coverFor, whenShort, recurTag } from "./ui.js";
import { eventFormHTML, bindEventForm, readEventForm, uploadCover, clearEventDraft } from "./eventform.js";
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
const HEADS = {
  signin: ["Sign in", "Post your events to LYNS. Listing is free — every event is checked before it goes live."],
  signup: ["Create an organiser account", "For venues and event organisers. We verify you before you can post."],
  forgot: ["Reset your password", "We'll email you a link to set a new one."],
  magic:  ["Sign in with a link", "We'll email you a one-time sign-in link — no password needed."],
};

function authFormHTML(mode) {
  const pw = (auto) => `<div class="field"><label for="password">${mode === "signup" ? "Choose a password" : "Password"}</label>
      <input id="password" name="password" type="password" required minlength="8" autocomplete="${auto}">
      ${mode === "signup" ? '<span class="hint">At least 8 characters.</span>' : ""}</div>`;
  const email = `<div class="field"><label for="email">Email</label>
      <input id="email" name="email" type="email" required autocomplete="email" placeholder="you@venue.co.za"></div>`;
  if (mode === "signin") return `<form id="authForm" data-mode="signin">${email}${pw("current-password")}
      <button class="btn solid block" type="submit">Sign in</button></form>
      <p class="muted-row"><button type="button" class="linkbtn" data-go="forgot">Forgot password?</button></p>
      <p class="muted-row">New here? <button type="button" class="linkbtn" data-go="signup">Create an account</button></p>
      <p class="muted-row"><button type="button" class="linkbtn" data-go="magic">Email me a one-time link instead</button></p>`;
  if (mode === "signup") return `<form id="authForm" data-mode="signup">${email}${pw("new-password")}
      <button class="btn solid block" type="submit">Create account</button></form>
      <p class="muted-row">Already have one? <button type="button" class="linkbtn" data-go="signin">Sign in</button></p>`;
  if (mode === "forgot") return `<form id="authForm" data-mode="forgot">${email}
      <button class="btn solid block" type="submit">Email me a reset link</button></form>
      <p class="muted-row"><button type="button" class="linkbtn" data-go="signin">Back to sign in</button></p>`;
  return `<form id="authForm" data-mode="magic">${email}
      <button class="btn solid block" type="submit">Email me a sign-in link</button></form>
      <p class="muted-row"><button type="button" class="linkbtn" data-go="signin">Use a password instead</button></p>`;
}

function infoScreen(title, html) {
  view.innerHTML = `<div class="center-wrap"><h1>${title}</h1><p>${html}</p>
    <p class="muted-row">Email is from <strong>lynsStellie@gmail.com</strong> — check spam if it's slow.
    Still stuck? <a href="mailto:lynsStellie@gmail.com">lynsStellie@gmail.com</a></p></div>`;
}

function screenLogin(mode) {
  mode = mode || "signin";
  view.innerHTML = `<div class="center-wrap">
    <h1>${HEADS[mode][0]}</h1><p>${HEADS[mode][1]}</p>
    ${authFormHTML(mode)}
    <p class="muted-row">Accounts are for organisers only — people browsing the app don't need one.</p>
  </div>`;

  view.querySelectorAll("[data-go]").forEach((b) =>
    b.addEventListener("click", () => screenLogin(b.dataset.go)));

  document.getElementById("authForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const f = e.target;
    const email = f.email.value.trim();
    const password = f.password ? f.password.value : "";
    const btn = f.querySelector("button[type=submit]");
    const label = btn.textContent;
    btn.disabled = true; btn.textContent = "One sec…";
    try {
      if (f.dataset.mode === "signin") {
        const { error } = await sb.auth.signInWithPassword({ email, password });
        if (error) throw error;
        route();
      } else if (f.dataset.mode === "signup") {
        const { data, error } = await sb.auth.signUp({ email, password, options: { emailRedirectTo: REDIRECT } });
        if (error) throw error;
        if (data.session) route();
        else infoScreen("One more step", `We sent a confirmation link to <strong>${esc(email)}</strong>. Tap it, then come back and sign in.`);
      } else if (f.dataset.mode === "forgot") {
        const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: REDIRECT });
        if (error) throw error;
        infoScreen("Check your email", `We sent a reset link to <strong>${esc(email)}</strong>.`);
      } else {
        const { error } = await sb.auth.signInWithOtp({ email, options: { emailRedirectTo: REDIRECT } });
        if (error) throw error;
        infoScreen("Check your email", `One-time sign-in link sent to <strong>${esc(email)}</strong>. Open it on this device.`);
      }
    } catch (err) {
      flash(err.message || "That didn't work.");
      btn.disabled = false; btn.textContent = label;
    }
  });
}

function screenNewPassword() {
  view.innerHTML = `<div class="center-wrap">
    <h1>Set a new password</h1>
    <form id="pwForm">
      <div class="field"><label for="np">New password</label>
        <input id="np" type="password" required minlength="8" autocomplete="new-password"></div>
      <button class="btn solid block" type="submit">Save password</button>
    </form></div>`;
  document.getElementById("pwForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const btn = e.target.querySelector("button");
    btn.disabled = true; btn.textContent = "Saving…";
    const { error } = await sb.auth.updateUser({ password: document.getElementById("np").value });
    if (error) { flash(error.message); btn.disabled = false; btn.textContent = "Save password"; return; }
    flash("Password saved — you're signed in");
    route();
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
      <p>Your organiser account is on hold. Email <a href="mailto:lynsStellie@gmail.com">lynsStellie@gmail.com</a> and we’ll sort it out.</p>
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
    clearEventDraft();
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
// Supabase re-fires SIGNED_IN on token refresh / tab focus / returning from the
// iOS photo picker. Re-rendering then would wipe a half-filled event form, so
// only act on a real change of who's signed in.
let authedUid = null;
let routedOnce = false;

async function route() {
  const user = await currentUser();
  authedUid = user?.id || null;
  routedOnce = true;
  if (!user) { screenLogin(); return; }
  const { data: prof, error } = await sb.from("organisers").select("*").eq("id", user.id).maybeSingle();
  if (error) { flash(error.message); }
  if (!prof) { screenProfile(user); return; }
  if (prof.status === "pending") { screenPending(); return; }
  if (prof.status === "suspended") { screenSuspended(); return; }
  screenApproved(user);
}

sb.auth.onAuthStateChange((event, session) => {
  if (event === "PASSWORD_RECOVERY") { screenNewPassword(); return; }
  if (event === "SIGNED_OUT") { authedUid = null; route(); return; }
  if (event === "SIGNED_IN") {
    const uid = session?.user?.id || null;
    if (routedOnce && uid && uid === authedUid) return;
    route();
  }
});
route();
