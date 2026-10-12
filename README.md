# World Pulse

A handheld news atlas for CartridgeOS using reported GDELT locations and articles, with ISS position.

## Public app refresh

Requires **CartridgeOS 0.7.0 or newer**. The display uses the CartridgeOS app components at 720×720, larger type and flat graphite/paper panels. Controls remain usable while requests are pending; idle screens do not continuously animate.

This refresh is a development preview, pending live GDELT verification. It is not yet added to the signed Store. Preferences remain under the same app data keys.

World Pulse reports GDELT coverage, not a complete or independently verified view of world events. Sentiment is distinct from severity and remains unknown when not supplied. GEO, DOC and ISS sources have separate status and error states. Cached results remain visibly labelled after a failed refresh. GDELT availability and quotas may temporarily prevent fresh results; no made-up locations or headlines are inserted.

L1/R1 changes Atlas, News and Statistics. D-pad selects a location or story; A opens details; B returns; Y refreshes. The map is an overview rather than a navigation map.

Current provider check (2026-10-12): the documented GDELT GEO endpoint returned HTTP 404; DOC returned HTTP 429. ISS responded successfully. GDELT starts share a six-second gap, and a 429 applies a persisted ten-minute cooldown to both news sources. Cached and partial-source behavior is validated with deterministic fixtures; a live news atlas is not yet verified.
