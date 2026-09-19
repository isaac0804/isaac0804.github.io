---
title: "Leading Software for a Robot Football Team"
date: 2026-09-17T00:00:00Z
draft: false
tags: ["Robotics", "RoboCup", "Software Architecture", "Python", "Autonomous Systems"]
summary: "An architectural overview of our RoboCup Small Size League robot control stack, lessons from our Great Exhibition Road Festival milestone, and open challenges as we scale to a full 6v6 squad."
cover:
    image: images/blog/festival_2.jpg
    alt: "Two autonomous robots playing 1v1 football live on carpet at the Great Exhibition Road Festival"
    relative: false
---

*By Isaac, First Order Robotics Team*

---

I lead software for **First Order Robotics**, our student-led team competing in RoboCup's Small Size League (SSL). In the SSL, teams of small, fast, omnidirectional (holonomic) robots play autonomous football against each other.

I am writing this post as both an architectural overview of our codebase and a roadmap of where we are heading. As we prepare for upcoming competitions, we are actively recruiting new students (particularly from Imperial College London) to join the team and tackle ambitious robotics problems across motion planning, simulation, computer vision, and embedded systems. In this post, I want to walk through the major components of our software stack, the reasons behind my design choices, and the open challenges we are solving next.

---

## 1. Background: The Game, The Team, and the June Milestone

RoboCup SSL matches are fully autonomous: once the referee signals kickoff, the entire system runs without human intervention. Robots accelerate at up to $3\text{–}4\text{ m/s}^2$, kick golf balls at up to $6.5\text{ m/s}$, and execute decisions at 60 Hz. Within each 16-millisecond tick window, the software stack must ingest vision tracking, parse referee states, update obstacle avoidance paths, and compute wheel velocities for the entire squad.

The league presents a unique set of engineering constraints:
* **The Field**: A carpeted field measuring up to $9\text{ m} \times 6\text{ m}$ (in Division B, 6 robots per side).
* **The Hardware**: Custom 4-wheel omnidirectional robots equipped with brushless drive motors, an infrared ball-detection beam, a powered rubber dribbler roller to hold the ball, and high-voltage solenoid kickers (both flat kicks and 45-degree chip kicks).
* **Global Sensing**: Overhead cameras send raw frame data to an external tracking server (`SSL-Vision`), which computes filtered $(x, y, \theta)$ poses for all robots and the ball.
* **The Referee**: A software referee box (`GameController`) broadcasts match states: kickoffs, indirect and direct free kicks, penalty kicks, halt and stop commands, and ball placement coordinates.

![System Architecture](/images/blog/system_architecture.svg)

### A milestone at the Great Exhibition Road Festival

Prior to this summer, much of our work was focused on getting individual subsystems to work in isolation—bench-testing motor control, verifying radio packet transmission, or testing basic path planning in simulation. We barely had a full 6v6 strategy because our immediate priority was getting the physical foundation off the ground.

That changed in **June 2026** at Imperial's **Great Exhibition Road Festival**, where we demonstrated our team's first full-stack software-to-hardware integration on **two physical robots** live on the carpet.

![Autonomous robots live on carpet at the Great Exhibition Road Festival](/images/blog/festival_1.jpg)

Seeing the complete end-to-end loop come alive in public—from overhead camera tracking to host strategy and real motor actuation—was a massive milestone for our team. It proved that our core concepts worked, and it gave us the momentum to double down and put serious engineering effort into scaling up. 

To take the leap from a 2-robot demonstration to a competitive 6v6 squad at RoboCup, we needed a robust software foundation: fast and deterministic simulation, resilient motion planning, and a modular architecture for tactical coordination. The systems described below represent the fruit of that effort over the past few months.

---

## 2. Environments, Refereeing, and Determinism

RoboCup SSL has a strong open-source culture, and we were able to build on community tools. In our software stack, we use:
1. **`rsoccer_simulator` (rsim)**: A lightweight, headless 2D simulator that allows us to run matches much faster than real time.
2. **`grSim`**: A 3D simulator using Open Dynamics Engine (ODE), which provides higher-fidelity physical interactions like ball bounce and wheel slip.

