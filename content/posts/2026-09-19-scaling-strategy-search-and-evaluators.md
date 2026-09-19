---
title: "Scaling Strategy Search, Evaluators, and the Agentic Coding Workflow"
date: 2026-09-19T00:00:00Z
draft: false
tags: ["Robotics", "RoboCup", "AI Agents", "Evaluation", "Software Engineering"]
summary: "Moving past the vibe check trap in autonomous sports: building a 3-tier evaluation pyramid, seed pairing to defeat simulation noise, and pairing with AI coding agents to search, debug, and benchmark tactics."
cover:
    image: images/blog/tactic_scheduling_timeline.svg
    alt: "Multi-Robot Tactic Scheduling Timeline: managing robot allocation across ticks, commitment locks, and barrier resets"
    relative: false
---

*By Isaac, First Order Robotics Team*

---

In competitive robot sports, there is a dangerous trap that every engineering team eventually encounters: **the "vibe check" evaluation**.

You spend hours tweaking a passing trajectory or fine-tuning a defensive marking threshold. You launch a 10-minute simulation match against last week’s strategy. You watch the 2D visualizer intently. Your team wins 1–0. 

*“The passing looks crisper,”* you tell yourself. *“The defense feels much more aggressive.”*

In reality, your change might have done nothing of the sort. In football, rewards are notoriously sparse, delayed, and chaotic. A single deflected ball at second 42 or an opponent wheel catching on a carpet seam can determine the entire scoreline. Watching a 2D match and trying to evaluate tactical quality with your human eyes is the robotics equivalent of reading tea leaves.

In my first post, I outlined the physical reality of our RoboCup Small Size League (SSL) stack. In my second post, I broke down how we separated strategy into **Tactics × Orchestration** to make multi-robot coordination modular and race-condition free.

In this third and final post, I want to address the biggest bottleneck in autonomous sports engineering: **How do you actually know if a strategy is better?** 

I will share how we moved from subjective visual impressions to quantifiable engineering metrics, how we built a **3-tier evaluation pyramid** using **seed pairing** to eliminate simulation noise, and how a deterministic software stack enabled an **agentic coding workflow**—where autonomous AI coding agents search, implement, and benchmark tactics alongside human engineers.

---

## 1. Measuring Architecture: What Can We Quantify?

When I decided to rip out our legacy Behavior Tree architecture in favor of the tactic-kernel model, I refused to rely on vague aesthetic arguments like "it feels cleaner" or "it's more elegant." If a new architecture is genuinely superior, that superiority must be **quantifiable**.

In our engineering reflections, we established four concrete dimensions to measure architectural improvement:

### 1. Static and Structural Complexity
* **Lines of Code (LOC)**: Compare equivalent tactical behaviors (such as a 2v2 attack or a defensive zone) between the Behavior Tree and the Tactic implementations, excluding comments. A decoupled functional model should drastically reduce boilerplate.
* **Cyclomatic Complexity**: Running tools like `radon cc` to measure decision branches. In a behavior tree, control flow is smeared across node classes, decorators, and tree topologies. In a tactic, control flow is concentrated into small, pure, unit-testable functions with lower branch complexity.
* **Indirection Hops**: To answer a concrete debugging question—such as *"what happens if `passer_id` is `None`?"*—how many files, classes, and decorators do you need to open? In our behavior tree, answering this required tracing through five separate node files and blackboard declarations. In a tactic, the answer is contained in a single self-contained function.
* **Blackboard Contract Audits**: In behavior trees, nodes declare read/write dependencies (`rd_`, `wr_`) on global blackboard strings. We audited our tree and found numerous mismatches: declared keys that were never read, and hidden keys used without declaration. In the tactic-kernel model, shared blackboards are eliminated entirely; tactic memory is private and strongly typed.

### 2. Type-Checker Leverage
In a multi-robot system executing at 60 Hz, runtime crashes are unacceptable. 
* In a behavior tree, blackboard communication relies on untyped strings: `blackboard.get("passer_id")`. A typo (`"paser_id"`) cannot be caught by static analyzers—it fails silently at runtime, manifesting as a mysterious stall fifty seconds into a match.
* In our Tactic model, all memory state is typed via Python dataclasses and `typing.Protocol`. Running strict `mypy` or `pyright` catches field renames, missing arguments, and type mismatches instantly at compile time, long before code ever touches the simulator or the robot hardware.

