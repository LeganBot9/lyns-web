// Shared "post an event" form — used by the organiser page and the admin page.
import { sb } from "./supabase.js";
import { CATS, timeOptions } from "./ui.js";

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function eventFormHTML({ submitLabel = "Submit for review" } = {}) {
  const cats = CATS.map((c) => `<option>${c}</option>`).join("");
  const times = timeOptions().map((t) => `<option value="${t}">${t}</option>`).join("");
  return `<form class="stack" id="eventForm" novalidate>
    <div class="field">
      <label for="ef-title">Event name</label>
      <input id="ef-title" name="title" required maxlength="70" placeholder="e.g. Rooftop Jazz Session">
    </div>

    <div class="field">
      <label for="ef-cat">Category</label>
      <select id="ef-cat" name="category">${cats}</select>
    </div>

    <div class="row2">
      <div class="field">
        <label for="ef-date">Date</label>
        <input id="ef-date" name="date" type="date" required min="${todayStr()}">
      </div>
      <div class="field">
        <label for="ef-time">Start time</label>
        <select id="ef-time" name="time" required>${times}</select>
      </div>
    </div>

    <div class="field">
      <label for="ef-timelabel">Time shown to people <span class="hint">(optional)</span></label>
      <input id="ef-timelabel" name="time_label" maxlength="40" placeholder="e.g. 22:00 – late">
    </div>

    <div class="field">
      <label for="ef-venue">Venue</label>
      <input id="ef-venue" name="venue" required maxlength="80" placeholder="The Vineyard">
    </div>

    <div class="field">
      <label>Price</label>
      <label class="check"><input type="checkbox" id="ef-free" name="free"> Free entry</label>
      <div class="rand">
        <span>R</span>
        <input id="ef-price" name="price" type="number" min="0" step="1" inputmode="numeric" placeholder="80">
      </div>
      <span class="hint">Whole rand only. Tick “Free entry” if there’s no charge.</span>
    </div>

    <div class="field">
      <label for="ef-desc">Short description</label>
      <textarea id="ef-desc" name="description" maxlength="240" placeholder="One or two lines. Keep it tight."></textarea>
    </div>

    <div class="field">
      <label for="ef-ticket">Ticket link <span class="hint">(optional)</span></label>
      <input id="ef-ticket" name="ticket_url" type="url" placeholder="https://">
    </div>

    <div class="field">
      <label for="ef-image">Cover photo <span class="hint">(optional — a cover is generated if you skip this)</span></label>
      <input id="ef-image" name="image" type="file" accept="image/png,image/jpeg,image/webp">
    </div>

    <button class="btn solid" type="submit" id="ef-submit" style="align-self:flex-start">${submitLabel}</button>
  </form>`;
}

export function bindEventForm(form) {
  const free = form.querySelector("#ef-free");
  const price = form.querySelector("#ef-price");
  const sync = () => { price.disabled = free.checked; if (free.checked) price.value = ""; };
  free.addEventListener("change", sync);
  sync();
}

export function readEventForm(form) {
  const f = form.elements;
  const title = f.title.value.trim();
  const venue = f.venue.value.trim();
  const date = f.date.value;
  const time = f.time.value;
  if (!title) return { error: "Add an event name." };
  if (!venue) return { error: "Add a venue." };
  if (!date) return { error: "Pick a date." };
  if (!time) return { error: "Pick a start time." };

  let price;
  if (f.free.checked) {
    price = "Free";
  } else {
    const raw = f.price.value.trim();
    const n = Number(raw);
    if (!raw || !Number.isFinite(n) || n < 0 || !Number.isInteger(n)) {
      return { error: "Price must be a whole number of rand, or tick “Free entry”." };
    }
    price = "R" + n;
  }

  const starts_at = new Date(`${date}T${time}`).toISOString();
  const ticket = f.ticket_url.value.trim();

  return {
    values: {
      title,
      category: f.category.value,
      starts_at,
      time_label: f.time_label.value.trim() || null,
      venue,
      price,
      description: f.description.value.trim() || null,
      ticket_url: ticket || null,
    },
    file: f.image.files[0] || null,
  };
}

export async function uploadCover(file, uid) {
  if (!file) return null;
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
  const path = `${uid}/${crypto.randomUUID()}.${ext}`;
  const { error } = await sb.storage.from("event-images").upload(path, file, {
    cacheControl: "3600",
    upsert: false,
  });
  if (error) { console.error(error); return null; }
  const { data } = sb.storage.from("event-images").getPublicUrl(path);
  return data.publicUrl;
}
