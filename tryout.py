from cudamat import cudamat as cm
from eigenmat import eigenmat as mat
from deepnet import * 
import numpy as np

# Ensuring that Cudamat is working. 
cm.cublas_init()

# create two random matrices and copy them to the GPU
a = cm.CUDAMatrix(np.random.rand(32, 256))
b = cm.CUDAMatrix(np.random.rand(256, 32))

# perform calculations on the GPU
c = cm.dot(a, b)
d = c.sum(axis = 0)

# copy d back to the host (CPU) and print
print( d.asarray() )


# Ensuring that eigenmat works. 
import matplotlib.pyplot as plot

plot.ion()
mat.EigenMatrix.init_random(seed=1)
plot.figure(1)
plot.clf()
x = mat.empty((100, 100))
x.fill_with_randn()
plot.hist(x.asarray().flatten(), 100)

plot.figure(2)
plot.clf()
y = np.random.randn(100, 100)
plot.hist(y.flatten(), 100)

input('Press Enter.')