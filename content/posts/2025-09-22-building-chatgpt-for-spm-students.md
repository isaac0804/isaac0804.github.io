---
title: "I Built a 'ChatGPT' for SPM Students"
date: 2025-09-22T00:00:00Z
draft: false
tags: ["spm-chat", "ai", "education", "startup"]
summary: "I built an AI chatbot for SPM students. Here's what I learned about marketing, small language models, community, and fumbling a beta launch."
cover:
  image: /images/blog/spm-chat-cover.jpg
  alt: "SPM Chat architecture: Student → Curated Context + Small LM → Accurate Answer"
  caption: "The secret is in the context, not the model size."
---

I made a ChatGPT for SPM students. This post is a mix of what I learned building it, and what went wrong (and right) when I launched it to real students.

## Why SPM Chat?

Two problems I wanted to solve:

1. **ChatGPT is not as helpful to SPM students** as it is to university students and coders. It just doesn't have enough context about the Malaysian syllabus.
2. **There is no centralized platform for SPM academic resources** -- notes, essays, scholarship information. I want SPM Chat to be this platform, and from this perspective, there are countless opportunities lying ahead.

I had previously built an SPM essay sharing platform that was growing steadily through RedNote and Telegram. Everything was seemingly on the right track, until my ADHD brain decided to start a new project.

## Some Learnings

### 1. Marketing from day one

Since the day I started writing the code, I shared some updates on RedNote and immediately gained lots of enquiries and support, even suggestions and feature requests. These signals helped me align my ideas with what students actually need. Plus, I got a group of early users to skip the "cold start" phase. Bad memories from my previous project -- I don't want to go through that again.

### 2. Small language model + curated context is the future

Contrary to our daily experience (I know your GPT-5 Pro Max is thinking in the background right now), small language models are much more scalable and powerful than you might think. And do expect a cheaper, smarter, longer context window model coming -- many such cases. So, what really matters is your context. Know your users inside out, get experts in that domain, and curate the "secret recipe" for your model.

> Good model + bad context < Ok model + good context

<div style="max-width: 600px; margin: 2em auto; font-family: inherit;">
  <div style="display: flex; align-items: stretch; gap: 0; justify-content: center;">
    <!-- Student -->
    <div style="background: #e8f4f8; border: 2px solid #4a9ebb; border-radius: 10px; padding: 14px 18px; text-align: center; min-width: 90px; display: flex; align-items: center; justify-content: center;">
      <div>
        <div style="font-size: 1.5em;">🎓</div>
        <div style="font-weight: 600; font-size: 0.85em; margin-top: 4px;">Student</div>
      </div>
    </div>
    <!-- Arrow -->
    <div style="display: flex; align-items: center; padding: 0 6px;">
      <div style="font-size: 1.4em; color: #888;">→</div>
    </div>
    <!-- SPM Chat box -->
    <div style="border: 2px solid #6b5ce7; border-radius: 12px; padding: 0; overflow: hidden; flex: 1; max-width: 360px;">
      <div style="background: #6b5ce7; color: white; padding: 8px 14px; font-weight: 600; font-size: 0.85em; text-align: center;">
        SPM Chat
      </div>
      <div style="display: flex; gap: 10px; padding: 14px; justify-content: center; flex-wrap: wrap;">
        <div style="background: #f0edff; border: 1.5px solid #6b5ce7; border-radius: 8px; padding: 10px 14px; text-align: center; flex: 1; min-width: 120px;">
          <div style="font-size: 0.75em; color: #666; text-transform: uppercase; letter-spacing: 0.5px;">Context</div>
          <div style="font-size: 0.82em; margin-top: 6px; line-height: 1.4;">
            📚 Syllabus<br>
            📝 Past papers<br>
            🎯 Subject notes
          </div>
        </div>
        <div style="background: #f0edff; border: 1.5px solid #6b5ce7; border-radius: 8px; padding: 10px 14px; text-align: center; flex: 1; min-width: 120px;">
          <div style="font-size: 0.75em; color: #666; text-transform: uppercase; letter-spacing: 0.5px;">Small LM</div>
          <div style="font-size: 0.82em; margin-top: 6px; line-height: 1.4;">
            ⚡ Fast<br>
            💰 Cheap<br>
            🎯 Focused
          </div>
        </div>
      </div>
    </div>
    <!-- Arrow -->
    <div style="display: flex; align-items: center; padding: 0 6px;">
      <div style="font-size: 1.4em; color: #888;">→</div>
    </div>
    <!-- Answer -->
    <div style="background: #e8f8e8; border: 2px solid #4abb5c; border-radius: 10px; padding: 14px 18px; text-align: center; min-width: 90px; display: flex; align-items: center; justify-content: center;">
      <div>
        <div style="font-size: 1.5em;">✅</div>
        <div style="font-weight: 600; font-size: 0.85em; margin-top: 4px;">Accurate<br>Answer</div>
      </div>
    </div>
  </div>
  <p style="text-align: center; font-size: 0.8em; color: #888; margin-top: 12px; font-style: italic;">The secret is in the context, not the model size.</p>
</div>

### 3. Claude Code + GLM 4.5 + Happy

Cost: $3 (GLM Coding plan). Claude Code has a steeper learning curve than Cline, but it can be really powerful with MCP configurations properly set up. It is faster and cheaper than my previous Cline + Deepseek V3 setup, and lets me work remotely with Happy app.

## How I Fumbled the Launch

