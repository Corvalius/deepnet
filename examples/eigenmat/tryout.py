from package.eigenmat import eigenmat as mat
import matplotlib.pyplot as plot
import numpy as np

# Ensuring that eigenmat works. 
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