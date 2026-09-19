---
title: "Scaling Strategy Search, Evaluators, and the Agentic Coding Workflow"
date: 2026-09-19T00:00:00Z
draft: true
tags: ["Robotics", "RoboCup", "AI Agents", "Evaluation", "Software Engineering"]
summary: "Our bet on scaling robot sports: why we believe coding agents can search strategy space better than human developers, and the infrastructure, debugging tools, and evaluation benches we built to let them hill-climb."
cover:
    image: images/blog/strategy_search_loop.svg
    alt: "The Agentic Strategy Search Loop"
    relative: false
---

*By Isaac, First Order Robotics Team*

---

## 1. The Bet: Searching Strategy Space with Coding Agents

In competitive robot football, human trial-and-error hits a complexity wall very quickly. 

You can spend days hand-tuning passing thresholds, adjusting marking distances, or writing nested if/else statements for dynamic game states. But as the number of robots and opponent counter-tactics grows, the combinatorial space of multi-robot coordination becomes too large for any single engineer to navigate by intuition alone.

Our core hypothesis in First Order Robotics is based on a specific bet:
1. **Strategy performance is ultimately a search problem**: Searching across strategy and program space can discover coordination patterns and tactical behaviors that human developers would never hand-craft.
2. **AI coding agents can search strategy space more efficiently than human engineers**: An autonomous coding agent can generate tactical variations, refactor coordination logic, explore edge cases, and run benchmarks around the clock—far faster than a human writing boilerplate.

If we make this bet, our primary role as software engineers fundamentally shifts. **We are not here to hand-craft every edge case. Our job is to build the infrastructure—the environment, the code contracts, and the evaluators—that allows coding agents to search strategy code and hill-climb toward better policies.**

![The Agentic Strategy Search Loop](/images/blog/strategy_search_loop.svg)

In this workflow, the **AI Coding Agent** acts as the search operator over the strategy codebase. Guided by repository context (`AGENTS.md`) and runtime debugging telemetry, the coding agent proposes, modifies, and refactors tactic implementations, then runs evaluators to verify if the new policy actually improved performance.

---

## 2. Infrastructure for Coding Agents: Making Search Efficient

For an AI coding agent to effectively search a strategy codebase, it cannot operate in an unstructured environment. Every piece of infrastructure we built exists to make this search process more reliable and efficient.

### Strategy and Tactic Contracts: Isolating the Search Space
In our second post, I broke down why we refactored our stack into **Tactics × Orchestration**. A major reason was to make the search space tractable:
* **Disjoint robot allocations**: A pure mathematical Partitioner assigns robots to tactics so that no two tactics ever control the same robot. An agent can mutate an attacking tactic without accidentally issuing conflicting commands to defensive robots.
* **Private typed state**: Every tactic owns an isolated `mem` dataclass. Tactics cannot read or write to global shared blackboards, preventing changes in one file from causing silent side effects in another.
* **Protocol enforcement**: Every tactic implements a clean `tick(ctx, robots, mem) -> (commands, mem)` interface.

Without these contracts, an agent modifying a striker heuristic would routinely break the goalkeeper. Isolating the state space allows the agent to search and optimize individual tactics locally without collapsing the rest of the team.

### Durable Context (`AGENTS.md`): Anchoring Search
Autonomous agents lack long-term memory across sessions. If an agent has to re-learn repo structure, testing conventions, and past architectural pitfalls on every turn, search efficiency collapses.

