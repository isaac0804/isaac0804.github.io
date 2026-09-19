---
title: "Scaling Strategy Search, Evaluators, and the Agentic Coding Workflow"
date: 2026-09-19T00:00:00Z
draft: false
tags: ["Robotics", "RoboCup", "AI Agents", "Evaluation", "Reinforcement Learning", "Software Engineering"]
summary: "Applying the Bitter Lesson to robot football: why strategy performance is a search problem, how noisy simulation breaks credit assignment, and how a 3-tier evaluation pyramid with seed pairing lets AI agents search tactic space."
cover:
    image: images/blog/evaluation_pyramid_harness.svg
    alt: "The 3-Tier Evaluation Pyramid and Autonomous Agentic Coding Harness"
    relative: false
---

*By Isaac, First Order Robotics Team*

---

Rich Sutton’s *Bitter Lesson* established an unavoidable truth in artificial intelligence: methods that leverage general computation—search and learning—inevitably outperform human-crafted heuristics.

In autonomous multi-agent sports, tactical superiority is fundamentally a **compute-scaling and search problem**. The team that can evaluate 10,000 tactical variations, stress-test dynamic counter-formations, and search policy space effectively will outcompete a team hand-crafting if/else heuristics every time.

Yet in competitive robotics, teams consistently run into a hard bottleneck: **the verifier problem**.

Search compute is useless without an accurate, low-variance value function. In reinforcement learning terms, robot football is an adversarial environment with delayed, sparse rewards ($\pm 1$ goal every few hundred seconds) and severe physical stochasticity. If your only evaluator is running a 10-minute simulation and watching the 2D visualizer to "vibe check" whether a passing chain looked crisper, your signal-to-noise ratio is zero. A single deflected ball or a motor slip at second 42 ruins credit assignment.

Search without an automated verifier is just hallucination at scale.

To unlock scalable strategy search, we had to solve three core problems:
1. **Search space stationarity**: Structuring code into modular, isolated tactical representations so changes don't cause explosive side effects.
2. **Variance-cancelled evaluation**: Building a 3-tier evaluation pyramid that uses seed-paired counterfactual rollouts to eliminate simulation noise.
3. **The autonomous policy proposal loop**: Leveraging autonomous AI coding agents as search operators over tactic space, bounded by automated contract gates.

---

## 1. Search Spaces Require Deterministic Contracts

In reinforcement learning or automated program synthesis, search over policy space only converges if the underlying representation is modular and stationary.

Under our legacy Behavior Tree architecture, the search space was pathological:
* **Untyped global blackboards**: Nodes read and wrote arbitrary string keys (`"passer_id"`, `"target_zone"`). Mutations in one branch triggered hidden side effects across unrelated subtrees.
* **Non-local control flow**: Execution order was smeared across tree topologies, tick traversals, and decorators.
* **Zero compile-time verifiability**: String typos failed silently at runtime 50 seconds into a match.

When a state space is entangled, evaluating any single modification requires exploring an exponential combination of global states.

To enable automated search, we refactored into our **Tactics × Orchestration** model (covered in Post 2). By enforcing:
1. **Disjoint robot sets**: A pure mathematical Partitioner prevents conflicting motor commands.
2. **Private typed dataclass state**: Every tactic owns an isolated `mem` instance.
3. **Protocol-enforced interfaces**: Every tactic conforms strictly to `tick(ctx, robots, mem) -> (commands, mem)`.

This collapses a chaotic 12-robot coordination problem into modular, independent subspaces. A tactic can be generated, mutated, or stress-tested in isolation without invalidating the rest of the stack.

---

## 2. The 3-Tier Evaluation Pyramid

How do you build a value function for robot football that is fast enough for inner-loop search, yet faithful to real-world physics?

Running full 10-minute matches for every tactic iteration is $O(\text{minutes})$ per sample and statistically noisy. Instead, our evaluation harness trades fidelity for latency across three distinct tiers:

![The 3-Tier Evaluation Pyramid and Autonomous Agentic Coding Harness](/images/blog/evaluation_pyramid_harness.svg)

### Tier 1: Invariant & Contract Gates (< 1s, Zero Simulator Compute)
Before allocating any physics simulation compute, a policy candidate must survive pure analytical verification:
* **Spatial geometry invariants**: Does defensive marking correctly position a robot along the shooter-to-goal bisector?
* **State machine invariants**: Does `applicable()` reject invalid field states? Does `is_committed()` release upon ball contact?
* **Scheduler invariants**: Does single-writer assignment hold across all allocated robot IDs?

Tier 1 runs in-memory in milliseconds. It filters out 90% of syntactically valid but structurally broken proposals instantly.

### Tier 2: Scenario Benchmarks & Seed-Paired Rollouts (10–30s)
To evaluate dynamic physics without running full 600-second games, we extract **`BenchScenario`** rollouts: 5-second, high-leverage micro-situations (2v1 counter-attacks, corner kick defenses, contested loose balls).

However, physics simulation introduces random variance (wheel slip, collision micro-bounces, vision latency). Evaluating Candidate $B$ against Baseline $A$ across independent seeds is noisy: $B$ might win purely because seed 83 gave it an advantageous bounce.

