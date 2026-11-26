# Recovery flow playtest: facilitator script

**Study status: NOT RUN. No human has played the recovery flow.** This script tests one thing: what
players see, understand and do when oxygen runs out or the hull fails, and what they do after Halcyon
recovers them. It is not a chapter-completion study. Use the general rules in
[facilitator_guide.md](facilitator_guide.md) for consent, anonymity, intervention and severity.

Recruit at least three people who have never played Below the Abyss. Five is better. About 30 minutes
each. Include at least one keyboard and one controller player. If someone agrees, have one person
play with sound muted, because the countdown must work without the alarm.

## What we want to learn

1. Do players notice the countdown (red border and the line `OXYGEN DEPLETED, LIFE SUPPORT 0:42`),
   and do they understand what it means and what they can do about it?
2. Is 60 seconds of life support enough to act on, or does it feel arbitrary?
3. Do players understand the recovery card: what happened, where they are now, and what they kept?
4. Does the card's input delay feel natural, or do players think their press was lost?
5. **Free refuel watch.** Recovery is a free full restock (designer decision, 2026-11-24, revisit only
   if a playtest shows it matters). Do players start running out of oxygen on purpose instead of
   returning to refill?

Do not tell participants any of these questions before or during play.

## How the flow works (facilitator reference, do not read aloud)

| Situation | What happens |
| --- | --- |
| Oxygen reaches 0 | A 60 s countdown on gameplay time. It stops while paused, on the map, in menus and on the dock. The vessel can still move. |
| During the countdown | Red border, the countdown line under the oxygen gauge, `CRITICAL` in the last 10 s. The existing oxygen alarm plays at 0 and at 10 s left, but the game's sound rules can skip it if another alarm is already playing. |
| Oxygen refilled in time | The countdown cancels and the border clears. In the caves the only refill is at Halcyon: Interact at the cave anchor (where the dive starts) offers **Return to Halcyon**, which refills at the dock. |
| Countdown expires, or the hull reaches 0 | Fade to black, then a card. `LIFE SUPPORT FAILED. Oxygen ran out...` or `HULL FAILURE. <cause>...`. Button: `Continue at Halcyon`. |
| On the card | Enter, Space or A is ignored for about one second, then a fresh press continues. Escape and B do nothing. |
| After the card | Twilight or the Drowned Caves: the Halcyon dock page. Sunlit: piloting at the Halcyon berth. Hull, battery, oxygen and torpedoes are full. Records, discoveries and choices are kept. Only position and an unfinished scan are lost. |

Where oxygen can realistically run out in one session: **the Drowned Caves**, where a full tank lasts
about 5.6 minutes (0.3 per second). In Sunlit it takes about 35 minutes of play and in Twilight about
56, so this script uses the caves. Wick's "oxygen is the clock" hint appears in the caves once oxygen
drops below 80%. It mentions the anchor refill and the countdown. Note whether the participant reads it.

The hull-failure card is tested in Twilight's optional basin, directly below the ascent tether. It is
1,120 m deep. Hull rank 2 is rated for it. Lower ranks take pressure damage after a short grace, and a
full hull lasts roughly half a minute there.

## Before the first participant: prepare one profile

Reaching the caves normally needs Sunlit, Twilight and the Twilight debrief (an hour or more). Play that
once yourself into a template profile, then give each participant a copy.

1. Launch the verified playtest package into an empty template folder, stored privately and outside
   the repository:

   ```sh
   XDG_DATA_HOME="$PWD/recovery-template/data" XDG_CONFIG_HOME="$PWD/recovery-template/config" XDG_CACHE_HOME="$PWD/recovery-template/cache" ./below-the-abyss.x86_64
   ```

2. Play Sunlit and Twilight and claim the Twilight debrief at the Halcyon dock. Do not enter the caves.
3. **Do not buy hull rank 2 or higher** in Research technology. Part C needs the basin to damage the hull.
4. Write down your story choices: the light bloom (collect or observe) and the sentinel (release,
   capture or lost). They carry into every participant's run. A released sentinel lights a path in
   the caves, which changes how long the caves take. Keep the same template for everyone.
5. Make sure the last checkpoint is at the dock: interact with the dock, then quit with the window close
   button or Playtest / local reports → Finish session and quit game.
6. Check the template once: relaunch it on a throwaway copy and confirm that Continue lands at the dock
   and that the dock offers **Descend to the Drowned Caves**.

Each participant gets a fresh copy, so recoveries and choices never leak between people:

```sh
cp -a recovery-template P01
XDG_DATA_HOME="$PWD/P01/data" XDG_CONFIG_HOME="$PWD/P01/config" XDG_CACHE_HOME="$PWD/P01/cache" ./below-the-abyss.x86_64
```

