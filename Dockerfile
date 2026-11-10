FROM quay.io/jupyter/datascience-notebook:fda564ccbdd6

# Install basic packages and libraries as root
USER root

# Setup required packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    # Utility
    vim nano tzdata tree eog git git-lfs wget curl tar bzip2 build-essential \
    # Cmake, fortran, python
    cmake cmake-curses-gui gfortran zlib1g-dev python3-dev python3-pip python3-venv python-is-python3 \
    # PyHOPE
    libxft-dev libxfixes3 \
    # ParaView setup
    mesa-common-dev libglu1-mesa-dev libgl1-mesa-dev libegl1-mesa-dev \
    qtbase5-dev qt5-qmake libqt5x11extras5-dev libqt5opengl5-dev libqt5help5 qtbase5-dev-tools qttools5-dev qtxmlpatterns5-dev-tools libqt5svg5-dev && \
    # Clean image
    apt-get clean -y && apt-get autoremove -y --purge && rm -rf /var/lib/apt/lists/*


# Setup OpenBLAS, ensure cross-platform portability by building library for multiple targets and detecting CPU at runtime (DYNAMIC_ARCH=ON)
RUN OPENBLAS_VERSION=0.3.30 && cd /tmp && \
    wget https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v${OPENBLAS_VERSION}.tar.gz && \
    tar -xvf v${OPENBLAS_VERSION}.tar.gz && \
    cd OpenBLAS-${OPENBLAS_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt -DDYNAMIC_ARCH=ON .. && \
    make -j$(nproc) && cmake --install . && \
    cd /tmp && rm -rf OpenBLAS* && rm -rf v${OPENBLAS_VERSION}.tar.gz

# Setup OpenMPI
RUN OPENMPI_VERSION=5.0.8 && cd /tmp && \
    wget https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-${OPENMPI_VERSION}.tar.bz2 && \
    tar -xvf openmpi-${OPENMPI_VERSION}.tar.bz2 && \
    cd openmpi-${OPENMPI_VERSION} && \
    ./configure --prefix=/opt && \
    make -j$(nproc) && make install && \
    ldconfig && \
    cd /tmp && rm -rf openmpi*

# Setup HDF5
RUN HDF5_VERSION=1.14.6 && cd /tmp && \
    wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_${HDF5_VERSION}/hdf5-${HDF5_VERSION}.tar.gz && \
    tar -xvf hdf5-${HDF5_VERSION}.tar.gz && \
    cd hdf5-${HDF5_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt \
    -DHDF5_BUILD_FORTRAN=ON \
    -DHDF5_ENABLE_PARALLEL=ON \
    -DHDF5_USE_ZLIB_STATIC=ON \
    -DZLIB_USE_EXTERNAL=ON \
    .. && \
    make -j$(nproc) && cmake --install . && \
    cd /tmp && rm -rf hdf5*

# Setup FFTW
RUN FFTW_VERSION=3.3.10 && cd /tmp && \
    wget https://fftw.org/fftw-${FFTW_VERSION}.tar.gz && \
    tar -xvf fftw-${FFTW_VERSION}.tar.gz && \
    cd fftw-${FFTW_VERSION} && \
    ./configure --prefix=/opt && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf fftw*

# Setup CGNS
RUN CGNS_VERSION=4.4.0 && cd /tmp && \
    wget https://github.com/CGNS/CGNS/archive/refs/tags/v${CGNS_VERSION}.tar.gz && \
    tar -xvf v${CGNS_VERSION}.tar.gz && \
    cd CGNS-${CGNS_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt \
    -DCGNS_ENABLE_FORTRAN=ON \
    -DCGNS_ENABLE_64BIT=ON \
    -DCGNS_BUILD_SHARED=OFF \
    -DCGNS_USE_SHARED=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCGNS_BUILD_CGNSTOOLS=OFF \
    -DCGNS_ENABLE_HDF5=ON \
    -DHDF5_NEED_MPI=ON \
    -DCGNS_ENABLE_PARALLEL=OFF \
    -DCGNS_ENABLE_TESTS=OFF \
    -DCMAKE_SKIP_RPATH=ON \
    .. && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf v* CGNS-*

# Setup ParaView
# Ubuntu24 apt-repository provides v5.11.2 which suffers from XML-parsing bug (https://discourse.paraview.org/t/i-cannot-read-a-vtp-file-i-could-open-yesterday-can-someone-try-to-open-it/13938)
COPY FileParser_5_9_0.patch .
RUN PARAVIEW_VERSION=5.13.3 && cd /tmp && \
    wget https://www.paraview.org/files/v${PARAVIEW_VERSION%??}/ParaView-v${PARAVIEW_VERSION}.tar.gz && \
    tar -xvf ParaView-v${PARAVIEW_VERSION}.tar.gz && \
    cd ParaView-v${PARAVIEW_VERSION} && \
    mv ../../FileParser_5_9_0.patch . && patch -p0 < FileParser_5_9_0.patch && \
    mkdir build && cd build/ && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DPARAVIEW_USE_MPI=ON \
    -DPARAVIEW_INSTALL_DEVELOPMENT_FILES=ON \
    -DPARAVIEW_USE_PYTHON=ON \
    -DVTK_MODULE_USE_EXTERNAL_VTK_hdf5=ON \
    -DHDF5_IS_PARALLEL=ON \
    -DHDF5_DIR=/opt/cmake \
    -DCMAKE_INSTALL_PREFIX=/opt \
    ../ && \
    make -j $(nproc) && make install && \
    cd /tmp && rm -rf ParaView*

# Add examples for paraview visualizations
# From: https://www.paraview.org/files/data/ParaViewTutorialData-20220629.tar.gz    
RUN mkdir /examples && \
    cd /examples && \
    wget https://www.paraview.org/files/data/ParaViewTutorialData-20220629.tar.gz && \
    tar -xvf ParaViewTutorialData-20220629.tar.gz --strip-components=1

# Setup OpenFoam
# From: https://gitlab.com/openfoam/core/openfoam/-/wikis/precompiled/debian

# Add the repository
RUN apt-get update && apt-get install -y wget gnupg lsb-release && \
    curl -s https://dl.openfoam.com/add-debian-repo.sh | bash && \
    # Update the repository information
    apt-get update && \
    # Install preferred package. Eg,
    apt-get install -y openfoam2412 && \
    # Clean image
    apt-get clean -y && \
    apt-get autoremove -y --purge && \
    rm -rf /var/lib/apt/lists/*

# Add OpenFoam environment
RUN echo "source /usr/lib/openfoam/openfoam2412/etc/bashrc" >> /etc/bash.bashrc


###
##
# Configuring jupyter
##
###

# Necessary to call paraview via terminal in the desktop (vnc)
ENV PATH="/opt/bin:$PATH"

# Set working directory when launching container and set up vim
WORKDIR /home/${NB_USER}
COPY vimrc /home/${NB_USER}/.vimrc

# Create venv and enable it to allow for pip installations
RUN chown -R ${NB_UID}:${NB_GID} /home/${NB_USER}
USER ${NB_USER}
RUN python -m venv venv
USER root
ENV PATH="/home/${NB_USER}/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN pip install --no-cache-dir \
    numpy matplotlib h5py notebook jupyterlab jupyterhub ipykernel

# Install PyVista for basic visualization of VTU files within Jupyter
# https://github.com/pyvista/pyvista/tree/main/docker
RUN pip install --no-cache-dir \
    'pyvista[all]' 'ipywidgets<9.0.0' jupyter-server-proxy meshio trimesh 'trame>=2.5.2' 'trame-vtk>=2.5.8' 'trame-vuetify>=2.3.1'
# Enable JupyterLab in container, configure PyVista/Trame for remote Jupyter environment

ENV JUPYTER_ENABLE_LAB=yes \
    PYVISTA_TRAME_SERVER_PROXY_PREFIX='/proxy/'

# Install Jupyter-remote-desktop-proxy package to run XFCE desktop environment in Jupyter
# https://github.com/jupyterhub/jupyter-remote-desktop-proxy
RUN pip install --no-cache-dir jupyter-remote-desktop-proxy


# Install the packages needed to provide the VNC server (TigerVNC) and the actual Linux Desktop environment (Xubuntu)
#USER $NB_USER
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs npm dbus-x11 \
    # xclip is added as jupyter-remote-desktop-proxy's tests requires it
    xclip \
    # XFCE desktop environment
    xfce4 xfce4-panel xfce4-session xfce4-settings xorg xubuntu-icon-theme fonts-dejavu \
    # TigerVNC server
    tigervnc-standalone-server && \
    # Disable the automatic screenlock since the account password is unknown
    apt-get -y -qq remove xfce4-screensaver && \
    # chown $HOME to workaround that the xorg installation creates a /home/jovyan/.cache directory owned by root
    chown -R $NB_UID:$NB_GID $HOME && \
    rm -rf /var/lib/apt/lists/*


##
# Install Kernels:
# C/C++
# Fortran
##
RUN chown -R ${NB_UID}:${NB_GID} /home/${NB_USER}

USER ${NB_USER}

# C/C++
# From: https://github.com/shiroinekotfs/jupyter-cpp-kernel/tree/master
RUN pip install git+https://github.com/shiroinekotfs/jupyter-cpp-kernel.git

# Fortran
# From: https://github.com/ZedThree/jupyter-fortran-kernel/tree/master
RUN git clone https://github.com/ZedThree/jupyter-fortran-kernel.git && \
    pip install -e jupyter-fortran-kernel && \
    cd jupyter-fortran-kernel && \
    jupyter-kernelspec install --user fortran_spec/

WORKDIR /home/jovyan/work

# Switch (back) to user
USER ${NB_USER}