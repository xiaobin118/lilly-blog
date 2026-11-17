---
title: "kmeans.py 代码 review"
description: "被检查的文件：code/kmeans.py"
date: 2026-10-13
tags: [machine-learning, code-review]
type: note
topic: "机器学习"
---

被检查的文件：`code/kmeans.py`

结论：**四个函数的实现全部正确，通过了全部验收标准，并且精确复现了参考实现的数值**（包括那个失败案例）。下面先列出验证结果，再讲三个需要修的问题，最后是可选改进。

## 一、验证结果

### 1.1 验收标准逐条通过

| 标准 | 要求 | 你的结果 | 判定 |
|---|---|---|---|
| seed=0 收敛轮数 | 5 轮 | 5 轮 | 通过 |
| seed=0 最终 inertia | 3570.5 | 3570.51 | 通过 |
| seed=0 最优匹配准确率 | 1.0000 | 1.0000 | 通过 |
| inertia 单调不增 | 是 | True | 通过 |
| 10 次重启的分布 | 1 次掉坑 | seed=3 得 18063.7 | 通过 |

### 1.2 三个"数值指纹"完全对上

这比"结果看起来对"强得多。你的实现和参考实现在下面三处给出了**完全相同的数值**：

第一个是 `seed=3` 的局部最优值 **18063.7**（其余 9 个种子都是 3570.5）。这个值依赖于"随机挑哪三个点"这一具体序列，能和参考实现对上是强证据。

第二个是讲义 02 里那组坏初始化在 90 点数据集上的结果。用 `seed=11`：

```
你的实现  : J = 1049.67  各簇点数 [16, 20, 54]
参考实现  : J = 1049.6741  各簇点数 [16, 20, 54]
```

两者一致。也就是说**你的实现能复现"错误答案"**——这正是讲义 02 练习 5 的要求，说明实现与算法在数值层面一致，而不是碰巧得到了正确结果。

第三个是 `assign_clusters` 用广播构造 $(N,K,D)$ 差张量的写法。你写的是

```python
diff = X[:, None, :] - centroids[None, :, :]   # (N, K, D)
dist2 = np.sum(diff ** 2, axis=2)              # (N, K)
labels = np.argmin(dist2, axis=1)              # (N,)
```

这是标准写法，两个 `None` 的位置都对：`X[:, None, :]` 把样本数放到第 0 维、簇数维度插入第 1 维，`centroids[None, :, :]` 把簇数放到第 1 维，广播后得到"每个样本对每个中心"的差。`axis=2` 对特征维求和、`axis=1` 沿簇维取 argmin，也都对。没有写双重循环。

### 1.3 空簇防护确实有意义（我构造了退化场景验证）

你的 `counts[j] > 0` 判断是必要的，但它在常规输入下几乎不会被触发——我用 1500 点数据跑了 60 次 $k=5$，**一次空簇都没出现**。原因是 `assign_clusters` 取的是 argmin，一个中心只要还有点是它最近的，就不会空；只有当它被别的中心完全"包住"时才会饿死。

真正高发的场景是**初始中心重合**。我构造了一组 $\mu_1=\mu_2=(0,0)$ 的初始中心，结果：

```
各簇点数: [1499, 0, 1]
无防护的均值计算: [[-0.28, -0.19], [nan, nan], [4.49, 5.76]]
```

第 1 簇一个点都没有，`X[labels == 1].mean(axis=0)` 对空数组求均值，同时抛出 `RuntimeWarning: Mean of empty slice` 并返回 `nan`。一旦 `nan` 进入中心矩阵，下一轮的 `assign_clusters` 会把它传播到整个距离矩阵，最终所有标签都变成 0，算法彻底失效。你的 `else: new_centroids[j] = centroids[j]` 挡住了这条路径，写法正确（保留旧中心而不是留下 `nan`）。

顺带说明：`np.bincount(labels, minlength=k)` 的 `minlength` 是必须的。如果最后一簇恰好是空的，`bincount` 返回的数组长度会小于 $k$，后面 `counts[j]` 就会 `IndexError`。你写对了。

## 二、需要修的问题

### 2.1 docstring 里残留了一行 `return labels`

`assign_clusters` 的 docstring 末尾是：

```
    Example:
        X = np.array([[0, 0], [1, 1], [2, 2]])
        centroids = np.array([[0, 0], [2, 2]])
        # diff = X[:, None, :] - centroids[None, :, :]  # (3, 2, 2)
        # dist2 = np.sum(diff ** 2, axis=2)  # (3, 2)
        # labels = np.argmin(dist2, axis=1)  # (3,)
        return labels  # array([0, 0, 1])
```

最后那行原本是示例的一部分，但它现在位于 docstring **内部**（缩进一致），所以 `help(assign_clusters)` 会把它当作说明文字打印出来，读起来像是"这个函数在这里返回"。函数的真实返回在 docstring 外面。删掉那一行，或者给它加上 `#` 注释前缀。

