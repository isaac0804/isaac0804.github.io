---
title: "MidiBERT-Piano Paper"
date: 2022-08-23T14:37:05+08:00
draft: false

tags: ["Paper"]
---

## MidiBERT-Piano

### Contributions

- Compound word(CP) encoding is better than REMI encoding in general
- BERT-based model outperforms RNN-based model in following downstream tasks:
	- Melody extraction
	- Velocity Prediction
	- Composer Identification
	- Emotion classfication
- Pretraining perform much better than the model that train from scratch.

### Future work 

- Implement other pretraining method to further boost the performance and robustness. Personally, I think the recent [GLM](https://arxiv.org/pdf/2103.10360.pdf) paper is worth trying.
