#!/bin/bash 

source modules_cuda 
autoreconf -f -i 
./configure --enable-openaccc-managed #--enable-openacc-stdpar
nf-config --all 
make install
