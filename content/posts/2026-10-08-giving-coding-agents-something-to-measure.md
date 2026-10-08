---
title: "Giving Coding Agents Something to Measure"
date: 2026-10-08T00:00:00Z
draft: false
tags: ["Robotics", "RoboCup", "AI Agents", "Performance", "Evaluation"]
summary: "What I changed in our RoboCup SSL control stack this summer so a coding agent could judge a change in minutes: 16x faster path planning, 11.5x smaller replays, and tools for finding stalled matches."
---

*By Isaac, First Order Robotics Team*

---

Strategy code is hard to improve when the only judge is watching matches. A change that looks better on one replay can be worse over a hundred games, and a human can't watch a hundred games. This post is about what I changed in our RoboCup Small Size League stack, Utama-Core, so that a coding agent could judge a change in minutes without me in the loop.

Between June and October the stack went from v1.11.11 to v2.0.3, and I shipped 435 commits. The headline change is the one I described in [Strategy = Tactics × Orchestration](/posts/2026-09-18-strategy-tactics-orchestration/): behaviour trees out, a tactic kernel in. This post covers the other half, the part that made the first half safe to do quickly.

Every figure below was measured by me from the repo at the commits named, except the ones marked "(commit message)", which I took from the original commit notes and did not re-run.

## Planning was spending its time on arithmetic

An agent that iterates on a strategy needs a match to finish in seconds, not minutes. So the first job was making the simulated match cheap.

I profiled a 30 second headless match. The biggest single cost was the geometry inside `FastPathPlanner`, the planner that routes each robot around the others. Its small helpers (distance from a point to a segment, and so on) were called 3.1 million times in one match (commit message), each doing two-number arithmetic through numpy. Numpy's per-call overhead was bigger than the math itself.

I measured planner time per call on one fixed 20 second match (`press_and_pass` vs `low_block`), with a git worktree at each commit, five repeats, taking the median. Each row is the repo at that commit, and "what changed" covers the work since the previous row.

| Commit | What changed since the previous row | Planner time per call |
|---|---|---|
| `3bcef0c` (Aug 16, before) | Baseline. Geometry through numpy scalars, obstacle list rebuilt on every path request. | 1.73 ms |
| `4493002` (Aug 16, same day) | Plain floats in the geometry helpers, a per-tick obstacle cache, no overlay drawing in headless runs, a bounding-box check before the segment distance. | 0.295 ms |
| `bbcff62` (Sep 28) | Six weeks of correctness work: less clearance in crowds, a fix for detours that dead-end at walls, keep-out circles around the ball, and a compiled (numba) obstacle scan. | 0.292 ms |
| `61be582` (Sep 29) | The detour search as a loop instead of recursion, plain-float line intersection, cheaper per-tick bookkeeping in the vision filters. | 0.264 ms |
| `8c191ee` (Sep 29) | Whole-function compiled kernels for the collision scan, detour search, target clean-up and clearance clamp. | 0.090 ms |
| `1697908` (v2.0.3) | Same code, plus October planner and tactic changes that add some work back. | 0.108 ms |

![Planner time per call at six commits](/images/blog/planner_time_per_call.svg)

That is about 16x from start to finish: 5.9x in the first day, a long flat stretch, then 2.9x, then a small giveback. The flat stretch is real. From Aug 16 to Sep 28 the planner gained behaviour, not speed. The compiled obstacle scan I added in that window was worth only 6 to 8% of planner time in a real match (commit message), because the search around it is a sequence of dependent steps that doesn't batch. The big second step came from moving the whole search into compiled code, not just the scan.

The first 5.9x came from boring changes. Plain floats instead of numpy scalars. A per-tick obstacle cache. A bounding-box check before the expensive distance, which cut the number of distance calls from 6.09M to 2.0M (commit message).

Whole-runner CPU for the same match went from 18.0 s to 3.7 s, about 5x. The gap is Amdahl's law: once the planner stopped being 75% of the time, the rest of the runner was what was left.

What made this safe to hand to an agent was one rule: **a speedup must not change a result.** Each change shipped with a test that keeps the old implementation next to the new one, and four fixture matches whose replays had to stay byte-identical. The compiled kernels do differ from numpy in the last bits, so they sit behind an environment variable, `UTAMA_EXACT_MATH`. The default is fast. Setting it to 1 reproduces earlier results exactly. The fast numerics are worth 2x per planner call (0.224 ms with exact math, 0.108 ms without) and about 1.4x on whole-runner CPU (commit message).

One more speedup came from not touching the planner at all. Tournament matches were slow because the runner started a browser vision stream by default, and nothing in a tournament watched it. A 60 second match took over 12 minutes. Turning the stream off brought it to about 21 seconds (commit message).

## Replays: 23.7 MB to 2.07 MB

The tools an agent uses to look at a match, the stuck detector, the clip renderer and the analyses, all read replays. A replay was one pickled frame per 1/60 s tick, and a full round-robin of them (every strategy plays every other once, 231 matches for our 22 strategies) filled the disk.

