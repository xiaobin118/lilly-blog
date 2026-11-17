---
title: "Sigmoid 网络为什么会梯度消失"
description: "从连乘的雅可比矩阵到实测梯度范数，理解梯度消失与激活、优化器的关系"
date: 2026-10-22
tags: [machine-learning, cnn, pytorch]
type: note
topic: "机器学习"
project: cnn
---

梯度消失常被描述成「sigmoid 导数最大只有 0.25」，但真正的问题是它在深层网络里被反复相乘。反向传播时，第 1 层的梯度要穿过后面每一层的雅可比矩阵：

$$
\frac{\partial\mathcal{L}}{\partial W^{(1)}}=\frac{\partial\mathcal{L}}{\partial Z^{(L)}}\prod_{\ell=2}^{L}\frac{\partial Z^{(\ell)}}{\partial Z^{(\ell-1)}}\frac{\partial Z^{(1)}}{\partial W^{(1)}}
$$

如果每层因子的谱范数都小于 1，乘积会指数衰减。sigmoid 在输入绝对值较大时导数接近 0，叠加最大池化与不合适的初始化，前几层几乎收不到有效梯度。

实验里的对照很直接：SGD、学习率 0.01、训练 6 轮，Sigmoid 网络的测试准确率只有 11.35%，接近十分类随机水平；第一层卷积的梯度范数约 \(9.3\times10^{-5}\)，而 ReLU 网络约 \(1.0\times10^{-2}\)，相差两个数量级。把优化器换成 Adam 后，同一个 Sigmoid 网络能到 89.82%，说明梯度消失不是「激活函数一票否决」，而是激活、初始化、优化器共同作用的结果。

工程上的处理顺序通常是：先用 ReLU 或 LeakyReLU 与合适的初始化（He/Kaiming），再加 BatchNorm，最后才考虑换优化器或加深网络。诊断时不要只看损失曲线，直接打印每层梯度范数，能更快定位是哪一层开始衰减。
