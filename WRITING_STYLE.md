# Isaac's Writing Style & Voice Guide

A concise reference for maintaining Isaac's authentic voice across blog posts, technical essays, and documentation.

---

## Core Philosophy: Pragmatic Engineering Realism

The overarching persona is **an experienced, intellectually honest engineer talking directly to a peer over coffee**. 

The tone is grounded, calm, understated, and reflective. It avoids tech-influencer hype, corporate buzzwords, and dramatic theatrics. It lets real-world engineering constraints carry the narrative weight.

---

## The Six Defining Pillars

### 1. Allergic to Melodrama and Theatrical Hype
* **Rule**: Never use dramatic movie-trailer hooks, artificial tension, or cliché AI pauses.
* **Why**: The actual physical constraints (60 Hz control loops, 4 m/s² acceleration, battery thermal throttling) are already interesting on their own merits.
* **Avoid**: *"There is no human. There is no remote control. Just cold, calculating steel."*
* **Prefer**: *"RoboCup SSL matches are fully autonomous: once the referee signals kickoff, the entire system runs without human intervention."*

### 2. The Conversational Punch (Understatement)
* **Rule**: Use short, quiet, punchy declarations that land with high impact.
* **Why**: Understatement conveys confidence. Let the implications speak for themselves rather than over-explaining.
* **Examples**:
  * *"That sounds small. It is not."*
  * *"Was it overkill for a hobby project? Probably. Do I check it every single day now? Also yes."*
  * *"Total user count feels good to look at, but honestly it's a vanity metric."*

### 3. Radical Intellectual Honesty (No Ego)
* **Rule**: Openly document what failed, what was humbling, and where initial assumptions were wrong.
* **Why**: Anyone can claim their architecture is brilliant. Real credibility comes from candidly explaining what broke, why it broke, and what was learned.
* **Example**: *"The retention chart humbled me... I would have been celebrating growth while ignoring a leaky bucket. (Not a great feeling, but better to know than not know)."*
* **Rule on legacy tools**: When critiquing previous systems (like Behavior Trees), don't trash-talk them. Explain why they made sense initially (e.g. 1v1 play) and specifically why they broke down at scale (6v6).

### 4. Skepticism of Over-Engineering (The Discipline of Simplicity)
* **Rule**: Instinctively resist premature generalization. Avoid building elaborate meta-schedulers or abstract frameworks in anticipation of hypothetical future needs.
* **Why**: Premature abstraction introduces complex configuration layers that obscure behavior and hide bugs.
* **Example**: *"I spent a lot of time thinking about this, and have decided that it is probably not worthy to build a system that can cover all different schedulers' need... but still I put tag here as an example, but if anyone has better idea, they can add this."*

### 5. Code as Explanation, Not as a Flex
* **Rule**: Strip heavy type machinery, generic constraints, and compiler boilerplate from blog code blocks.
* **Why**: Readers want the **mental model** (Inputs $\to$ Decision $\to$ Outputs), not Python typing gymnastics.
* **Avoid**: `Partitioner = Callable[[Game, frozenset[RobotId], ...], dict[TacticId, frozenset[RobotId]]]`
* **Prefer**:
  ```python
  # The Partitioner: divides free robots among candidate tactics
  allocations = partitioner(game, free_robots)
  # -> e.g. {"strike_play": [1, 2], "shadow_and_mark": [3, 4, 5]}
  ```

### 6. Empirical and Falsifiable (Metrics Over Vibes)
* **Rule**: Never settle for aesthetic claims like *"it feels cleaner"* or *"the passing looks crisper."* Anchor claims in quantifiable metrics.
* **Dimensions to measure**:
  * **Static complexity**: Lines of code, cyclomatic complexity branches, indirection hops to answer a debugging question.
  * **Type leverage**: Bugs caught statically at compile time vs silent runtime failures.
  * **Behavioral benchmarks**: Task success rates under seed-paired simulation (holding physics and random seeds identical across runs).

---

## Perspective & Attribution Guidelines

* **Use `"I"` for**:
  * Architectural leadership and design rationale (*"I separated the problem...", "I modeled the scheduler..."*)
  * Personal reflections and realizations (*"In my view...", "The retention chart humbled me..."*)
  * Authorship and documentation (*"In this post, I want to explore..."*)
* **Use `"we"` for**:
  * Physical team implementation (*"We built...", "We integrated...", "Our hardware team..."*)
  * Collective tournament matches and public milestones (*"We demonstrated our robots at the Great Exhibition Road Festival..."*)

---

## Quick Tone Checklist Before Publishing

1. [ ] Is the opening direct and contextual, without dramatic movie-trailer phrasing?
2. [ ] Are failure modes, trade-offs, and design limits honestly acknowledged?
3. [ ] Are code snippets ultra-clean and easy to parse in under 10 seconds?
4. [ ] Does the piece avoid corporate buzzwords, excessive exclamation marks, and emoji overload?
5. [ ] Are claims backed by concrete metrics or observable behavior rather than "vibe checks"?