We maintain an authoritative [`AGENTS.md`](file:///home/isaac/dev/ssl/Utama-Core/AGENTS.md) at the repository root. It provides durable context: architectural boundaries, strict constraints (such as always passing `--headless` to tests, and never hand-writing multi-robot allocations), and historical lessons from past tactic deadlocks. This anchors the agent's search within realistic bounds from the very first prompt.

### Runtime Telemetry: Providing Search Direction
A search algorithm cannot hill-climb if its only feedback is a single scalar loss or an opaque 0–1 match scoreline after 10 minutes. The agent needs actionable diagnostic feedback to understand *why* a policy failed so it can propose an informed fix.

To provide this feedback without flooding the agent's context window with raw numerical data, we built focused telemetry tools:
* **`MatchLog` (Context-Efficient Telemetry)**: Structured JSONL logging that separates high-level `intention` changes (logged only when tactic slot assignments change, keeping token usage minimal) from granular `trace()` calls (per-tick variable logging enabled on demand for debugging).
* **Visual Motion Trails (`render_window`)**: Dumping thousands of floating-point coordinate rows into an LLM's context window wastes tokens and makes spatial patterns hard to parse. Rendering a top-down PNG of 5-second robot and ball trajectories uses far fewer tokens and makes spatial breakdowns—such as defenders clustering on the same attacker—immediately obvious.
* **In-Match Stall Watchdog**: Automatically detects live game deadlocks—such as referee stoppages lasting >15 seconds (`RESTART_STALL`) or ball freezes lasting >10 seconds while a tactic is committed (`COMMITTED_FROZEN`)—and writes the exact onset time and tactic IDs into a diagnostic JSON file.
* **Deterministic Replay Slicing**: Takes a 15-second snapshot of a specific failure from a match replay and re-runs it headlessly in seconds, letting an agent iterate directly on the issue without re-running an entire match.

---

## 3. How We Evaluate: Three Benches

In reinforcement learning, teams often train a parametric critic or learned value function to evaluate policies. We decided not to use a parametric critic at this stage for two reasons:
1. **Scale**: Training a reliable neural critic requires massive environment rollouts. At our scale, it is sample-inefficient and prone to distribution shift.
2. **Interpretability**: A neural critic outputs an opaque scalar value (e.g. 0.72). An LLM coding agent cannot take "0.72" and know what line of code or tactical decision was flawed.

Instead, we built three evaluation benches that provide interpretable, causal signals that an agent can directly reason about:

![Three Ways to Evaluate Strategy: Test Bench, Scenario Bench, and Tournament](/images/blog/evaluation_methods.svg)

### 1. Test Bench (Fixed Tests)
* **What it is**: Deterministic, pure Python in-memory tests running in under a second without spinning up a simulator.
* **Purpose**: Ensures tactics and strategies perform the way they should at a functional level.
* **What it checks**: Contract adherence, single-writer partitioning, and spatial geometry calculations (marking angles, shot blocking).
* **Role in search**: Fast, deterministic pass/fail filter. If an agent introduces a syntax error, type mismatch, or invariant violation, it gets an immediate stack trace to self-correct within seconds.

### 2. Scenario Bench (Wide Scenario Coverage)
* **What it is**: Isolated, 5-second dynamic simulation runs across a broad library of predefined match situations.
* **Execution speed**: 10 to 30 seconds.
* **Purpose**: Provides broad scenario coverage to spot tactical errors quickly across varied game situations, without the overhead of playing full matches.
* **Scenario coverage**: 2v1 counter-breakaways, defensive walls against corner kicks, contested loose-ball scrums in midfield, and goal-line scrambles.
* **Seed Pairing for Noise-Free Comparison**:
  Physical simulation introduces random noise (wheel slip, collision micro-bounces, vision latency). If Candidate Strategy B runs on Seed 42 and Baseline Strategy A runs on Seed 99, Strategy B might win purely because of favorable physics noise.
  
  To eliminate this noise, the Scenario Bench uses **Seed Pairing**: both strategies are spawned into the **exact same initial field state** and executed against the **identical sequence of pseudo-random seeds**.

  By comparing the paired difference:
  $$\Delta = \text{Score}_B(\text{seed}_k) - \text{Score}_A(\text{seed}_k)$$
  environmental variance cancels out, giving clean, high-signal feedback on whether a tactical code change actually improved performance across the scenario library.

### 3. Tournament (Head-to-Head Matches)
* **What it is**: Full 6v6 round-robin matches run headlessly against our catalog of established strategies (`tiki_taka`, `zone_flow`, `counter_flow`, `score_aware_zone_flow`).
* **Execution speed**: Minutes to hours.
* **Purpose**: Tests emergent 6v6 team coordination, referee foul accumulation, and overall competitiveness over a full 600-second match.
* **Role in search**: While this is the most realistic evaluation, it provides less immediate, granular signal for rapid iterative development. A 1–0 scoreline after 10 minutes does not tell an agent which specific passing decision or defensive rotation made the difference. It serves as the final validation gate before merging a strategy into the active roster.

---

## Summary & Looking Forward

Building an autonomous robot football stack is about creating the conditions for automated improvement:
1. **The core bet**: Strategy development is a search problem, and AI coding agents can explore that search space faster than humans if given the right infrastructure.
2. **Clean contracts and durable context**: Protocol-enforced tactics, private typed state, and `AGENTS.md` isolate the search space so agents can iterate safely.
3. **Interpretable feedback over opaque critics**: Tools like `MatchLog`, visual motion trail PNGs, and the stall watchdog give agents actionable diagnostics instead of uninterpretable scalars.
4. **Three evaluation benches**: Fixed test benches for functional correctness, scenario benches for wide coverage and seed-paired comparisons, and tournaments for macro competitive validation.

### Join First Order Robotics

Autonomous robot sports sits at the intersection of embedded hardware, optimal trajectory planning, distributed multi-agent systems, and automated software workflows.

Our team at **First Order Robotics** is actively recruiting students at **Imperial College London** across our core sub-teams:
* **Motion Planning**: Implement Model Predictive Control (MPC) and Trajectory Sampling on physical omnidirectional robots.
* **Computer Vision**: Build automated multi-camera calibration and latency compensation pipelines.
* **Embedded Hardware**: Design high-voltage kicker circuits, wireless telemetry firmwares, and motor controllers.
* **Strategy & AI**: Expand our tactical library, optimize partitioners, and build automated evaluation harnesses.

If you are an Imperial student excited about building autonomous systems that compete in the physical world, reach out to get involved.

---

*Thank you for following this 3-part series on building the First Order Robotics software stack. Check out the previous posts on [our system architecture](/posts/2026-09-17-leading-software-for-a-robot-football-team/) and [Tactics × Orchestration](/posts/2026-09-18-strategy-tactics-orchestration/).*