<div style="max-width: 580px; margin: 1.5em auto 2em; font-family: inherit;">
  <div style="position: relative; padding-left: 28px;">
    <!-- Vertical line -->
    <div style="position: absolute; left: 8px; top: 8px; bottom: 8px; width: 3px; background: linear-gradient(to bottom, #4a9ebb, #e74c3c, #f39c12, #6b5ce7, #e74c3c); border-radius: 2px;"></div>
    <!-- Prelaunch -->
    <div style="position: relative; margin-bottom: 20px;">
      <div style="position: absolute; left: -24px; top: 4px; width: 14px; height: 14px; background: #4a9ebb; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 0 2px #4a9ebb;"></div>
      <div style="background: #e8f4f8; border-radius: 8px; padding: 10px 14px;">
        <div style="font-weight: 600; font-size: 0.85em;">🚀 Prelaunch</div>
        <div style="font-size: 0.8em; color: #555; margin-top: 2px;">Hundreds join the RedNote group</div>
      </div>
    </div>
    <!-- Launch -->
    <div style="position: relative; margin-bottom: 20px;">
      <div style="position: absolute; left: -24px; top: 4px; width: 14px; height: 14px; background: #e74c3c; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 0 2px #e74c3c;"></div>
      <div style="background: #fde8e8; border-radius: 8px; padding: 10px 14px;">
        <div style="font-weight: 600; font-size: 0.85em;">💥 Sep 16, 8pm — Launch</div>
        <div style="font-size: 0.8em; color: #555; margin-top: 2px;">API quota burned, students yelling in group chat</div>
      </div>
    </div>
    <!-- Feedback -->
    <div style="position: relative; margin-bottom: 20px;">
      <div style="position: absolute; left: -24px; top: 4px; width: 14px; height: 14px; background: #f39c12; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 0 2px #f39c12;"></div>
      <div style="background: #fef6e4; border-radius: 8px; padding: 10px 14px;">
        <div style="font-weight: 600; font-size: 0.85em;">🐛 Feedback flood</div>
        <div style="font-size: 0.8em; color: #555; margin-top: 2px;">404s, broken profiles, markdown bugs — students found them all</div>
      </div>
    </div>
    <!-- Poll -->
    <div style="position: relative; margin-bottom: 20px;">
      <div style="position: absolute; left: -24px; top: 4px; width: 14px; height: 14px; background: #6b5ce7; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 0 2px #6b5ce7;"></div>
      <div style="background: #f0edff; border-radius: 8px; padding: 10px 14px;">
        <div style="font-weight: 600; font-size: 0.85em;">📊 The 98% poll</div>
        <div style="font-size: 0.8em; color: #555; margin-top: 2px;">Students want subject selection — not magic routing</div>
      </div>
    </div>
    <!-- Apocalypse -->
    <div style="position: relative;">
      <div style="position: absolute; left: -24px; top: 4px; width: 14px; height: 14px; background: #e74c3c; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 0 2px #e74c3c;"></div>
      <div style="background: #fde8e8; border-radius: 8px; padding: 10px 14px;">
        <div style="font-weight: 600; font-size: 0.85em;">☠️ RedNote group nuked</div>
        <div style="font-size: 0.8em; color: #555; margin-top: 2px;">400+ member group shut down — Telegram backup saves the day</div>
      </div>
    </div>
  </div>
</div>

### Prelaunch

I created a group chat on RedNote, inviting interested students for product updates in hope of receiving their feedback. Within a few days, hundreds of students joined. I figured, why not send a link to them and let them have a try?

So I said, SPM Chat will be launched on September 16th, 8pm!!

Ohh boi. Do not try this at home if your app has some sort of limit per minute or per day.

### Rocky start

The app suffered massive outage at launch. The sudden spike in API usage fully consumed my daily free quotas. Even worse, my fallback mechanism that routes requests to other providers was flawed. So, the first hour of the launch was just students yelling at me in the group chat.

At least they care, right? ... right?

### Feedback coming in

After the app was working properly, I actually did not expect any more feedback. However, bug reports and feature requests started popping up -- mysterious 404 errors when changing language, profile page not loading, markdown rendering issues, chat rename not working. I was surprised (and somewhat ashamed). Without this group of students, it would have taken me ages to spot all these bugs. They were even helping newcomers onboard the app.

I figured, I should expand this community. Instead of staying only on RedNote, maybe I should create a Telegram group too. Also, for backup. (Spoiler alert.)

### Surprise request

Students started discussing about the user experience, and they asked me, "can I choose a specific subject before I start a conversation?"

I was shocked. I had wanted to create a magical experience -- ask a question and it just works, all the routing and context selection handled under the hood. I thought maybe it was just taste difference among the students, so I created a poll.

Turns out **98% of the students want to have finer control** over what context they are chatting with the bot. And by giving them that control, I got to reduce the latency and API calls. Win-win situation. I started clauding immediately.

### Apocalypse, well not exactly

The group with 400+ members got shut down because of violation to RedNote community guidelines. Weird people slipped in and posted random unrelated stuff -- I guess this triggered some students to report the group. It's bad, but luckily there was the Telegram group as backup. I quickly created another group on RedNote and started directing the traffic there. TBH, I was tired at this point.

## What's Next

It is really fun to work on a project that actually benefits people. There are many more things for me to learn, to make this a truly valuable app for the students. Some questions for myself:

1. **Community** -- How do I maintain a community in a positive atmosphere, free from bots and ads?
2. **Testing** -- How do I set up a testing environment to capture severe bugs before pushing into production? It is forgivable at the start, but as the number of users grows, I definitely need some way to facilitate it.
3. **Sustainability** -- What should I do when the cost grows beyond my budget? This is a hobby / research project. But if you know anyone interested in sponsoring or helping students with free education, do let me know!