However, using multiple simulators alongside real hardware easily leads to messy branching logic if not decoupled carefully.

### Decoupling simulation and hardware: `StrategyRunner`

If strategy code contains checks like `if is_sim:` or `elif is_real_hardware:`, the logic paths diverge, and tests run in simulation stop reflecting real behavior.

To solve this, we unified all targets behind a single loop interface: **`StrategyRunner`**.

```python
# StrategyRunner exposes an identical tick contract across all environments
runner = StrategyRunner(
    strategy=my_strategy,
    env=sim_or_hardware_env,
    referee=custom_or_network_referee,
)
runner.run()
```

The strategy layer receives a normalized `Game` snapshot and returns a dictionary of `RobotCommand` objects (`target_velocity`, `kick_speed`, `dribbler_rpm`). Whether those commands are converted into UDP packets for rsim/grSim or serialized over radio to an on-robot microcontroller is completely invisible to the tactics layer.

### In-process refereeing: `CustomReferee`

During real matches, an external `GameController` process sends referee commands over the network. But running an external referee server during automated unit test runs or 200-match headless tournament sweeps introduces network latency, port management issues, and test brittleness.

We implemented **`CustomReferee`**: an in-process referee engine enforcing the SSL rulebook (§8.3 and §8.4):
* **Foul tracking**: Excessive dribbling distance ($>1.0\text{ m}$ without releasing), pushing fouls, exceeding speed limits under STOP ($1.5\text{ m/s}$ ), and ball placement interference.
* **Restarts**: Managing transitions (`PREPARE_KICKOFF` $\to$ `NORMAL_START`, `STOP` $\to$ `DIRECT_FREE`, `BALL_PLACEMENT`).
* **Foul escalation**: Tracking double touches, team foul counters, and card issuance.

Running the referee inside the test process makes full-game evaluation deterministic and fast.

### Deterministic diagnosis: The Replay System

In a 60 Hz multi-robot system, bugs rarely announce themselves cleanly. A robot might stall against an obstacle boundary, or a referee rule might issue a false-positive foul 45 seconds into a match. Trying to diagnose these issues from raw console logs is nearly impossible.

To make matches debuggable, we built a two-part replay pipeline:
1. **Columnar Replays (`.npz`)**: Instead of pickling Python objects every tick—which creates massive files and slow load times—`ColumnarReplayWriter` dumps dense numerical arrays across time slices. Loading a full match takes milliseconds.
2. **Intention Logs (`.intentions.jsonl`)**: Beside the physical coordinates, we record high-level decision changes: which tactic owned which robot, what target was selected, and why a transition fired.

With `repro_from_replay.py` and the web dashboard's Replay tab, we can step through any match tick-by-tick, inspect robot intentions, and deterministically reproduce subtle edge cases.

### Physical fidelity and simulator edge cases

Simulators simplify physics, and those simplifications can mask bugs or create artificial ones:
* **The sticky dribbler**: In standard rsim, an active dribbler could trap the ball indefinitely, ignoring the physical forces that cause a ball to slip off a roller during sharp turns. We authored and applied an upstream patch (`rSim-dribbler-release.diff`) so the ball releases realistically under lateral acceleration.
* **Sensor jitter and restarts**: In simulation, minor coordinate jitter on a stationary ball during a direct free kick caused planners to believe the target was moving, triggering expensive replans every tick. Fixing this required adding target hysteresis tolerances rather than relying on exact equality.

---

## 3. Motion Planning: Evolution and Open Challenges

Once a tactic assigns goals to robots, the motion planner must calculate collision-free trajectories that respect velocity and acceleration limits. Over the team's history, our motion planning architecture has gone through several iterations:

