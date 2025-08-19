import matplotlib.pyplot as plt
import numpy as np

# 读取 IQ 数据
data = np.loadtxt("constellation_output.txt")
I = data[:, 0]
Q = data[:, 1]

# 绘制星座图
plt.figure(figsize=(6,6))
plt.plot(I, Q, 'o', markersize=2)
plt.title("Constellation Diagram")
plt.xlabel("In-Phase (I)")
plt.ylabel("Quadrature (Q)")
plt.grid(True)
plt.axhline(0, color='gray', linestyle='--')
plt.axvline(0, color='gray', linestyle='--')
plt.axis("equal")
plt.savefig("constellation.png")
plt.show()
