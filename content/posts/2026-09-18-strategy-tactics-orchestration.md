---
title: "Strategy = Tactics × Orchestration"
date: 2026-09-18T00:00:00Z
draft: false
tags: ["Robotics", "RoboCup", "Software Architecture", "Python", "Operating Systems"]
summary: "Why Behavior Trees broke down for multi-agent coordination, how modeling our scheduler after an OS kernel solved dynamic regrouping, and the three safety invariants that eliminate race conditions."
---

*By Isaac, First Order Robotics Team*

---

In competitive autonomous robot football, the strategy layer has a deceptively hard job: sixty times a second, it must decide what every robot on the pitch is doing. In the RoboCup Small Size League (SSL), where six holonomic robots per side accelerate at up to $4\text{ m/s}^2$ and strike golf balls at $6.5\text{ m/s}$, a single tick of indecision or a missed state transition leads immediately to open goals or physical collisions.

In my previous post, I gave an architectural overview of our stack and shared how the team's milestone at the Great Exhibition Road Festival motivated us to scale up to a full 6v6 squad. 

In this post, I want to take a deep dive into the strategy layer: why the earlier **Behavior Tree** architecture broke down, how I restructured our strategy around the mathematical model of **Tactics × Orchestration**, why I modeled the scheduler after an **operating system kernel**, and the three safety invariants that make dynamic multi-robot coordination work without concurrency bugs.

---

## 1. Why I Moved on from Behavior Trees

Like many robotics teams, the earliest strategy layer was built on **Behavior Trees (BT)** using Python’s `py_trees` library. Behavior trees are standard in single-agent game AI and mobile robotics, celebrated for reactive fallback logic.

However, as the system scaled toward full 6v6 play, behavior trees became fundamentally painful to maintain and reason about. In short:
* **The single-agent mismatch**: A tree naturally models *one* entity. For six robots, you either maintain six disjoint trees that cannot synchronize plays, or a monolithic 50+ node tree that is impossible to navigate.
* **The "Blackboard" trap**: Sharing information between subtrees requires untyped global strings (`blackboard.set("passer_id", ...)`), causing silent race conditions and invisible bugs.
* **Dynamic regrouping fights static trees**: Football is fluid. Dynamically dissolving an offensive 2-robot overlap to form an ad-hoc 3-robot defensive wall requires spaghetti decorators and priority switches.

<details>
<summary><b>Deep Dive: The Specific Architectural Breakdowns of Behavior Trees (Click to expand)</b></summary>

### The Single-Agent Mismatch
A behavior tree naturally models the decision hierarchy of a **single agent**. When applied to six robots, you are forced into an awkward choice:
1. **Six independent trees**: One per robot. But coordinated actions (like a give-and-go pass or a zonal wall) require external signaling and locks, defeating the modularity of the tree.
2. **One monolithic tree**: A single massive tree driving all six robots. In practice, this tree rapidly grew into a 50+ node monstrosity that was impossible to trace or debug.

### The "Blackboard" Trap
In a monolithic multi-robot tree, subtrees communicate via a shared **blackboard**—essentially an untyped global dictionary:
```python
# Untyped, implicit, order-dependent couplings
blackboard.set("passer_id", robot_1)
blackboard.set("target_point", Point(1.2, -0.5))
```
A node deep in an offensive branch could silently overwrite a variable needed by a defensive fallback. Because keys were raw strings, type checkers couldn't verify them, leading to regressions that only manifested when specific branches fired in rare sequences.

### Dynamic Regrouping Fights the Tree Hierarchy
When the opponent deflects the ball, a two-robot attack and three-robot defense must instantly morph into two pressing markers and two retreating defenders. Inside a static tree hierarchy, forming temporary multi-robot squads requires an explosion of custom decorators, conditional gates, and priority selectors.

</details>

Instead of fighting the tree structure, I stepped back and re-examined the fundamental problem: how do you coordinate multiple autonomous agents dynamically without shared global state?

---

## 2. The Mental Model: Strategy = Tactics × Orchestration

To solve this, I separated the problem into two orthogonal concerns: **Tactics** and **Orchestration**.

