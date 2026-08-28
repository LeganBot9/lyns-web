// Reusable "tap to add a photo" field with live preview.
export function photoField({ id = "photo", label = "Photo", hint = "" } = {}) {
  return `<div class="field">
    <label for="${id}">${label}${hint ? ` <span class="hint">${hint}</span>` : ""}</label>
    <label class="photo-drop" for="${id}" id="${id}-drop">
      <span class="photo-drop-inner">Tap to add a photo<br><small>JPG or PNG</small></span>
      <img id="${id}-preview" alt="" hidden>
    </label>
    <input id="${id}" name="${id}" type="file" accept="image/png,image/jpeg,image/webp" class="visually-hidden">
    <button type="button" id="${id}-clear" class="link-btn" hidden>Remove photo</button>
  </div>`;
}

export function bindPhotoField(root, id = "photo") {
  const input = root.querySelector(`#${id}`);
  const drop = root.querySelector(`#${id}-drop`);
  const preview = root.querySelector(`#${id}-preview`);
  const clearBtn = root.querySelector(`#${id}-clear`);
  if (!input) return { file: () => null };
  const show = (file) => {
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
  input.addEventListener("change", () => show(input.files[0] || null));
  clearBtn.addEventListener("click", () => { input.value = ""; show(null); });
  return { file: () => input.files[0] || null };
}

export async function uploadImage(sb, bucket, file, uid, prefix = "") {
  if (!file) return null;
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
  const path = `${uid}/${prefix}${crypto.randomUUID()}.${ext}`;
  const { error } = await sb.storage.from(bucket).upload(path, file, { cacheControl: "3600", upsert: false });
  if (error) { console.error(error); return null; }
  return sb.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}
