---
title: "FID 低不一定更好：生成模型的记忆化"
description: "为什么小数据量下 FID 反而更低，以及评价生成模型时该同时看哪些指标"
date: 2026-11-04
tags: [machine-learning, generative-models, fid]
type: note
topic: "机器学习"
project: generative-models
---

FID 用 Inception 特征比较真实分布与生成分布，数值越低通常表示越接近。公式是

$$
\mathrm{FID}=\lVert\mu_r-\mu_g\rVert_2^2+\mathrm{Tr}\left(\Sigma_r+\Sigma_g-2(\Sigma_r\Sigma_g)^{1/2}\right)
$$

它只看特征的一阶、二阶统计量，不看生成样本是否真的「新」。当训练数据很少时，模型可能直接背训练图，特征分布当然接近真实分布，FID 反而更低。

实验里出现过这种情况：训练集只有 1,000 张时，某个 GAN 配置的 FID 是 163.3，比数据量更大时还低；但最近邻距离与真实图基线的比值只有 0.920，说明生成样本离训练图很近。数据量增加到全量后，比值升到 0.945，FID 反而变差，但生成的东西更像「新图」。

所以评价生成模型不能只看一个数。比较不同数据量或不同模型时，至少同时看 FID、最近邻距离、C2ST 和抽样目检；FID 的参考集、生成样本数和采样步数也要固定，否则数字之间不可比。

同一套流程下，扩散模型的 FID 是 20.0，DCGAN 是 92.7，VAE 是 203.1；但扩散模型生成 1,000 张样本需要约 168 秒（DDIM-50），而 GAN 与 VAE 在 0.1 秒量级。质量、成本与多样性必须一起看。