### 3. Behavioral and Task Metrics
Code legibility is meaningless if the robots play worse. We measured behavioral success across identical randomized scenarios:
* **Pass completion rate**: The percentage of attempted passes cleanly received without deflection or interception.
* **Time-to-shot**: How quickly the team transitions from ball recovery to an on-target shot.
* **Foul frequency**: The number of rule infractions (pushing, entering the defense area, exceeding speed limits under STOP) triggered per match minute.

---

## 2. The 3-Tier Evaluation Pyramid

Running a full 10-minute 6v6 match to test every small code modification is impossibly slow and statistically noisy. To scale strategy development, we organized our testing into a **3-tier evaluation pyramid**:

![The 3-Tier Evaluation Pyramid: Tier 1 Unit Tests (<1s), Tier 2 Scenario Benchmarks (10-30s), Tier 3 Tournament Ladder (Minutes-Hours)](/images/blog/system_architecture.svg)

### Tier 1: Unit & Invariant Tests (< 1 Second)
The base of the pyramid consists of pure Python unit tests running in memory without spinning up a simulator.

These tests assert:
* **Tactical geometry**: Does `_mark_target()` correctly position a defender between the opponent striker and the goal center?
* **Entry and exit gates**: Does `applicable()` return `False` when the ball is out of range? Does `is_committed()` properly release when a pass is received?
* **Scheduler invariants**: Does the `Partitioner` allocate strictly disjoint robot sets? Does `Strategy.tick()` enforce the single-writer invariant and catch duplicate assignments?

Because Tier 1 tests run in milliseconds, developers (and AI agents) can run them after every single code edit.

### Tier 2: Scenario Benchmarks & Seed Pairing (10–30 Seconds)
When you want to know if a tactic works in dynamic physics, running a full match introduces too many confounding variables. 

Instead, our replay system captures **`BenchScenario`** snapshots: high-leverage 5-second game situations harvested from real matches or hand-authored by engineers:
* A 2v1 counter-attack breakaway.
* A defensive wall defending an indirect free kick from the corner.
* A contested loose ball in midfield.

#### The Secret Weapon: Seed Pairing
In physics simulation, pseudo-random noise (wheel slip, collision micro-bounces, vision latency) creates variance. If Strategy A plays Scenario 1 with Seed 42 and Strategy B plays Scenario 1 with Seed 99, Strategy B might win purely because of random physics jitter.

To eliminate this noise, our benchmark harness uses **Seed Pairing**:
1. Strategy A (Baseline) and Strategy B (Candidate) are spawned into the **exact same initial field state**.
2. Both runs execute against the **identical sequence of pseudo-random seeds**.
3. The opponent team's initial positions and sensor noise are identical.

By holding the environment completely deterministic, environmental noise cancels out:

$$\Delta \text{Performance} = \text{Score}_B(\text{seed}_k) - \text{Score}_A(\text{seed}_k)$$

If Strategy B scores 4 out of 5 goals while Strategy A only scores 2 under the exact same seeds, you have mathematically rigorous proof that your tactical change improved performance.

### Tier 3: The Tournament Ladder (Minutes to Hours)
Once a strategy passes Tier 1 invariants and Tier 2 scenario benchmarks, it enters our automated round-robin tournament runner (`smoke_tournament.py` and `arena_tournament.py`).

The tournament runner pits candidate strategies against our established catalog:
* **`tiki_taka`**: High-tempo short-passing possession game.
* **`zone_flow`**: Fluid zonal defense paired with wide wing overloads.
* **`score_aware_zone_flow`**: Dynamically shifts between a 4-attacker press when trailing and a 3-defender low block when defending a lead in the final 60 seconds.
* **`counter_flow`**: Absorbs pressure and launches rapid direct counter-attacks.

The tournament runner aggregates head-to-head records, goal differentials, stall rates, and referee infractions over hundreds of simulated games, producing an updated ELO ranking across the entire codebase.

---

## 3. The Agentic Coding Workflow

Over the past year, AI coding assistants have evolved from simple autocomplete tools into autonomous agents capable of reading repos, executing shell commands, and writing multi-file pull requests. 

However, in many robotics codebases, asking an AI agent to write strategy code fails miserably. Why? Because the code relies on **tacit human knowledge**: unspoken conventions, untyped blackboard strings, and hidden execution orders that no LLM can deduce from a prompt.

