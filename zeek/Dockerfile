FROM zeek/zeek:latest

RUN apt update && \
    apt install -y \
      iproute2 \
      iputils-ping \
      net-tools \
      tcpdump \
      less \
      nano \
      vim \
      && apt clean && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /zeek-logs /zeek-scripts
