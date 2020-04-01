# multiple build stages in order of change frequency instead of dependency, so
# updating the server does not require installing build/deploy packages, and
# updating the game does not require building the server

FROM debian:buster AS deploy-base

USER root

RUN groupadd minetest \
	&& useradd -m -g minetest -d /var/lib/minetest minetest \
	&& apt-get update -y \
	&& apt-get -y install \
	libc6 \
	libcurl3-gnutls \
	libjsoncpp1 \
	liblua5.1-0 \
	libluajit-5.1-2 \
	libpq5 \
	libsqlite3-0 \
	libstdc++6 \
	zlib1g

RUN apt-get clean \
	&& rm -rf /var/cache/apt/archives/* \
	&& rm -rf /var/lib/apt/lists/*

FROM deploy-base AS build-base

RUN apt-get update -y \
	&& apt-get -y install \
	build-essential \
	cmake \
	git \
	libbz2-dev \
	libcurl4-gnutls-dev \
	libgmp-dev \
	libirrlicht-dev \
	libjpeg-dev \
	libjsoncpp-dev \
	libpng-dev \
	libsqlite3-dev\
	zlib1g-dev

RUN apt-get clean \
	&& rm -rf /var/cache/apt/archives/* \
	&& rm -rf /var/lib/apt/lists/*

FROM build-base as build-server

COPY . /usr/src/minetest
RUN	mkdir -p /usr/src/minetest/cmakebuild \
	&& cd /usr/src/minetest/cmakebuild \
	&& cmake .. \
	-DBUILD_CLIENT=FALSE \
	-DBUILD_SERVER=TRUE \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr/local \
	-DENABLE_LUAJIT=TRUE \
	-DENABLE_POSTGRESQL=TRUE \
	-DENABLE_SOUND=FALSE \
	-DENABLE_SYSTEM_GMP=TRUE \
	-DENABLE_SYSTEM_JSONCPP=TRUE \
	-DPOSTGRESQL_CONFIG_EXECUTABLE=/usr/bin/pg_config \
	-DPOSTGRESQL_LIBRARY=/usr/lib/libpq.so \
	-DRUN_IN_PLACE=FALSE \
	&& make -j2 \
	&& rm -Rf ../games/minetest_game

RUN cd /usr/src/minetest/cmakebuild \
	&& make install

RUN git clone https://github.com/CivtestGame/civtest_game /usr/local/share/minetest/games/minetest_game

FROM deploy-base

COPY --from=build-server /usr/local/share/minetest /usr/local/share/minetest
COPY --from=build-server /usr/local/bin/minetestserver /usr/local/bin/minetestserver

COPY minetest.conf.example /etc/minetest/minetest.conf

WORKDIR /var/lib/minetest

USER minetest

EXPOSE 30000/udp

CMD ["/usr/local/bin/minetestserver", "--config", "/etc/minetest/minetest.conf"]