### The Agent Benchmark
In our metrics document, we formulated a challenge: **The LLM-Agent Modification Benchmark**.

> *Take a fresh autonomous coding agent with zero repository history. Give it a realistic tactical task—such as "Add a timeout that aborts a give-and-go play if the receiver is blocked for 3 seconds" or "Implement an overload tactic that pulls a marker away from the primary striker."*
> 
> *Measure: Can the agent produce a correct diff, in how many tool turns, without introducing regressions?*

Under our legacy Behavior Tree architecture, LLM agents consistently failed this benchmark:
* They hallucinated blackboard keys that didn't exist.
* They inserted tree decorators in places that broke tick traversal order.
* They could not verify their changes without human intervention.

### How Tactics × Orchestration Enables AI Pair Programming

Under our current architecture, the agent benchmark succeeded completely. The reason comes down to three architectural properties:

1. **Explicit, Isolated Contracts**: A tactic is a self-contained class satisfying `Protocol`. An agent does not need to understand the entire 10,000-line codebase to write a tactic—it only needs to implement `initial_mem()`, `tick()`, and declare its `tag`.
2. **Private Typed Memory**: Because tactics carry private typed state (`mem`) rather than global blackboards, the agent's changes cannot cause invisible side effects in other files.
3. **Fast, Falsifiable Feedback Loops**: An agent can write a tactic, generate a Tier 1 unit test, run `pytest --headless`, and immediately receive concrete compiler or test feedback. If a test fails, the agent reads the traceback, fixes the bug, and re-runs—all within an automated loop.

```
       [ Human Architect ]
     Defines Invariants & Scenarios
                 │
                 ▼
         [ AI Coding Agent ]
    Implements / Refactors Tactic
                 │
                 ▼
       [ Tier 1: Unit Tests ]  ──► (Fails? Agent self-corrects)
                 │ Pass
                 ▼
     [ Tier 2: Scenario Bench ] ──► (Seed-paired delta comparison)
                 │ Pass
                 ▼
     [ Tier 3: Tournament Run ] ──► (ELO verification)
```

In this workflow, the role of the human engineer fundamentally shifts:
* **Before**: The human spent 80% of their time writing boilerplate if/else loops, debugging blackboard race conditions, and manually watching 2D replays.
* **Today**: The human acts as an **architect and evaluator designer**—curating high-value match scenarios, defining mathematical invariants, and specifying performance metrics, while AI agents explore the tactical search space and implement verified code.

---

## Summary & What’s Next

Building an autonomous robot football stack is not just about writing algorithms that look good on paper; it is about building the **infrastructure to verify them**:

1. **Quantify architectural quality**: Don't rely on aesthetic claims. Measure lines of code, cyclomatic complexity, indirection hops, and type safety directly.
2. **Eliminate evaluation noise**: Use a 3-tier pyramid with seed-paired scenario benchmarking to measure tactical improvements in seconds rather than hours.
3. **Design for autonomous collaboration**: Clean contracts, private typed memory, and fast deterministic test suites allow AI coding agents to search and improve strategies safely.

### Join First Order Robotics

Autonomous robot football is one of the most exciting testbeds in modern robotics—combining high-speed embedded hardware, real-time computer vision, optimal trajectory planning, and distributed multi-agent game theory.

Our team at **First Order Robotics** is actively recruiting students at **Imperial College London** to join us as we build toward our next competitive milestones:
* **Motion Planning**: Implement Model Predictive Control (MPC) and Trajectory Sampling on physical omnidirectional robots.
* **Computer Vision**: Build automated multi-camera calibration and latency compensation pipelines.
* **Embedded Hardware**: Design high-voltage kicker circuits, wireless telemetry firmwares, and motor controllers.
* **Strategy & AI**: Develop learned tactical partitioners and expand our automated evaluation harness.

If you are an Imperial student excited about building autonomous systems that compete in the physical world, check out our repositories or reach out to get involved!

---

*Thank you for following this 3-part series on building the First Order Robotics software stack. Check out the previous posts on [our system architecture](/posts/2026-09-17-leading-software-for-a-robot-football-team/) and [Tactics × Orchestration](/posts/2026-09-18-strategy-tactics-orchestration/).*
