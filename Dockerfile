# version : 1 ( Testing )

FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei

RUN apt-get update && apt-get install -y \
    tzdata \
    bash \
    sudo \
    && ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*


ARG USERNAME=devuser
ARG UID=500
ARG GID=500
RUN groupadd --gid $GID $USERNAME \
    && useradd --uid $UID --gid $GID --create-home --shell /bin/bash $USERNAME \
    && usermod -aG sudo $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


USER $USERNAME


WORKDIR /home/$USERNAME
CMD ["/bin/bash"]


FROM base AS common_pkg_provider
USER root


RUN apt-get update && apt-get install -y \
    vim git curl wget ca-certificates build-essential \
    python3 python3-pip bzip2 \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*


ARG CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh; \
        echo "Found architecture: $ARCH"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O miniconda.sh; \
        echo "Found architecture: $ARCH"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    bash miniconda.sh -b -p $CONDA_DIR && \
    rm miniconda.sh && \
    ln -s $CONDA_DIR/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> /etc/bash.bashrc && \
    conda init bash


# verilator_provider
FROM common_pkg_provider AS verilator_provider
USER root

RUN apt-get update && apt-get install -y \
    git make autoconf g++ flex bison help2man \
    && git clone https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator && git checkout v5.024 \
    && autoconf && ./configure && make -j$(nproc) && make install \
    && rm -rf /tmp/verilator


#systemc_provider
FROM common_pkg_provider AS systemc_provider
USER root

RUN apt-get update && \
    apt-get install -y autoconf automake libtool && \
    rm -rf /var/lib/apt/lists/*

# WORKDIR /tmp
RUN cd /tmp && \
    wget https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz -O systemc-2.3.4.tar.gz && \ 
    tar -xzf systemc-2.3.4.tar.gz && \
    cd systemc-2.3.4 && \
    autoreconf -i && \
    mkdir build && cd build && \
    ../configure --prefix=/opt/systemc && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/systemc-2.3.4*

# Copy the eman script to the container
COPY ./eman.sh /usr/local/bin/eman
RUN chmod +x /usr/local/bin/eman

# base + all packages
FROM base AS final
USER root


COPY --from=common_pkg_provider /opt/conda /opt/conda
COPY --from=common_pkg_provider /etc/profile.d/conda.sh /etc/profile.d/conda.sh
COPY --from=common_pkg_provider /usr /usr
COPY --from=verilator_provider /usr/local /usr/local
COPY --from=systemc_provider /opt/systemc /opt/systemc


ENV PATH=/opt/conda/bin:$PATH

USER $USERNAME

WORKDIR /home/$USERNAME
CMD ["/bin/bash"]