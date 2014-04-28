deepnet
=======

## Implementation of some deep learning algorithms. ##

GPU-based python implementation of

1.  Feed-forward Neural Nets
2.  Restricted Boltzmann Machines
3.  Deep Belief Nets
4.  Autoencoders
5.  Deep Boltzmann Machines
6.  Convolutional Neural Nets

Built on top of the [cudamat](http://code.google.com/p/cudamat/) library by
Vlad Mnih and [cuda-convnet](http://code.google.com/p/cuda-convnet/) library by
Alex Krizhevsky.


## Build on Windows ##

Instructions:

- Install [Python Tools for Visual Studio](https://pytools.codeplex.com/)
- Install CUDA (tested on CUDA 6.0).
- Compile [cudamat](http://code.google.com/p/cudamat/)
  - From the cudamat directory run: "nmake -f Makefile.win"
- Compile [eigen-mat](#eigenmat)
  - From the eigenmat directory run: "nmake -f Makefile.win". The automated process will download [Eigen3](http://eigen.tuxfamily.org/), Powershell 3.0 and .Net 4.5 if they are not available (those 2 are needed to automate the rest).
- Open the solution and enjoy.


Pull requests are welcome. 
