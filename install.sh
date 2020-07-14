#!/usr/bin/bash
# Install WRF + dependencies on an OpenHPC system (and spack but could fix that).
# Prerequisites are modules for gnu7/7.3.0, openmpi3/3.1.0, hdf5/1.10.2.
# Assumes no root access.
# Each section is set up so it can be rerun stand-alone, but the order of sections is important.


# will install into this OpenHPC-style tree:
export INSTALL_ROOT=$HOME/gnu-7.3.0/openmpi-3.1.0/
mkdir -p $INSTALL_ROOT
mkdir $HOME/src # will use for builds which can't be done in the install tree

# spack install `time`:
spack install time

# install zlib:
cd $INSTALL_ROOT
wget https://zlib.net/zlib-1.2.11.tar.gz
tar xf zlib-1.2.11.tar.gz 
cd zlib-1.2.11
module load gnu7/7.3.0 openmpi3/3.1.0 hdf5/1.10.2
./configure --prefix=$INSTALL_ROOT/zlib-1.2.11/
make check
make install

# parallel-netcdf:
cd src
wget https://parallel-netcdf.github.io/Release/pnetcdf-1.12.0.tar.gz
tar -xf pnetcdf-1.12.0.tar.gz
cd pnetcdf-1.12.0
module load gnu7/7.3.0 openmpi3/3.1.0 hdf5/1.10.2
./configure --prefix=$INSTALL_ROOT/pnetcdf-1.12.0/ --enable-shared
make check
make install

# netcdf-c:
# NB this is actually required even when using parallel-netcdf, despite some posts that you don't
# NB: Needs build options parallel (non-default) and shared libs (default)
# NB: Can't be built in its install directory
cd $HOME/src
wget https://github.com/Unidata/netcdf-c/archive/v4.7.1.tar.gz
tar xf v4.7.1.tar.gz 
mv v4.7.1.tar.gz netcdf-c-4.7.1.tar.gz 
cd netcdf-c-4.7.1
module load gnu7/7.3.0 openmpi3/3.1.0 hdf5/1.10.2
export ZDIR=$INSTALL_ROOT/zlib-1.2.11/
export PNDIR=$INSTALL_ROOT/pnetcdf-1.12.0/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HDF5_LIB
CC=mpicc CPPFLAGS="-I${HDF5_INC} -I${ZDIR}/include -I${PNDIR}/include" LDFLAGS="-L${HDF5_LIB} -L${ZDIR}/lib -L${PNDIR}/lib" ./configure --prefix=$INSTALL_ROOT/netcdf-c-4.7.1 --disable-dap --enable-pnetcdf --enable-parallel
make check
make install

# netcdf-f:
cd $HOME/src
wget ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-fortran-4.5.2.tar.gz
tar -xf netcdf-fortran-4.5.2.tar.gz
cd netcdf-fortran-4.5.2
module load gnu7/7.3.0 openmpi3/3.1.0 hdf5/1.10.2
export NCDIR=$INSTALL_ROOT/netcdf-c-4.7.1/
export LD_LIBRARY_PATH=${NCDIR}/lib:${LD_LIBRARY_PATH}
export NFDIR=$NCDIR # install dir for netcdf-f; wrf expects netcdf-c and netcdf-f to be in same place
CC=mpicc FC=mpifort CPPFLAGS=-I${NCDIR}/include LDFLAGS=-L${NCDIR}/lib ./configure --prefix=${NFDIR}
# (NB if you don't set CC/FC to mpi* you get warning that netcdf-c has parallel i/o but gfortran doesn't support it)
make check
make install

# WRF:
cd $INSTALL_ROOT
wget --no-check-certificate https://www2.mmm.ucar.edu/wrf/src/WRFV3.8.1.TAR.gz # cert expired
tar -xf WRFV3.8.1.TAR.gz
mv WRFV3 WRFV3.8.1
cd WRFV3.8.1
module load gnu7/7.3.0 openmpi3/3.1.0 hdf5/1.10.2
export PNETCDF=$INSTALL_ROOT/pnetcdf-1.12.0
export ZDIR=$INSTALL_ROOT/zlib-1.2.11/
export HDF5=$HDF5_DIR
export NETCDF=$INSTALL_ROOT/netcdf-c-4.7.1/
spack load time
./clean -a
./configure # pick "dmpar for gcc", then default nesting
# modify the generated config:
dm_cc_line='DM_CC           =       mpicc -DMPI2_SUPPORT'
sed -i "s/^DM_CC\s*=.*/${dm_cc_line}/" configure.wrf
./compile em_real 2>&1 | tee real1.log
# RUNNING ...