* **A `Tactic` is a local group behavior**: A self-contained micro-behavior for an arbitrary group of robots (e.g., `GiveAndGoTactic`, `PressAndContainTactic`, `DefensiveWallTactic`). It has its own private, typed memory state, zero global blackboards, and no awareness of how many other tactics exist on the field. Crucially, **a tactic never decides who is assigned to it**.
* **`Orchestration` is global resource allocation**: A pure scheduling function (the `Partitioner`) that looks at the current match state and decides how to partition the pool of free robots across available tactic slots. Crucially, **the orchestrator never decides what a group of robots does once assigned to a tactic**.

Multiplying these two orthogonal concerns together produces the team's behavior on the pitch:

$$\text{Team Behavior} = \text{Tactics} \times \text{Orchestration}$$

If you want to change the team formation from a conservative 3-defender shape to an aggressive high press, you change the orchestration policy—the underlying tactics remain untouched. Conversely, if you optimize the passing geometry inside `GiveAndGoTactic`, every formation that uses it inherits the improvement instantly.

### The OS Scheduler Analogy

If this mental model feels familiar, it is because it mirrors a modern **multitasking operating system kernel**:

![The OS Scheduler Model](/images/blog/os_scheduler_model.svg)

The computer systems analogy maps directly:
* **Robots are CPU Cores**: The outfield robots are the scarce compute resource that must be allocated.
* **Tactics are Processes**: Each tactic is an isolated process executing a specific task with private heap memory.
* **Strategy is the OS Scheduler**: Every 16 ms tick, the scheduler runs a partitioner function that assigns available cores (robots) to active processes (tactics).
* **`is_committed()` is a Mutex / Non-preemptible Critical Section**: When a tactic begins a time-critical action that cannot be interrupted without disaster (e.g., a kicker striking the ball or a receiver awaiting a pass), it declares `is_committed() = True`. The scheduler guarantees those robots will not be preempted or reassigned until the action completes.
* **Referee Restarts are Universal Barrier Resets**: When the referee stops play (whistle, foul, restart), the kernel executes a universal reset—wiping all tactic memories and clearing all commitment locks simultaneously.

### Strategy Implementation: The Scheduling Loop

At every tick (60 Hz), the strategy kernel executes a simple, 3-step orchestration loop:

```python
# 1. Respect committed actions (their robots cannot be reassigned)
free_robots = get_uncommitted_robots(game)

# 2. The Partitioner divides free robots among candidate tactics
allocations = partitioner(game, free_robots)
# e.g. {"strike_play": [1, 2], "shadow_and_mark": [3, 4, 5]}

# 3. Each active tactic independently drives its assigned robots
commands = {}
for tactic, assigned_robots in allocations.items():
    slot_commands, memory = tactic.tick(game, assigned_robots, memory)
    commands.update(slot_commands)
```

Notice the simplicity of the mental model:
* **Inputs**: The live game state + the pool of uncommitted robots.
* **Decision**: A pure assignment mapping tactics to disjoint robot subsets.
* **Execution**: Each tactic independently drives its assigned robots without knowing who is driving the others.

---

## 3. The Tactic Contract and The Philosophy of `tag`

What does a Tactic look like to the scheduler? Stripped of Python typing machinery, a tactic only needs to provide:

1. **`tick(game, robots, memory)` (Required)**: Calculates wheel/kick commands for its assigned robots and returns updated state.
2. **`tag` (Required)**: A coarse role declaration (`"attack"`, `"defense"`, or `"mixed"`).
3. **`is_committed(game, memory)` (Optional, default: `False`)**: An exit lock indicating whether interrupting this tactic mid-action would cause physical chaos.
4. **`applicable(game)` (Optional, default: `True`)**: An entry gate checking physical preconditions (e.g. only run if ball is in the opponent half).

### A Note on `tag` and Scheduler Design

`tag` is strictly a **scheduler-facing feature**. 

When designing this layer, I spent a lot of time weighing whether tactics should expose continuous fitness scores, dynamic utility bids, or priority weights to help the scheduler choose who gets which robots at runtime. 

Ultimately, I decided that trying to build an elaborate, universal scheduler that caters to every conceivable tactic's needs is a trap. In multi-robot systems, premature generalization in scheduler heuristics often introduces complex configuration layers that obscure behavior and make debugging nearly impossible.

Instead, `tag` provides a simple, coarse handle:
* A partitioner can balance team roles (e.g., *"guarantee at least 2 robots go to defense-tagged tactics"*) without knowing individual tactic names.
* Telemetry and replay tools can color-code team formations and log tactical distributions across a match.

