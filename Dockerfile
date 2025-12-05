# Dockerfile for MonoLaneMapping
# 基于ROS Noetic (Ubuntu 20.04)
FROM ros:noetic-ros-base-focal

# 设置非交互模式和时区
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 更换apt源为阿里云（可选，加速下载）
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    python3-tk \
    git \
    wget \
    vim \
    libboost-all-dev \
    libeigen3-dev \
    libmetis-dev \
    libtbb-dev \
    cmake \
    build-essential \
    ros-noetic-eigen-conversions \
    ros-noetic-tf \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# 升级pip
RUN pip3 install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装Python依赖 (注意：empy需要使用3.3版本以兼容ROS)
RUN pip3 install --no-cache-dir --ignore-installed -i https://pypi.tuna.tsinghua.edu.cn/simple \
    numpy \
    scipy \
    open3d \
    jaxlie \
    pyyaml \
    tqdm \
    matplotlib \
    easydict \
    "empy==3.3.4" \
    catkin_pkg \
    rospkg \
    pycryptodomex

# 安装GTSAM (预编译版本，更快)
RUN pip3 install --no-cache-dir gtsam -i https://pypi.tuna.tsinghua.edu.cn/simple || \
    (cd /tmp && \
    git clone https://github.com/borglab/gtsam.git && \
    cd gtsam && \
    git checkout 4.2 && \
    mkdir build && cd build && \
    cmake .. -DGTSAM_BUILD_PYTHON=ON \
             -DGTSAM_PYTHON_VERSION=3.8 \
             -DCMAKE_BUILD_TYPE=Release \
             -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
             -DGTSAM_BUILD_TESTS=OFF && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && rm -rf gtsam)

# 设置GTSAM路径
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"

# 创建catkin工作空间
RUN mkdir -p /catkin_ws/src
WORKDIR /catkin_ws/src

# 克隆openlane_bag消息包
RUN git clone https://github.com/qiaozhijian/openlane_bag.git

# 编译openlane_bag
WORKDIR /catkin_ws
RUN /bin/bash -c "source /opt/ros/noetic/setup.bash && catkin_make"

# 创建启动脚本
RUN echo '#!/bin/bash\n\
source /opt/ros/noetic/setup.bash\n\
source /catkin_ws/devel/setup.bash\n\
export PYTHONPATH="/workspace/MonoLaneMapping:${PYTHONPATH}"\n\
exec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh

# 设置工作目录
WORKDIR /workspace

# 设置入口点
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
