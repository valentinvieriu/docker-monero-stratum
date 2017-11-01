FROM alpine:3.6 as builder

ARG MONERO_VERSION=v0.11.1.0
ENV MONERO_VERSION $MONERO_VERSION
ENV MONERO_URL https://github.com/monero-project/monero.git
ENV MONERO_DIR /usr/src/monero
ENV MONERO_STRATUM_URL https://github.com/sammy007/monero-stratum.git
ENV MONERO_STRATUM_DIR /usr/src/monero-stratum

RUN apk --no-cache add                                                         \
	boost-dev                                                                  \
	cmake                                                                      \
	g++                                                                        \
	git                                                                        \
	go                                                                         \
	libressl-dev                                                               \
	make                                                                       \
	miniupnpc-dev                                                              \
	patch                                                                      \
	unbound-dev                                                                \
	zeromq-dev 

WORKDIR $MONERO_DIR
	
RUN git clone -b $MONERO_VERSION --depth 1 --single-branch $MONERO_URL .       

COPY easylogging.patch $MONERO_DIR/

RUN patch -p1 < easylogging.patch                                              \
 && cmake -DBUILD_SHARED_LIBS=1 -DARCH:STRING=x86-64 && make                   \
 && mkdir -p /build/lib/                                                       \
 && cp $MONERO_DIR/external/db_drivers/liblmdb/liblmdb.so /build/lib/          \
 && cp $MONERO_DIR/external/easylogging++/libeasylogging.so /build/lib/        \
 && cp $MONERO_DIR/src/blockchain_db/libblockchain_db.so /build/lib/           \
 && cp $MONERO_DIR/src/common/libcommon.so /build/lib/                         \
 && cp $MONERO_DIR/src/crypto/libcncrypto.so /build/lib/                       \
 && cp $MONERO_DIR/src/cryptonote_basic/libcryptonote_basic.so /build/lib/     \
 && cp $MONERO_DIR/src/ringct/libringct.so /build/lib/

WORKDIR $MONERO_STRATUM_DIR

RUN git clone --depth 1 --single-branch $MONERO_STRATUM_URL .                  \
 && cmake . && make                                                            \
 && mkdir -p /build/bin/                                                       \
 && mv $MONERO_STRATUM_DIR/build/_workspace/src/github.com/sammy007/monero-stratum/cnutil/libcnutil.so /build/lib/   \
 && mv $MONERO_STRATUM_DIR/build/_workspace/src/github.com/sammy007/monero-stratum/hashing/libhashing.so /build/lib/ \
 && mv $MONERO_STRATUM_DIR/build/bin/* /build/bin/                             \
 && mv $MONERO_STRATUM_DIR/www /build/www

FROM alpine:3.6

COPY --from=builder /build/lib/* /usr/lib/
COPY --from=builder /build/bin/* /usr/bin/
COPY --from=builder /build/www /var/www

WORKDIR /var/

RUN apk --no-cache add unbound libressl boost boost-program_options