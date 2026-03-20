# Vision — Pokemon Go Events Calendar

## Product Vision
Pokemon Go runs dozens of overlapping events — community days, spotlight hours, raid hours, seasonal events, research days — each with their own set of buffs, bonuses, and special spawns. Niantic announces these across blog posts, in-game news, and social media, but there's no single, clean view that answers the simplest question a player has: "What's active right now, and what should I care about today?"

This app puts that answer in your pocket. Open it up, see today's active buffs at a glance — 2x transfer candy, bonus catch XP, boosted spawns — and plan your play session accordingly. Flag the events you care about and get a push notification when they're about to end so you don't miss your window.

The end state is a tool that every Pokemon Go player checks before they head out. Not a social network, not a Pokedex, not a raid coordinator — just a dead-simple event calendar that respects your time and tells you exactly what you need to know.

## Guiding Principles
- **Simplicity over features.** The app answers one question well: "What's boosted today?" Resist the urge to bolt on raid finders, IV calculators, or friend lists.
- **Glanceable.** A player should get the information they need in under 5 seconds. If it takes longer, the UI has failed.
- **Offline-friendly.** Event data syncs to the device. No network connection required to check today's buffs.
- **Timezone-correct.** Pokemon Go events roll with local time — 2pm is 2pm wherever you are. The app must handle this correctly and never confuse users with UTC offsets.

## Target Users
Pokemon Go players of all levels who want a quick, reliable way to check what events and bonuses are active on any given day. Particularly useful for players who play in short sessions (lunch breaks, commutes, walks) and want to maximise their time by knowing what's boosted before they start.

## Roadmap Direction
- **Phase 1:** Core calendar view showing daily buffs and active events. Data synced from ScrapedDuck via .NET backend. Basic event flagging on-device.
- **Phase 2:** Push notifications for flagged events (event starting, event ending). FCM integration.
- **Phase 3:** Polish, performance, and app store submission (iOS App Store, Google Play).
- **Phase 4:** Evaluate user feedback. Consider features like weekly overview, event history, or widget support based on demand.

## Non-Goals
- This is not a Pokedex or Pokemon database
- This is not a raid coordinator or group finder
- This is not a social platform — no friends lists, no chat, no sharing
- This is not a replacement for LeekDuck or other comprehensive news sites — it's a focused tool for daily buff awareness
- No monetisation planned at this stage — no ads, no subscriptions, no in-app purchases
