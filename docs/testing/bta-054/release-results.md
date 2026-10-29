# BTA-054 release results

Runtime/source base: main `67a6a0e` after PR #37. Tested runtime commit:
`c292dce662b2673eacf794842dd5964f69f81e38`. Godot `4.6.3.stable.official.7d41c59c4`, GUT 9.6.1,
Compatibility renderer. Subsequent evidence-only commits change documentation,
logs and screenshots, not runtime source or assets. A rebuild stamps its own HEAD.

## Local results

- **705/705 GUT tests**, **42,960 assertions**, 545.394 s; no failures/errors/skips.
- Import, **295-script** parser validation and startup passed.
- New headless hazard matrix: **4/4 processes**.
- Final native keyboard/1280 normal and controller/800 Large Text/High Contrast/
  reduced presentation: **4/4 processes**, muted, zero torpedoes. Real inputs complete
  Chapter 1, deploy, tour the ecology, bypass an eruption safely, take bounded thermal
  damage deliberately, pause, escape, attract the squid, save/Continue, refit and resume.
  Permanent records stay unchanged. Final hull: 86.3333 / 88.9333 before Continue.
- Expanded/revised expedition checks, **8** story-choice and **4** original handoff
  processes passed. The full standard **12-process Sunlit chapter matrix passed**.
- **7/7 Python tooling tests** passed.
- Clean Linux x86_64 export and packaged standalone startup passed.
  `development_dirty` is **false**. Package: `below-the-abyss-playtest-linux-c292dce662b2.zip`.
  Exported binary SHA-256: `eb616cc3d35129fa9cfc52e801f0da78f9f38d73f6f37dbeee3a0c4dd3df02ac`.
  See [manifest](logs/manifest.json), [export](logs/linux-export.json),
  [standalone result](logs/standalone-result.txt), [engine log](logs/standalone-smoke.log).
  Packages remain local under `build/`; no binary release was published.

Commands, manual route, the 30 unedited native screenshots and acceptance mapping
are in [README.md](README.md). Raw final results are retained alongside this report.

## Timing diagnosis and limitations

Two earlier extended-controller attempts exceeded the original 300-second wall
budget. A diagnostic waypoint trace completed the same **1014.6167 simulation-second
route** in **257.011417 wall seconds**, including all optional studies/supply demos.
The final standard route completed in **261.837162 seconds**, followed by all other
standard routes. **No route timeout was relaxed.** The rock-trim clipping rectangle
is now built once per build instead of once per clipped edge. Runs were serial;
software-rendered shared-host throughput remains variable. The trace is retained
for diagnosis, not as a replacement for the passing standard matrix.

Native screenshots use actual Godot Compatibility/Xorg/Mesa llvmpipe output.
No human playtest, physical-controller, audible-mix or target-GPU/60 FPS approval
is claimed. Artwork/readability still require user review. This is environmental
content, not the complete Twilight narrative, glyph/sentinel choice or new quest.

Hosted CI and PR publication status will be recorded after the branch is pushed.
No automatic merge.
