---
title: "EM 算法为什么单调不降"
description: "用 Jensen 下界、E 步贴紧与 M 步最大化，解释 EM 每轮对数似然都不下降"
date: 2026-10-14
tags: [machine-learning, em-algorithm, clustering]
type: note
topic: "机器学习"
project: kmeans-gmm
---

EM 的单调性不是实验调出来的，而是由「下界 + 最大化」两步保证的。含隐变量 \(z\) 的对数似然是

$$
\ln p(X\mid\theta)=\sum_{n=1}^{N}\ln\sum_{k=1}^{K}\pi_k\mathcal{N}(x_n\mid\mu_k,\Sigma_k)
$$

对数里有求和，直接求导很难。引入一个任意分布 \(q(z)\)，用 Jensen 不等式得到

$$
\ln p(X\mid\theta)\ge\sum_{n}\sum_{k}q_{nk}\ln\frac{p(x_n,z_n=k\mid\theta)}{q_{nk}}
$$

等号在 \(q_{nk}=p(z_n=k\mid x_n,\theta)\) 时成立，这正是 E 步：用当前参数算责任度，把下界贴到似然上。M 步固定 \(q\)，对 \(\mu_k,\Sigma_k,\pi_k\) 最大化下界，于是下界上升；下一轮 E 步再用新参数重新贴紧。两步都只会让似然变大，所以迭代单调不降。

在合成数据上，对数似然从 -8189.31 升到 -5671.24，每一轮的增量都为正；用固定 \(q\) 计算的下界也同步上升，末轮与似然只差 \(9.09\times10^{-13}\)。这也解释了为什么 k-means 可以看作 GMM 在协方差趋近于零、责任度变成硬分配时的特例。

实现上有两个必须处理的数值问题：概率连乘会下溢，要在对数域用 log-sum-exp；某个分量只分到少量样本时协方差会接近奇异，需要加正则项 \(\epsilon I\)，否则似然可能发散到无穷。