On Windows, copy the `Below the Abyss` folder under `%APPDATA%\Godot\app_userdata\` instead, and
restore it before each participant. This path has not been verified on a real Windows machine.

## Setup with the participant (about 3 minutes)

1. Consent for observation. Then offer optional local recording (Playtest / local reports). Recording
   starts OFF. Never turn it on for them.
2. Let them change accessibility settings (Reduced flashing, High contrast, text size) or mute audio.
   Record what they chose. Do not suggest settings.
3. Show the controls table in START_HERE.md. Do not mention oxygen, the countdown or recovery.
4. Read this briefing, and nothing more:

   > You are continuing an expedition. From the Halcyon dock you can descend into a flooded cave.
   > Explore it however you like and think aloud: say what you notice and what you expect.
   > You can pause, stop, or ask for technical help at any time.

5. Have them choose Continue, then Descend to the Drowned Caves. Start the stopwatch at the descent.

## Part A: first dive (open play, up to 12 minutes)

Do not warn them about oxygen. Do not prompt them to return. Let it run out if that happens. Returning to
Halcyon through the cave anchor in time, which cancels the countdown, is also a valid outcome. Note it
and let them continue.

Write down, with stopwatch times:

| Moment | What to record |
| --- | --- |
| Oxygen hint | Did they read Wick's oxygen card or dismiss it unread? |
| Oxygen low (gauge shows LOW) | Did they comment, glance at the gauge, or change course? |
| Countdown starts | Time from the countdown starting to the first visible reaction: a comment, turning back, pausing. Their words. |
| During the countdown | Did they head for the anchor? Did they pause, and did they notice the countdown stop? Did they read the time aloud? |
| Card appears | Did they read it? Did they press before it accepted input, then look confused ("did it work?")? How long until they continued? |
| After the card | Do they know where they are? Do they know their supplies are full? Do they think they lost progress? |

If they reach the far chamber and come back with oxygen to spare, that is a valid result: no run-out.
Record it and move to Part B anyway.

At the end of Part A, ask only: **"What just happened?"** Write down the answer word for word.

## Part B: second dive (open play, up to 8 minutes)

Say only:

> You can go back down if you want, or do anything else you like.

This is the free refuel watch. Record whether they:

- return to Halcyon through the cave anchor before running out,
- let oxygen run out on purpose (listen for "I'll just let it run out", "it refills anyway"),
- run out by accident, or
- do not go back down at all.

Do not hint at either strategy. If they ask whether running out is bad, answer: "What do you think?"

## Part C: hull failure (directed, about 4 minutes, optional)

This is a directed task, so it measures the card, not discovery. From the Halcyon dock, have them choose
**Resume Twilight Shelf**. Then say:

> Go straight down from where you start, into the deep basin, and stay at the bottom until something
> happens.

Record: did they read the pressure warning? Did they understand that the hull failed rather than the
oxygen? Did the `HULL FAILURE` card make clear what happened? If their hull rank is 2 or higher (check
Research technology), nothing will happen. Record that and skip Part C.

## Questions afterwards (about 5 minutes)

Ask in this order. Do not explain the mechanics until they have answered all of them.

1. "When did you first notice that something was wrong with the air? What told you?"
2. "What did the red border and the text at the top left mean to you?"
3. "When the countdown was running, was there anything you could have done?"
4. "After the dark screen and the message: where were you, and what did you still have?"
5. "Did you lose anything? Was that fair, too harsh, or did it not matter?"
6. "On your second dive, how did you decide when to come back?"
7. "Was the border comfortable to look at? Did anything flash too much?"
8. "Was there a moment you pressed a button and nothing seemed to happen?"
9. If Part C ran: "What happened in the basin, and how was it different from running out of air?"

Then hand over FEEDBACK.md as usual. If they chose recording, ask whether they want to share the report.
A shared report shows `oxygen_low` and `oxygen_depleted` as resource warnings and one `failure` event per
recovery (`life_support_expired` or `hull_destroyed`). Do not infer intent from the report alone.

## Per-participant worksheet

Anonymous code: ____  Build ID: ____  Template choices (bloom / sentinel): ____
Device: keyboard / controller  Muted: yes / no  Reduced flashing: yes / no  High contrast: yes / no
Recording chosen by participant: yes / no  Assistance given (time and reason): ____

| Part | Ran out? (yes / refilled in time / no) | Countdown start to first reaction (s) | Headed for anchor? | Pressed early on card? | Understood where they were after? | Words used |
| --- | --- | --- | --- | --- | --- | --- |
| A | | | | | | |
| B | | | | | | |
| C (hull) | n/a | n/a | n/a | | | |

Part B refuel behaviour: refilled at anchor / ran out on purpose / ran out by accident / did not dive
Verbatim answer to "What just happened?": ____

## Reading the results (after all participants)

Report every participant, including ones who never ran out. These are signals for the designer, not
pass marks, and a few people cannot settle a tuning question.

- **Countdown readable:** most participants reacted to the countdown before it expired, and could say
  what it meant. If several only understood it after the card, the warning needs work, not the timer.
- **60 seconds:** look at what they did with it. If participants who headed for the anchor ran out on
  the way, the grace or the cave scale is the issue. If nobody tried, it is the explanation.
- **Card understood:** participants could say they were at Halcyon with full supplies and nothing lost.
  If they believed they lost progress, the card text needs revising.
- **Input delay:** repeated early presses followed by confusion mean the delay needs a visible cue.
- **Free refuel:** if two or more participants ran out on purpose to refuel, bring it back to the
  designer. That is the playtest evidence the 2026-11-24 decision asked for. Do not propose a cost
  yourself.

Bring the worksheets and verbatim answers to the designer before opening any follow-up issue.