It is a pragmatic baseline that works reliably today. But more importantly, the interface is deliberately unencumbered: if anyone on the team or in the robotics community has a better idea—whether reinforcement-learned allocation, market auctions, or hierarchical task networks—the architecture leaves clean room to experiment.

### Worked Example: `ShadowAndMarkTactic`

To see how clean a tactic looks under this model, consider `ShadowAndMarkTactic`. This defensive behavior dynamically scales to defend with anywhere from **2 to 5 robots**:
* The first two robots shadow the direct shot line between the ball and the goal.
* Any remaining robots dynamically mark the nearest unmarked opposing attackers.

```python
class ShadowAndMarkTactic:
    tag = "defense"

    def tick(self, game, robot_ids, memory):
        commands = {}
        
        # 1. First two robots block the primary shot angle
        shadow_ids = robot_ids[:2]
        for robot_id in shadow_ids:
            commands[robot_id] = defend_shot_line(game, robot_id)

        # 2. Remaining robots match to nearest unmarked opponents
        marker_ids = robot_ids[2:]
        for robot_id in marker_ids:
            target = get_marking_position(game, robot_id)
            commands[robot_id] = go_to_point(game, robot_id, target)

        return commands, memory
```

Notice the key properties here:
1. **Dynamic robot counts**: The tactic works whether the scheduler allocates 2, 3, 4, or 5 robots without branching on team size.
2. **Never locks the scheduler**: Because marking positions are recomputed fresh every tick, it uses the default `is_committed() = False`. The scheduler can reassign any marker robot to a counter-attack the millisecond the ball is recovered.

---

## 4. The Three Safety Invariants

Allowing multiple tactics to run concurrently with dynamic robot reassignment could easily turn into a concurrency nightmare. To prevent this, the strategy kernel enforces **three strict safety invariants**:

![Multi-Robot Tactic Scheduling Timeline](/images/blog/tactic_scheduling_timeline.svg)

### Invariant 1: Single-Writer Partition (Safe by Construction)

> *Every tick, exactly one authority (the Partitioner) decides the disjoint allocation of all outfield robots across tactic slots before any tactic's `tick()` executes.*

By the time a tactic runs, its robot set is fixed, final, and guaranteed to be disjoint from every other tactic's set:

$$G_i \cap G_j = \emptyset \quad \forall \; i \ne j$$

**What breaks without it**: If two tactics could independently choose which robots to drive, whichever tactic wrote to the command map last would silently overwrite the other. This would introduce non-deterministic race conditions dependent entirely on Python dictionary iteration order.

### Invariant 2: `is_committed()` is an Absolute Veto (No Mid-Action Preemption)

> *While a tactic's `is_committed()` returns `True`, the scheduler is strictly prohibited from reassigning its robots to any other slot.*

There is no timeout and no forced eviction mechanism. If a striker is halfway through kicking a loose ball or a winger is sprinting to intercept an aerial chip, the scheduler guarantees those robots will not be yanked away to fulfill a defensive request.

**What breaks without it**: A scheduler that could preempt committed robots would constantly abort physically active actions on the carpet. Imagine a robot beginning a shot, only for the scheduler to reassign it to defense mid-swing because an opponent took two steps forward.

*(Design note: If a tactic contains a logic bug and remains committed forever, the scheduler does not use a timeout to paper over the bug. Instead, it logs a prominent warning every 100 consecutive ticks, identifying the buggy tactic so it can be fixed with a unit test).*

### Invariant 3: Barrier Resets on Referee Restarts (Uniform State Flush)

> *A referee restart (kickoff, ball placement, direct/indirect free kick, penalty) triggers an immediate, universal barrier reset across all tactic slots simultaneously.*

When the referee halts or restarts play, the kernel unconditionally resets all slots:
1. All tactic memory objects (`mem`) are flushed to `make_initial_mem()`.
2. All `is_committed()` locks are cleared.
3. During restart positioning (e.g. `BALL_PLACEMENT_THEIRS`), a dedicated `RefereeOverride` takes direct control of all outfield robots to enforce SSL positioning rules.
4. When normal play resumes, the partitioner starts from a completely clean slate.

**What breaks without it**: If resets were partial or targeted, a tactic that began a pass right as the whistle blew could remain committed across the stoppage, attempting to complete an illegal kick during the opponent's ball placement. Universal barrier resets eliminate the possibility of stale tactical state bleeding across match phases.

