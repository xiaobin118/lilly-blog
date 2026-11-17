---
title: 生成模型
description: DCGAN、卷积 VAE 与 DDPM 扩散模型的从零实现与三方对比
date: 2026-11-03
status: done
tech: [Python, PyTorch, CUDA]
repo: https://github.com/xiaobin118/HIT_ML_Lab/tree/main/experiment6
---

目标是用 PyTorch 从零实现三种生成式模型——DCGAN、卷积变分自编码器与 DDPM 扩散模型，在 64×64 的动漫头像上训练并做三方对比。

实现包括 GAN 的生成器与判别器、训练循环与采样，VAE 的重建项与 KL 项，扩散模型的 U-Net、余弦噪声调度、参数 EMA 与 DDIM 采样。评价使用 FID、C2ST 判别测试、最近邻距离、颜色多样性与采样成本，并分析了激活函数、Dropout、数据量、潜维、学习率、批大小与标签平滑的影响。

结果上，扩散模型的 FID 为 20.0，明显优于 DCGAN 的 92.7 与 VAE 的 203.1。代价是采样速度：生成 1,000 张样本，扩散模型用 DDIM-50 需要约 168 秒，而 GAN 与 VAE 都在 0.1 秒量级。

报告还记录了一个反直觉现象：训练数据只有 1,000 张时 FID 反而最低，因为模型在背训练图；最近邻比值随数据量上升，说明生成质量与记忆化程度需要分开评价，单看 FID 会得出错误结论。