To eliminate environment variance, our harness implements **Seed Pairing** (antithetic / counterfactual baseline subtraction):
1. Candidate $B$ and Baseline $A$ are initialized to the exact same continuous world state $s_0$.
2. Both policies roll out against the **exact same pseudo-random seed sequence** $\text{seed}_k$ (identical opponent decisions, identical noise trajectories).
3. We compute the paired difference:

$$\Delta \text{Performance} = \text{Score}_B(\text{seed}_k) - \text{Score}_A(\text{seed}_k)$$

Because environmental variance is identical across both runs, the shared noise term cancels out:

$$\operatorname{Var}(\Delta) = \operatorname{Var}(B) + \operatorname{Var}(A) - 2\operatorname{Cov}(B, A)$$

Since $B$ and $A$ share identical initial states and random perturbations, $\operatorname{Cov}(B, A) \approx \operatorname{Var}(\text{env})$, collapsing sample variance to near zero. A 10-scenario seed-paired batch provides tighter statistical confidence than 50 unseeded full matches.

### Tier 3: Tournament Ladder & Meta Stability (Minutes to Hours)
Policies that clear Tier 2 enter an automated asynchronous tournament ladder (`arena_tournament.py`), competing against our catalog of established baselines (`tiki_taka`, `zone_flow`, `counter_flow`, `score_aware_zone_flow`).

Tier 3 updates Elo ratings, checks long-horizon stamina, monitors foul accumulation rates, and detects non-transitive meta cycles (e.g., A beats B, B beats C, C beats A).

---

## 3. The Agentic Search Loop

Once you have a fast, noiseless evaluation harness, strategy development transforms from manual engineering into **guided search over code space**.

LLM coding agents are natural policy proposal operators: they can generate tactical variations, optimize geometric heuristics, and refactor coordination logic. However, without automated verifiers, LLMs hallucinate broken code and degrade quickly.

By coupling our 3-tier harness with autonomous agents, we close the loop:

```
       [ Human Architect ] ──► Specifies Value Function & Scenarios
                 │
                 ▼
       [ AI Policy Proposer ] ──► Generates / Mutates Tactic Code
                 │
                 ▼
       [ Tier 1: Invariants ] ──► (Compiler / Unit Check; Auto-Refines on Fail)
                 │ Pass
                 ▼
       [ Tier 2: Seed Pairing ] ──► (Calculates Δ vs Baseline; Prunes Regressions)
                 │ Pass
                 ▼
       [ Tier 3: Ladder ELO ] ──► (Meta Certification & Deployment)
```

1. **Objective Specification**: The human defines the target behavior and value metric (e.g., *"Implement an overload tactic that pulls the near-post defender away during corner restarts"*).
2. **Policy Generation**: The AI agent authors the tactic under the strict `Tactic` Protocol.
3. **Inner Verification (Tier 1)**: The agent runs `pytest --headless`. If a contract or type invariant fails, the traceback is fed directly back into the agent's context for autonomous self-correction.
4. **Counterfactual Validation (Tier 2)**: The candidate executes seed-paired scenario benchmarks. If $\Delta \text{Performance} \le 0$, the change is rejected.
5. **Ladder Promotion (Tier 3)**: Certified candidates enter the tournament ladder and update team Elo ratings.

In this paradigm, the engineer no longer spends days writing if/else branches or staring at 2D visualizers. The engineer's role becomes that of a **verifier architect**—shaping the loss landscape, curating high-leverage scenarios, and defining mathematical invariants—while automated compute searches the tactical space.

---

## Summary

- **The Bitter Lesson applies to sports robotics**: Hand-tuned heuristics hit an early complexity ceiling. Long-term performance scales with compute spent on search and verification.
- **Search requires a value function**: Without fast, low-variance evaluators, compute is wasted. Sparse 10-minute match scores cannot guide optimization.
- **Variance cancellation unlocks simulation**: Seed pairing cancels physical noise, providing statistical confidence in seconds rather than hours.
- **Clean architecture enables agentic search**: Isolated protocols, disjoint allocations, and typed state turn AI coding agents into reliable search operators.

---

### Join First Order Robotics

Autonomous robot football is one of the most exciting testbeds in modern robotics—combining high-speed embedded hardware, real-time computer vision, optimal trajectory planning, and distributed multi-agent game theory.

Our team at **First Order Robotics** is actively recruiting students at **Imperial College London** to join us as we build toward our next competitive milestones:
* **Motion Planning**: Implement Model Predictive Control (MPC) and Trajectory Sampling on physical omnidirectional robots.
* **Computer Vision**: Build automated multi-camera calibration and latency compensation pipelines.
* **Embedded Hardware**: Design high-voltage kicker circuits, wireless telemetry firmwares, and motor controllers.
* **Strategy & AI**: Develop learned tactical partitioners and expand our automated evaluation harness.

If you are an Imperial student excited about building autonomous systems that compete in the physical world, reach out to get involved.

---

*Thank you for following this 3-part series on building the First Order Robotics software stack. Check out the previous posts on [our system architecture](/posts/2026-09-17-leading-software-for-a-robot-football-team/) and [Tactics × Orchestration](/posts/2026-09-18-strategy-tactics-orchestration/).*
