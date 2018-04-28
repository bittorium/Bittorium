# daemon runs in the background
# run something like tail /var/log/PinkstarcoinV2d/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/PinkstarcoinV2d:/var/lib/PinkstarcoinV2d -v $(pwd)/wallet:/home/pinkstarcoinv2 --rm -ti pinkstarcoinv2:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG PINKSTARCOINV2_VERSION=v0.4.3
ENV PINKSTARCOINV2_VERSION=${PINKSTARCOINV2_VERSION}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev \
      librocksdb-dev && \
    git clone https://github.com/pinkstarcoinv2/pinkstarcoinv2.git /src/pinkstarcoinv2 && \
    cd /src/pinkstarcoinv2 && \
    git checkout $PINKSTARCOINV2_VERSION && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/PinkstarcoinV2d /usr/local/bin/PinkstarcoinV2d && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/simplewallet /usr/local/bin/simplewallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/PinkstarcoinV2d && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/simplewallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/pinkstarcoinv2 && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the PinkstarcoinV2d service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/PinkstarcoinV2d PinkstarcoinV2d && \
    useradd -s /bin/bash -m -d /home/pinkstarcoinv2 pinkstarcoinv2 && \
    mkdir -p /etc/services.d/PinkstarcoinV2d/log && \
    mkdir -p /var/log/PinkstarcoinV2d && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/PinkstarcoinV2d/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/PinkstarcoinV2d/run && \
    echo "cd /var/lib/PinkstarcoinV2d" >> /etc/services.d/PinkstarcoinV2d/run && \
    echo "export HOME /var/lib/PinkstarcoinV2d" >> /etc/services.d/PinkstarcoinV2d/run && \
    echo "s6-setuidgid PinkstarcoinV2d /usr/local/bin/PinkstarcoinV2d" >> /etc/services.d/PinkstarcoinV2d/run && \
    chmod +x /etc/services.d/PinkstarcoinV2d/run && \
    chown nobody:nogroup /var/log/PinkstarcoinV2d && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/PinkstarcoinV2d/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/PinkstarcoinV2d/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/PinkstarcoinV2d" >> /etc/services.d/PinkstarcoinV2d/log/run && \
    chmod +x /etc/services.d/PinkstarcoinV2d/log/run && \
    echo "/var/lib/PinkstarcoinV2d true PinkstarcoinV2d 0644 0755" > /etc/fix-attrs.d/PinkstarcoinV2d-home && \
    echo "/home/pinkstarcoinv2 true pinkstarcoinv2 0644 0755" > /etc/fix-attrs.d/pinkstarcoinv2-home && \
    echo "/var/log/PinkstarcoinV2d true nobody 0644 0755" > /etc/fix-attrs.d/PinkstarcoinV2d-logs

VOLUME ["/var/lib/PinkstarcoinV2d", "/home/pinkstarcoinv2","/var/log/PinkstarcoinV2d"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/pinkstarcoinv2 export HOME /home/pinkstarcoinv2 s6-setuidgid pinkstarcoinv2 /bin/bash"]
