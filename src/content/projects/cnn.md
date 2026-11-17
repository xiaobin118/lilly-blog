---
title: 卷积神经网络
description: PyTorch 在 GPU 上训练 LeNet-5 与 SmallVGG，系统分析训练技巧
date: 2026-10-21
status: done
tech: [Python, PyTorch, CUDA]
repo: https://github.com/xiaobin118/HIT_ML_Lab/tree/main/experiment5
---

目标是在 GPU 上用 PyTorch 构建并训练卷积网络，主模型是课程中的 LeNet-5，另做更深的 SmallVGG 对照，并系统分析各种训练技巧对结果的影响。

实验覆盖激活函数、Dropout 与权重衰减、训练数据量、优化器与学习率、批大小、旋转平移增强和旋转鲁棒性，最后做混淆矩阵、每类精确率与召回率、错分样本、卷积核、特征图与置信度分析。所有实验共用同一套训练引擎、数据划分和评估流程。

最终选出的 SmallVGG 配方在 MNIST 上用 3 个随机种子重复训练 15 轮，测试准确率 99.52% ± 0.07%，共 41 张测试图被分错；在 Fashion-MNIST 上，同一套 CNN 的准确率为 88.71%，比 MLP 高 0.66 个百分点。

报告里也记录了梯度消失的直接证据：在 SGD、学习率 0.01 的设置下，Sigmoid 网络训练 6 轮后测试准确率只有 11.35%，第一层卷积的梯度范数比 ReLU 小约两个数量级，换成 Adam 后可以恢复训练。