1. **Early on: Naive PID Control**: Our first system used simple PID tracking directed straight toward the target point. This works fine on an open field, but offers zero obstacle avoidance.
2. **The Hybrid Step: DWA + PID**: To dodge obstacles, we adopted a Dynamic Window Approach (DWA) variant paired with PID velocity tracking. DWA samples achievable $(v_x, v_y, \omega)$ velocity windows over a short forward time horizon. While this avoided static collisions, it introduced high per-tick computational overhead (consuming up to $1.0\text{–}1.5\text{ ms}$ per robot), and its short lookahead horizon struggled with narrow corridors.
3. **Last Year: FastPathPlanner (FPP)**: To cut latency and achieve global routing, we transitioned to FastPathPlanner (FPP)—a geometric visibility-graph planner that computes line-of-sight waypoints and smooths them. FPP reduced compute time to $<0.2\text{ ms}$ per tick.

### Gaps we observed with FPP

While FPP is fast, practical match testing revealed critical limitations:
* **Local minima in crowded scenes**: In dense 6v6 scenarios (such as mirrored restarts), FPP's carrot-following waypoint logic can get trapped in local minima. Robots stall $0.5\text{ m}$ short of their targets because obstacle safety envelopes overlap.
* **Dynamic crossing conflicts**: FPP plans for each robot independently and treats other moving robots as static circular obstacles. When two robots cross paths at right angles, neither anticipates the other's velocity vector, frequently leading to collisions.

### Where we are heading: Trajectory Sampling & Benchmarking

We are currently exploring more robust motion planning paradigms:
* **Trajectory Sampling (`trajsample`)**: Inspired by the world-champion **TIGERs Mannheim** architecture, this approach generates 1D and 2D Bang-Bang acceleration profiles, uses adaptive-timestep collision checking, and implements explicit priority-based yielding (`robot_id` or tactical urgency) so crossing robots cleanly yield to each other.
* **Model Predictive Control (MPC)**: Formulating trajectory generation as a constrained optimization problem to handle actuator saturation and momentum natively.
* **A Unified Motion Benchmark**: We recently began building standardized scenario test benches (`tools/motion_planning_benchmark.py`) to measure completion times, path length efficiency, clearance margins, and controller latency across algorithms under deterministic conditions.

Tuning and comparing these algorithms under real-time constraints is one of the most exciting technical challenges on our roadmap.

---

## 4. Strategy Design: Tactics and Orchestration

In our earlier stack, strategy was built on **Behavior Trees (BT)** using the `py_trees` library. Behavior trees are standard in game AI and single-robot robotics, but as our team grew, the BT approach became painful to work with, both conceptually and practically:

* **The single-agent mismatch**: A behavior tree naturally models the decision hierarchy of *one* agent. In 6v6 soccer, you either maintain six independent trees (which makes multi-robot coordination like a give-and-go pass or a zonal defensive wall nearly impossible to synchronize), or a single monolithic tree managing all six robots simultaneously.
* **The "Blackboard" trap**: A monolithic multi-robot tree requires nodes to communicate by reading and mutating shared variables on a global blackboard. In practice, this created hidden state couplings, execution-order race conditions, and bugs that were brutal to reproduce.
* **Dynamic regrouping fights the tree structure**: Football is fluid. Two robots might run an offensive overlap while three hold a defensive shape; a second later, the ball spills loose, and the robots regroup into two pressing defenders and two retreating markers. Representing dynamic, temporary multi-robot squads inside a fixed tree hierarchy led to a tangled web of custom decorators and priority switches.

We replaced the behavior tree entirely with a clean separation of concerns: **Tactics** and **Orchestration**.

### The OS Scheduler Model

Instead of a giant tree, we model our team after an **operating system kernel**:

![The OS Scheduler Model](/images/blog/os_scheduler_model.svg)

This maps directly to computer systems concepts:
* **Tactics are Processes**: A `Tactic` is an isolated micro-behavior for a small group (e.g. `GiveAndGoTactic`, `PressAndContainTactic`, `DefensiveWallTactic`). It has its own private state memory, zero global blackboards, and doesn't know or care how many other tactics exist.
* **Robots are CPU Cores**: Outfield robots are the scarce compute resource allocated to tactics.
* **Strategy is the OS Scheduler**: Every tick, the strategy runs a pure `Partitioner` function that inspects the field situation and decides which free robots to assign to which tactic slots.
* **`is_committed()` is a Mutex / Non-preemptible Section**: When a tactic begins a time-critical action (e.g., a striker mid-kick or a receiver expecting a pass), it declares `is_committed() = True`. The scheduler guarantees those robots will not be preempted or reassigned until the action completes.

