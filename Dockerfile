# daemon runs in the background
# run something like tail /var/log/Bittoriumd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/Bittoriumd:/var/lib/Bittoriumd -v $(pwd)/wallet:/home/Bittorium --rm -ti Bittorium:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG BITTORIUM_VERSION=v0.4.3
ENV BITTORIUM_VERSION=${BITTORIUM_VERSION}

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
    git clone https://github.com/bittorium/Bittorium /src/Bittorium && \
    cd /src/Bittorium && \
    git checkout $BITTORIUM2_VERSION && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/Bittorium /usr/local/bin/Bittorium && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/simplewallet /usr/local/bin/simplewallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/Bittorium && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/simplewallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/Bittorium && \
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

# setup the Bittoriumd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/Bittoriumd Bittoriumd && \
    useradd -s /bin/bash -m -d /home/Bittorium Bittorium && \
    mkdir -p /etc/services.d/Bittoriumd/log && \
    mkdir -p /var/log/Bittoriumd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/Bittoriumd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/Bittoriumd/run && \
    echo "cd /var/lib/Bittoriumd" >> /etc/services.d/Bittoriumd/run && \
    echo "export HOME /var/lib/Bittoriumd" >> /etc/services.d/Bittoriumd/run && \
    echo "s6-setuidgid Bittoriumd /usr/local/bin/Bittoriumd" >> /etc/services.d/Bittoriumd/run && \
    chmod +x /etc/services.d/Bittoriumd/run && \
    chown nobody:nogroup /var/log/Bittoriumd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/Bittoriumd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/Bittoriumd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/Bittoriumd" >> /etc/services.d/Bittoriumd/log/run && \
    chmod +x /etc/services.d/Bittoriumd/log/run && \
    echo "/var/lib/Bittoriumd true Bittoriumd 0644 0755" > /etc/fix-attrs.d/Bittoriumd-home && \
    echo "/home/Bittorium true Bittorium 0644 0755" > /etc/fix-attrs.d/Bittorium-home && \
    echo "/var/log/Bittorium true nobody 0644 0755" > /etc/fix-attrs.d/Bittoriumd-logs

VOLUME ["/var/lib/Bittoriumd", "/home/Bittorium","/var/log/Bittoriumd"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/Bittorium export HOME /home/Bittorium s6-setuidgid Bittorium /bin/bash"]
