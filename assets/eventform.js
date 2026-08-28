// Shared "post an event" form — used by the organiser page and the admin page.
import { sb } from "./supabase.js";
import { CATS, timeOptions, RESIDENCES } from "./ui.js";

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
      <label for="ef-image">Cover photo <span class="hint">(shown on the front of the card)</span></label>
      <label class="photo-drop" for="ef-image" id="ef-photo-drop">
        <span class="photo-drop-inner">Tap to add a photo<br><small>JPG or PNG · a cover is generated if you skip this</small></span>
        <img id="ef-photo-preview" alt="" hidden>
      </label>
      <input id="ef-image" name="image" type="file" accept="image/png,image/jpeg,image/webp" class="visually-hidden">
      <button type="button" id="ef-photo-clear" class="link-btn" hidden>Remove photo</button>
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
      <label for="ef-repeat">Repeats</label>
      <select id="ef-repeat" name="recurrence">
        <option value="none">Just once</option>
        <option value="weekly">Every week</option>
        <option value="monthly">Every month</option>
      </select>
      <span class="hint">For a weekly run or quiz, set the date to the next time it happens — the app rolls it forward after that.</span>
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
      <label for="ef-res">Residence <span class="hint">(only if it's a res / koshuis event)</span></label>
      <input id="ef-res" name="residence" list="ef-res-list" maxlength="40" placeholder="Leave blank if not">
      <datalist id="ef-res-list">${RESIDENCES.map((r) => `<option value="${r}">`).join("")}</datalist>
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

    <button class="btn solid" type="submit" id="ef-submit" style="align-self:flex-start">${submitLabel}</button>
  </form>`;
}

export function bindEventForm(form) {
  const free = form.querySelector("#ef-free");
  const price = form.querySelector("#ef-price");
  const sync = () => { price.disabled = free.checked; if (free.checked) price.value = ""; };
  free.addEventListener("change", sync);
  sync();

  // cover photo preview
  const input = form.querySelector("#ef-image");
  const drop = form.querySelector("#ef-photo-drop");
  const preview = form.querySelector("#ef-photo-preview");
  const clearBtn = form.querySelector("#ef-photo-clear");
  const showPreview = (file) => {
    if (!file) {
      preview.hidden = true; preview.removeAttribute("src");
      drop.classList.remove("has-photo"); clearBtn.hidden = true;
      return;
    }
    preview.src = URL.createObjectURL(file);
    preview.hidden = false;
    drop.classList.add("has-photo");
    clearBtn.hidden = false;
  };
  input.addEventListener("change", () => showPreview(input.files[0] || null));
  clearBtn.addEventListener("click", () => { input.value = ""; showPreview(null); });
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

  const recurrence = ["none", "weekly", "monthly"].includes(f.recurrence.value) ? f.recurrence.value : "none";

  return {
    values: {
      title,
      category: f.category.value,
      starts_at,
      time_label: f.time_label.value.trim() || null,
      venue,
      residence: f.residence.value.trim() || null,
      price,
      description: f.description.value.trim() || null,
      ticket_url: ticket || null,
      recurrence,
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
