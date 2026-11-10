# Market research review — 2026-11-10

Inputs (Gemini deep research, supplied by the designer; originals are not stored in the repo):
`Below_the_Abyss_Market_Research` (UX report, written for the earlier non-combat design),
`Below_the_Abyss_Steam_Research_Sources` (designer's checked sources, 2026-11-09), and
`Steam_Metroidvania_Market_Analysis` (two versions; the revised one is reviewed here).

**Verification status.** `partner.steamgames.com` and `steamdb.info` were not reachable from the
review session, so no figure below was checked against its primary source by the reviewer. Items
are marked **Supported**, **Plausible** or **Unverified**. Re-verify before any public claim.

## 1. What the evidence supports

| Finding | Status |
| --- | --- |
| Comparable 2D underwater / Metroidvania games sell at $14.99–$19.99 (Song of the Deep, Depths of Sanity, In Other Waters $14.99; Pronty $17.99) | Plausible (designer's SteamDB notes agree) |
| Steam requires disclosing shipped AI-made art, music and narrative; code and editor help is out of scope | Supported (matches the Valve text the designer quoted) |
| A human-authorship requirement blocks copyright for purely AI-made works (*Thaler v. Perlmutter*, D.C. Cir. 2025); *Allen v. Perlmutter* is a pending district-court case | Plausible; get legal advice; the March 2026 Supreme Court denial of review is Unverified |
| Small-team Metroidvanias are punished for clunky controls, repetitive or "boring" music, linear maps disguised as exploration, low enemy variety and hidden costs | Plausible (review sentiment, small sample) |
| Games finishable in under ~2 h see high refund rates | Plausible |

## 2. What changes our plan

1. **Plan for the low case.** The nearest comparable, *Depths of Sanity* (underwater Metroidvania
   with sonar, $14.99, 93 % positive), has 72 reviews. At the common 30–50 sales per review that is
   roughly 2,000–3,600 copies, about $30,000 after Steam's cut before discounts. Treat 100–500 reviews
   as the realistic range; 500–1,500 is upside, not a plan.
2. **Wishlist gate.** Cited visibility target: 7,000–10,000 pre-launch wishlists (Unverified, blog
   sources). Decide in advance what scope changes if a wishlist threshold is missed.
3. **Price.** Hold $14.99 (possibly up to $19.99) and decide later on content length and polish.
4. **Controls are the first market risk.** Add a control-feel check and a handling option; our
   water-like inertia must be playtested against this audience.
5. **Music must be dynamic**, not only sparse. This matches the designer's "bland" feedback.
6. **Non-linear routes and enemy variety** belong in the slice.
7. **AI use.** Keep: AI for code (exempt); AI for prototyping and concept; hand-finish the identity
   assets (Stalker design, key art, main music motifs); CC0 or licensed libraries for effects and
   ambience; specific, bounded store disclosure; keep originals, prompts, revision history and dated
   tool terms (see `docs/audio_audit.md` §6). The publisher "IP warranty" risk only applies if a
   publisher or investor is involved.

## 3. Known defects in the research (do not quote these)

- Table and text disagree on MF-01 Aerostrike reviews (116 vs 11).
- "Sold poorly / failed to find an audience" is asserted without support; several low counts are
  simply recent releases.
- "Water drag means players expect frictionless movement" is opinion, not data.
- AI-backlash evidence is three obscure games, one an AI experiment.
- Wishlist and refund benchmarks, the AI-share-of-releases figures and several legal claims come from
  blogs, forums and a university blog.
- The first (UX) report assumes a non-combat game and advises removing guidance; both conflict with
  the current direction (Fusion-style action, novices wanting dialogue). Its useful parts: make
  Resonance visible in the world, vary and soften threat telegraphs, silent-observer playtests.

## 4. Follow-up research (if commissioned)

Reconcile Store vs SteamDB review counts per title; add time-on-market and a spread of poor sellers;
add playtime and refund data for comparables; verify current Valve disclosure text and how
disclosures are displayed to players; verify the cited cases with counsel.
