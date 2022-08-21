---
title: "2022 07 04 Deep Learning Is Not Only About Training"
date: 2022-07-04T20:31:40+08:00
draft: true
---

When I first started learning deep learning, I thought the main part (or the fun part) is designing the network.
Many years later, I realized that there are so many things that are important in order to enable a deep learning project to run smoothly.
Based on my experience, without a proper environment and tools weel-prepared, it is time-consuming to conduct various experiments and is difficult to design a good deep learning project.
Here is some learning outcomes from my experience.

## Start small and add components as you need

It is not a good idea to start with a extra large model.
Instead, I recommend trying with a rather small neural network and let it run on the same batch for multiple times to see if it is able to converge.
This step is to prevent the potential bug such as wrong tensor operation or flaws in the loss function etc.
Remember, if a model is not able to converge in a small batch, something is wrong.

## 1. Data Pipeline

## 2. Visualization

## 3. Scheduler

## 4. Logger

## 5. Callback