### 2.2 退出那一轮，返回的三个值互不自洽（**返回的 `centroids` 差了一次更新**）

这是唯一一个真正的逻辑问题。看你的循环：

```python
for i in range(max_iter):
    labels = assign_clusters(X, centroids)          # 用【旧】中心得到 labels
    new_centroids = ...
    shift = np.linalg.norm(new_centroids - centroids, axis=1).max()
    inertia = compute_inertia(X, labels, new_centroids)   # 用【新】中心算 J
    history.append(...)
    if shift < tol:
        break                                       # ← 这里直接退出
    centroids = new_centroids                        # 更新只发生在未退出时
return centroids, labels, inertia, history
```

问题在 `break` 的位置：退出时 `centroids` 还是**旧**的（因为赋值在 `break` 之后），而 `labels` 和 `inertia` 都已经是**新**中心对应的值。所以返回的三者是错位的。

我在 1500 点数据上实测了这一点：

```
返回的 labels 与"用返回的 centroids 重新分配"的结果相同吗: True
```

这次碰巧相同，所以没出问题——因为收敛时新中心和旧中心只差 0.015，边界上的点归属没变。但这个"碰巧"不可依赖：换一组数据、换一个更松的 `tol`，就可能出现"返回的中心和返回的标签其实是两次不同迭代的产物"，而且这种错误不会报错、不会产生 `nan`，只是结果微妙地不一致。

修法有两条，任选一条，关键是**别让返回值跨越两次迭代**。

第一条是把更新提到判断之前，让 `centroids` 始终保持为"最后一次算出的中心"：

```python
for i in range(max_iter):
    labels = assign_clusters(X, centroids)
    new_centroids = ...(含空簇防护)...
    shift = np.linalg.norm(new_centroids - centroids, axis=1).max()
    centroids = new_centroids
    inertia = compute_inertia(X, labels, centroids)
    history.append({'iter': i + 1, 'inertia': float(inertia), 'shift': float(shift)})
    if shift < tol:
        break
```

第二条是在退出前补一次分配，保证 `labels` 与最终 `centroids` 配套：

```python
if shift < tol:
    labels = assign_clusters(X, centroids)     # 用最终中心重新分配
    inertia = compute_inertia(X, labels, centroids)
    history[-1]['inertia'] = float(inertia)
    break
centroids = new_centroids
```

我推荐第一条：它少一次分配计算，而且 `history` 的语义更自然。注意我在里面同时做了两件小事，见下一条。

### 2.3 `history` 的语义：首轮记录的是"更新之后"的值，且 `iter` 从 0 开始

看你的实际输出：

```
{'iter': 0, 'inertia': 17034.61, 'shift': 4.167}
{'iter': 1, 'inertia': 6988.50,  'shift': 2.918}
{'iter': 2, 'inertia': 3585.92,  'shift': 1.445}
{'iter': 3, 'inertia': 3570.51,  'shift': 0.0153}
{'iter': 4, 'inertia': 3570.51,  'shift': 0.0}
```

问题在于第一条记录的不是"初始中心下的 $J$"。我验算过：

```
初始中心下的 J            = 32670.641
history 第 0 条记录的 J   = 17034.609
```

**真实起点 32670.6 没有出现在 history 里**，第一条记录的 17034.6 已经是做完一次更新之后的值了（因为 `inertia` 是用 `new_centroids` 算的）。后面画收敛曲线时，曲线会从 17034 开始，看起来下降得没有实际那么剧烈，首轮的信息丢了。

另外 `iter` 从 0 开始，而讲义 02 和实验报告里讲的都是"第 1 轮、第 2 轮"，如果直接把 `history` 的 `iter` 当横坐标画图，图上的轮次会比文字描述少 1。

建议：`iter` 用 `i + 1`；并且明确选定一种语义——要么记录"本轮分配后的 $J$"（用本轮的中心），要么记录"更新后的 $J$"，然后**在 docstring 里写清楚**。上面 2.2 的修法一采用的就是"更新后的 $J$ + `iter=i+1`"，这样序列是 $J_1, J_2, \dots$，与报告里的轮次编号一致。

如果你想让曲线包含真实的起点，可以在循环外用初始中心额外算一次 $J$ 放进 `history`，标成第 0 轮；但要注意这样 `len(history)` 就不再等于迭代次数了，画图和汇报时容易混淆，所以我更倾向于不这么做，而是在报告里单独说明起点值。

## 三、可选改进

### 3.1 让 `kmeans` 支持指定初始中心

现在 `kmeans(X, k, seed=...)` 只能通过 `seed` 间接控制初始化，没法直接传入初始中心。这在讲义 02 的练习里是个限制——我想复现"$\mu_1=\mu_2$"这种特定的坏初始化时，只能绕开你的函数、在外部手写循环。

