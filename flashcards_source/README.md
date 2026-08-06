# Windows setup: poppler & libwebp

`build_flashcards.py` needs three command-line tools that don't come with
a TeX distribution or Python: `pdfinfo`, `pdftoppm` (both from
**poppler**) and `cwebp` (from **libwebp**). Install both, then check
they're on `PATH`.

## 1. Poppler (`pdfinfo`, `pdftoppm`)

1. Go to the [poppler-windows releases page](https://github.com/oschwartz10612/poppler-windows/releases)
   and download the newest `Release-XX.XX.X-X.zip`.
2. Extract it somewhere permanent, e.g. `C:\Tools\poppler`.
3. The executables are in the `Library\bin` subfolder, e.g.
   `C:\Tools\poppler\Library\bin`. Add that folder to your `PATH`
   (see step 3 below).

## 2. libwebp (`cwebp`)

1. Go to the [WebP downloads page](https://developers.google.com/speed/webp/download)
   and download the latest **Windows** precompiled archive, e.g.
   `libwebp-1.x.x-windows-x64.zip`.
2. Extract it somewhere permanent, e.g. `C:\Tools\libwebp`.
3. The executables are in the `bin` subfolder, e.g.
   `C:\Tools\libwebp\bin`. Add that folder to your `PATH` as well.

## 3. Add both folders to PATH

1. Press `Win`, search **"Edit the system environment variables"**, open it.
2. Click **Environment Variables...**
3. Under **User variables** (or **System variables**), select `Path` → **Edit...**
4. Click **New** and add:
   - `C:\Tools\poppler\Library\bin`
   - `C:\Tools\libwebp\bin`
5. Click OK on all dialogs, then **open a new terminal** (existing ones
   won't pick up the change).

## 4. Verify

In a fresh terminal (PowerShell or cmd):

```
pdfinfo -v
pdftoppm -v
cwebp -version
```

Each should print a version number, not "not recognized as an internal
or external command". If one fails, double-check the folder you added
to `PATH` actually contains that `.exe` directly (some archives nest an
extra subfolder — adjust the `PATH` entry to point at the folder
containing the `.exe` files themselves).
