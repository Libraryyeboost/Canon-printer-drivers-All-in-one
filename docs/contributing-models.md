# Adding a new printer model

Fastest way to help the project: **add your printer**. It takes 60 seconds
and directly helps every other person who owns that model.

## The 60-second version

1. Open [`manifests/printers.json`](../manifests/printers.json).
2. Copy any existing entry and edit it:
   ```json
   {
     "model":      "TS7750a",
     "family":     "PIXMA",
     "aliases":    ["pixma ts7750a", "ts7750"],
     "supportUrl": "https://www.usa.canon.com/search?query=PIXMA+TS7750a",
     "driverUrl":  "",
     "sha256":     "",
     "verified":   false
   }
   ```
3. Open a PR. Done.

That's enough — the tool will open Canon's support page for the user to
click through. The next step (upgrading to `verified: true`) is optional
but doubly helpful.

## The gold-standard version (direct download URL)

If you want to unlock one-command install for your model:

1. Go to Canon's official download page for the model (the `supportUrl`).
2. Pick the latest recommended Windows driver.
3. Right-click the **Download** button → **Copy link address**.
4. Confirm the link is on `gdlp01.c-wss.com` or similar Canon domain.
5. Paste it into `driverUrl`.
6. (Optional but great) Run `Get-FileHash -Algorithm SHA256 <downloaded.exe>`
   and paste the upper-case hash into `sha256`.
7. Flip `verified` to `true`.

That's it — your PR just made one-command installs possible for that model.

## Why is `verified` a thing?

Because Canon refreshes download URLs. A URL that worked last month might
404 this month. We mark entries as `verified: true` only when a human has
confirmed the URL is current. The tool is conservative: on a 404 it falls
back to opening the `supportUrl` so the user can still finish the job.

## What not to do

- **Don't** paste a URL from a mirror, driver aggregator, or archive.
  The module's allow-list will reject it anyway.
- **Don't** include binary files in your PR. The repo stores URLs, not
  drivers.
- **Don't** edit two families in the same PR — keep it scoped, it's easier
  to review.

## Schema reference

Full JSON Schema: [`manifests/schema.json`](../manifests/schema.json).
If you use VS Code, the `$schema` key at the top of `printers.json` means
you get autocomplete and validation for free.