加一个 `init=None` 参数即可，兼容现有调用：

```python
def kmeans(X, k, max_iter=100, tol=1e-6, seed=0, init=None):
    if init is None:
        rng = np.random.default_rng(seed)
        centroids = X[rng.choice(len(X), size=k, replace=False)].copy()
    else:
        centroids = np.array(init, dtype=float).copy()
        k = len(centroids)          # 以传入的中心个数为准，避免 k 与 init 冲突
```

这样就能写 `kmeans(X, k=3, init=X[[11, 71, 88]])` 来直接复现讲义里那个局部最优，报告里也方便做初始化对照实验（参考实现的 `gmm_em` 就有 `init` 参数）。

### 3.2 把 `np.float64` 转成 `float`

`inertia` 和 `shift` 目前是 NumPy 标量，所以自检脚本打印出来是 `np.float64(3570.5)` 而不是 `3570.5`。

这里我要更正上一条消息里我说错的一句话：我说这会导致 `json.dumps` 失败，**这是错的**。实测在 Python 3.13 下 `json.dumps({"inertia": np.float64(...)})` 完全正常，包括 `indent=2`。真正无法序列化的是 **`ndarray`**：

```
json.dumps({"centroids": best['centroids']})  ->  TypeError: Object of type ndarray is not JSON serializable
```

所以数组要转 `.tolist()`，而 NumPy 标量在当前 Python 版本下不需要特殊处理。不过在 `history` 里存 `float(inertia)`、`float(shift)` 仍然值得做：一是打印好看，二是万一以后换 Python 版本或换序列化库（不少库对 NumPy 类型的兼容性不如标准库），不会突然出问题。

### 3.3 变量名拼写

`kmeans_restarts` 里的 `all_iterias` 是 `all_inertias` 的笔误（`iteria` 不是词）。虽然只在函数内部使用，不影响运行，但 `inertia` 和 `iteration` 都以 `iter` 开头，这种拼写错误容易在之后的调试中造成混淆——看到 `iterias` 可能会误以为是"迭代次数"。顺手改掉。

### 3.4 `kmeans_restarts` 的 seed 传参

```python
for seed in range(n_init):
    centroids, labels, inertia, history = kmeans(X, k, seed=seed, **kwargs)
```

如果调用者写了 `kmeans_restarts(X, 3, n_init=10, seed=5)`，`seed` 会同时出现在显式参数和 `kwargs` 里，触发 `TypeError: got multiple values for keyword argument 'seed'`。参考实现里也踩过这个坑。稳妥的写法是先把 `seed` 从 `kwargs` 里摘掉，或者把循环变量改名并用 `functools.partial` 固定其他参数：

```python
kwargs.pop("seed", None)          # 忽略调用者传的 seed，重启时逐个覆盖
for s in range(n_init):
    centroids, labels, inertia, history = kmeans(X, k, seed=s, **kwargs)
```

### 3.5 一个更实用的空簇处理策略

你现在保留旧中心。更好的做法是 k-means 论文里的经典方案：**把空簇的中心放到"离它所属中心最远的那个点"上**，把这个点抢过来，让空簇重新获得一个点。

```python
if counts[j] == 0:
    # 找到当前离自己中心最远的点，占为这个空簇的第一个点
    far = np.argmax(np.sum((X - new_centroids[labels]) ** 2, axis=1))
    new_centroids[j] = X[far]
```

这个改动的效果是让 $K$ 真的能被用满，而不是留一个永远不动的死中心。不过它会让 $J$ 在那一轮**上升**（因为强行把远处的点划给了新中心），破坏教材里"$J$ 单调不增"的表述——所以如果报告里要展示单调性曲线，保留旧中心反而更干净。两种都能用，选择取决于你想演示哪一点；建议在代码注释里说明你的选择及理由。

## 四、小结

做得好的地方：`assign_clusters` 的广播写法一次到位；`compute_inertia` 用 `centroids[labels]` 索引避免了逐簇循环；空簇防护写对了（我构造退化场景验证过，没有防护会直接产生 `nan`）；三个数值指纹与参考实现完全一致。

需要修的：docstring 里残留的 `return labels`；退出轮的返回值错位（把 `centroids = new_centroids` 提到 `break` 之前）；`history` 的 `iter` 编号和首轮语义。

建议顺手做的：`kmeans` 加 `init` 参数，`all_iterias` 改名，`kmeans_restarts` 里处理 `seed` 冲突。

修完之后可以进入讲义 03。那一讲会用你已经能跑的实现来做实验：对比不同初始化方法的成败率、用肘部法和轮廓系数选 $K$、以及在没有标签的情况下怎么判断聚类结果可不可信。
