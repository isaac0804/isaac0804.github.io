---
title: "2022 08 21 AI Music Part 1"
date: 2022-08-21T20:17:24+08:00
draft: true
---

## Project Outline

Transformer will be used as the base model for the music generation in midi space.
I am also thinking to train a separate wav2vec 2 model in waveform space and a CLIP model to bridge the gap between these two domains.
But let's focus on in midi space first.

## Dataset

For midi dataset, I will be using MAESTRO v3 dataset for this project, which include 1276 midi files divided into train, validation and test sets.

