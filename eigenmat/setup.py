from setuptools import setup, find_packages
import os, sys

if os.name == 'nt':
    ret = os.system("nmake -f Makefile.win")
else:
    ret = os.system("make")
if ret != 0:
    sys.exit(ret)
    

setup(
    name="eigenmat",
    version="0.1",
    description="Eigen matrix support for Python",
    license="BSD",
    keywords="EIGEN MATRIX",
    packages=find_packages(),
    include_package_data=True,
)