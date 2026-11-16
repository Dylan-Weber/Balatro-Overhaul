# Steamodded in Balatro Overhaul

`assets/smods` holds Steamodded 26.1020.0~dev-a (https://github.com/Steamodded/smods, commit f8ed0f9ba1), licensed under the GNU General Public License v3.0 (see `assets/smods/LICENSE`). Every file in that folder is the same as upstream. Upstream's developer-only files (`lsp_def`, `tk_debug_window.py`, `.github`) are left out.

The Overhaul changes Steamodded when the game loads, the same way mods change Balatro: with patch files in `assets/overhaul/late/`. The ones named `smods_*_auto.toml` patch Steamodded's own files, and the other `*_auto.toml` files also cover the lines of Balatro that Steamodded patches. They run after every mod, so a mod that edits the same lines keeps its own version.

What the changes do:

- Run Steamodded inside the Overhaul's own mod loader (`assets/modloader`), on desktop and on phones.
- Fix crashes found while testing mods: card descriptions with a missing card, texture packs sharing an atlas key, missing shader settings, marquee text, mod versions that do not start with a number, and the load order of the splash screen and conf.lua modules.
- Decode mod images on worker threads while the main thread keeps the loading screen moving, and draw the Overhaul's loading screen while mods load.
- Fit Steamodded's menus to phone screens and touch (tab widths, deck and rank layouts, stencil size on high DPI screens).
- Guard profile data that can be missing on older or merged profiles (deck and Joker usage, meta file).
- Hook Overhaul features into Steamodded's versions of Balatro's code: the pack slots rule and the hand sort setting.
- Add French and Spanish texts for Steamodded's menus.
- Steamodded's thread and mobile patches are not used: the Overhaul stops its threads and sets up phones itself.

These changes keep the GPL v3.0 licence. Each one is in the Overhaul's git history (`git log -- assets/overhaul/late assets/smods`).