To compare formats fairly I captured the in-memory frames of one 120 second match (7,200 ticks) and re-encoded the same frames with each historical writer:

| Format | Size | vs pickle |
|---|---|---|
| Pickle per frame | 23.69 MB | 1x |
| Columnar `.npz` | 6.43 MB | 3.7x |
| + referee sidecar stores changes only | 4.34 MB | 5.5x |
| + float32 state | 2.07 MB | 11.5x |

![Replay size for one 120 second match](/images/blog/replay_size.svg)

The sidecar step is a bug story. The sidecar was meant to hold only rare referee fields, but a live referee sets team info on every message, so it held every tick. Storing only the changes took that file from 2.10 MB to 5.6 KB for this match. The float32 step is a judgment call I checked instead of assumed. The worst position error is 2.4e-7 m, far below vision noise, and re-encoding 24 round-robin matches left every analysis result within 1e-4 and every restart outcome identical (commit message).

Rebuilding every frame as Python objects is only 1.2x faster, because creating the objects dominates. The win is for tools that read the columns directly. The stuck detector, described next, runs about 15x faster on the columnar file (0.04 to 0.06 s against 0.69 to 0.88 s).

## Teaching the agent what "stuck" looks like

Most of the bugs I fixed this summer were the same bug: a match that stopped making progress. A ball nobody could reach. A free-kick taker crawling toward the ball too slowly to ever arrive. Two robots converging on one ball and freezing.

Looking for those by eye does not scale across 231 matches, so I wrote a detector that works on a replay after the match. It flags a window as stuck when the ball has barely moved *and* a robot's position keeps jittering back and forth instead of settling. A second check flags a restart command held for 15 seconds with the ball never moving. The detector only reports. Its output is a replay window for a human or an agent to render and read, and it feeds no live decision.

The first real catch was a ball carrier oscillating about 0.2 m beside a wall for over 540 seconds (commit message). The planner's detour search had given up and returned a point sitting on the wall. My first fix, rejecting that fallback outright, broke kickoff scrums that legitimately need many search steps. The fix that stayed rejects the fallback only when the same obstacle is still blocking at the cutoff.

The round-robin summary tracks this over time. Every full round-robin from Sep 16 to Sep 28 had between 3 and 12 stalled matches out of 231. The three full runs from Oct 1 to Oct 3 had 1, 0 and 0.

## The loop that made it cheap

A single check is not a harness. The pieces that mattered were the ones that let an agent test a change against evidence without me in the middle. Each one is something an agent can run and read.

- **A deterministic simulator plus a code fingerprint.** A match in our simulator (rsim) is a pure function of the code each side runs, the pairing and the settings. So I fingerprint the code, by parsing its import graph and never importing it, and a round-robin run with `--reuse` replays only the matches whose fingerprint changed. Edit one strategy and only its matches play. A spot check replays 5% of the reused matches and fails loudly if a dependency was missed.
- **A scenario bench.** A paired A/B screen over a set of starting situations (kickoffs, free kicks, penalties, open-play moments) taken from a round-robin's replays. The candidate and the baseline play the same starts, so what gets compared is the difference per start, not two separate win rates. It stops early once the difference is clear: on one run it stopped after 100 of 846 starts, about 1.5 minutes instead of 11 (commit message).
- **Checking the checkers.** `bench_vs_standings.py` asks whether the bench ranks strategies the way a round-robin does. The most it can agree is how well two round-robins agree with each other, which measured 0.84 to 0.91 (commit message). A separate study of cheap proxy metrics found turnovers, completed passes and attacking-third entries both valid and reliable, and possession and robot motion carrying no signal. I kept possession as a diagnostic, not as something to optimise.
- **Fuzzing the referee.** A `RestartFuzzingReferee` injects seeded random legal restarts into live play, to surface restart stalls that ordinary matches only hit occasionally.
- **Written guidance and tests that say no.** `AGENTS.md` has a work-area table, a glossary with one word per concept, and the rule that a bug-fix commit needs a regression test that fails before the fix. A known defect that I haven't fixed is marked as an expected failure that turns red the moment it starts passing, so a later fix can't go unnoticed.

## What's next, and what I don't know yet

The loop is built for strategy search: an agent proposes a tactic, the scenario bench screens it against a baseline, a round-robin with `--reuse` confirms it, and CI restricts `strategy/*` branches to strategy code. I haven't yet run an agent through that loop end to end.

The bench is also only a screen. Its agreement with round-robin standings is capped at about 0.9 by round-robin noise, so a bench win still has to be confirmed in a round-robin before I believe it.

*Method notes: planner timings come from git worktrees at six commits sharing one environment, five repeats, medians, using the process CPU time of the runner (the simulator subprocess is excluded). Match trajectories differ between commits, so per-call time is the cleanest comparison, and the first run at each commit was slower, which the median discards. Replay sizes come from one captured match and are not extrapolated here. Figures marked "commit message" come from the original commit notes and were not re-run.*
