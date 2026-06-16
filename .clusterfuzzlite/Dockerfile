FROM gcr.io/oss-fuzz-base/base-builder-python@sha256:8c8a4c8f7e492c33e4fde60448d118532c55f1efa4b6a36b8b8eb82e6de43a70

COPY . $SRC/kyth
WORKDIR $SRC/kyth
COPY .clusterfuzzlite/build.sh $SRC/build.sh