---

## 5. Architectural Trade-offs & Frequently Asked Questions

When presenting this architecture, teammates and roboticists often challenge specific design decisions. Here are the core questions and why I landed where I did:

### Q1: Why not Sumatra’s greedy sequential claiming?
*Background: TIGERs Mannheim, one of the most successful SSL teams in the world, uses a framework called "Sumatra," where tactics sequentially claim robots based on a fixed priority hierarchy ($\tau_1 \succ \tau_2 \succ \dots \succ \tau_k$).*

In Sumatra, Tactic 1 claims as many robots as it wants, then Tactic 2 claims from the leftovers, and so forth. While effective, greedy sequential claiming tightly couples tactical priority to evaluation order. If Tactic 1 gets greedy, Tactic 2 is starved without any global mediation. 

In this model, the `Partitioner` acts as an impartial scheduler: it inspects the whole field globally and decides the entire team split simultaneously. This makes team-wide tactical balances (such as *"always maintain at least two defenders, regardless of offensive opportunities"*) trivial to enforce as pure mathematical invariants.

### Q2: Why not a continuous bidding/scoring system?
*Why don't tactics output a float confidence score (e.g. `fit = 0.87`), allowing the scheduler to run an optimization auction?*

Self-reported float scores are **structurally unfalsifiable**. A tactic optimizing its own confidence in isolation—especially one authored by an autonomous AI agent without human review—has every incentive to report high confidence to claim robots. 

Worse, scalar scores create a false sense of mathematical precision while hiding miscalibration. Instead of continuous bids, the architecture asks two falsifiable, binary questions:
* `applicable(game) -> bool`: An entry gate (*"Is it physically sensible for me to begin right now?"*)
* `is_committed(game, mem) -> bool`: An exit lock (*"Would interrupting me mid-action be disastrous?"*)

Both functions are deterministic, unit-testable Boolean predicates that can be verified in milliseconds.

### Q3: Why is the Goalkeeper scheduled separately?
In this architecture, Robot 0 (the Goalkeeper) is completely exempt from the tactic partitioner. The goalkeeper runs its own dedicated skill loop directly under the strategy runner. 

In SSL rules, the goalkeeper possesses special physical privileges (e.g., inside the penalty area, it cannot be charged, and opponent contact is an automatic red card). Combining the goalkeeper into the general outfield pool would risk dynamic partitioners accidentally pulling the goalie out of position during a tactical reshuffle. Keeping Robot 0 isolated protects the goal line by construction.

### Q4: Where do referee rules and custom set-piece overrides live?
Tactics should never have to know about SSL referee rulebooks—handling rules like keeping 0.5m away from the ball during `STOP` or executing ball placement would pollute tactical code with administrative edge cases.

Instead, referee handling is encapsulated directly at the `Strategy` level. Every tick, before running any tactics, the strategy checks whether an official referee command is active (such as `STOP`, `BALL_PLACEMENT_*`, `PREPARE_KICKOFF_*`, or `DIRECT_FREE_*`). If so, tactics are bypassed entirely and a dedicated referee engine takes over to position robots in compliance with the rulebook.

To support custom set pieces (such as a rehearsed offensive free-kick routine or a coordinated defensive wall), a strategy can supply optional override functions for specific referee commands—customizing restarts without tangling open-play tactics in referee code.

---

## Summary & What’s Next

Separating multi-robot software into **Tactics** and **Orchestration** transformed the strategy layer from an unmaintainable behavior tree into a robust, contract-driven system:
* **Tactics are independent**: Authors write small, focused group behaviors with private typed memory.
* **Orchestration is explicit**: The `Partitioner` makes global allocation decisions without mutating tactic state.
* **Safety is guaranteed by construction**: The single-writer partition, `is_committed()` locks, and universal barrier resets make concurrent multi-robot execution mathematically robust.

In my next and final post of this series, I will examine the biggest open frontier: **Scaling Strategy Search and Building Evaluators**. Once your software stack is modular and deterministic, how do you measure whether a tactical change actually improved team performance? And how can autonomous AI coding agents leverage this evaluation harness to search, benchmark, and improve strategies automatically?

---

*Interested in multi-agent coordination, robot operating systems, or autonomous sports? First Order Robotics is recruiting Imperial students—check out the team's repositories or reach out to get involved!*