### Barrier resets on referee restarts

One problem with stateful tactics is handling sudden referee interruptions. If two robots are in the middle of an offensive pass and the referee calls a foul, what happens to their committed state?

![Multi-Robot Tactic Scheduling Timeline](/images/blog/tactic_scheduling_timeline.svg)

Reading each horizontal row as a single robot's timeline over time reveals how the scheduler behaves:
* In **Phase 1**, Robot 0 guards the goal, Robots 1 & 2 run an attacking play (`GiveAndGo`), while Robots 3–5 press and hold the defensive line.
* In **Phase 2**, Robots 1 & 2 lock themselves with `🔒 is_committed()` to execute the shot without being interrupted. Meanwhile, because Robot 4 is free, the scheduler dynamically reassigns it to support the play.
* At **$t_9$**, an unexpected referee whistle triggers a universal **Barrier Reset** across all six rows simultaneously—wiping tactic memories and commitment locks unconditionally.
* In **Phase 3**, normal play resumes, and the partitioner allocates completely fresh tactical squads from a clean slate.

*(Note: For a detailed look at the protocol interfaces, mathematical properties, and scheduling invariants, see the dedicated companion post: [Strategy = Tactics × Orchestration](/posts/2026-09-18-strategy-tactics-orchestration/).)*

---

## 5. Looking Ahead: Open Engineering Challenges

To expand from our initial 2-robot testbed toward a full 6-robot squad and compete at RoboCup, there is a wide range of open engineering problems to solve. Our team is actively recruiting Imperial College students across robotics, software, and embedded systems to lead these projects:

* **Vision calibration and multi-camera merging**: Merging 4 overhead camera fields into a single, distortion-free coordinate frame. Building automated calibration routines to eliminate boundary stitching seams and compensate for lens distortion across the carpet.
* **Automated pre-flight hardware diagnostics**: Before putting physical robots on the carpet, running automated self-tests over radio. This includes monitoring motor current curves to detect jammed omni-wheels, measuring dribbler motor back-EMF/resistance to flag worn rubber rollers, and verifying solenoid kicker capacitor charging profiles.
* **Motion planning benchmark & algorithm development**: Transitioning beyond FastPathPlanner’s geometric visibility graph. Expanding our standardized motion planning test bench, improving Trajectory Sampling obstacle models, and exploring Model Predictive Control (MPC) formulations for high-speed multi-robot interception.
* **Simulation fidelity**: Bridging the sim-to-real gap by improving dribbler friction modeling and contact dynamics in rsim/grSim so tactical maneuvers translate faithfully to the real carpet.
* **Embedded comms & radio firmware**: Hardening our 2.4 GHz nRF/radio protocol pipeline to minimize packet drop rates and compensate for latency between vision ingestion on the host PC and motor execution on our microcontrollers.

---

## Summary & What’s Next

Building an autonomous robot football stack requires careful separation of concerns:
* **Decouple strategy from execution environments** early with a unified runner interface.
* **Enforce referee rules in-process** to keep test loops fast, self-contained, and deterministic.
* **Separate strategic allocation from local robot execution**, modeling multi-robot play like an operating system scheduler.

In my next post, I will tackle the next frontier: **Scaling Strategy Search and Building Evals**. In sparse-reward sports like robot football, how do you reliably evaluate whether a tactical change made your team better? I will dive into evaluator design, scenario harvesting, and how a deterministic software stack enables an **agentic coding workflow**—where autonomous AI agents benchmark, debug, and propose tactical improvements alongside human engineers.

---

*Interested in robotics, motion planning, embedded systems, or autonomous multi-agent strategy? First Order Robotics is recruiting Imperial students—get in touch with us to get involved!*
