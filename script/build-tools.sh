# build GNU sed if needed.
if [ ! -z $SED_VERSION ]; then
  TMPINST=${BASE}/build/tmpinst
  mkdir -p ${TMPINST}
  export PATH="${TMPINST}/bin:$PATH"

  cd ${BASE}/build || exit 1

  if [ ! -e ${TMPINST}/sed-${SED_VERSION}-installed ]; then
    echo "Building sed"
    untar ${SED_ARCHIVE} || exit 1
    cd sed-${SED_VERSION}/
    TEMP_CFLAGS="$CFLAGS"
    export CFLAGS="${CFLAGS//-w}"   # configure fails if warnings are disabled.
    ./configure --prefix=${TMPINST} || exit 1
    ${MAKE} -j${MAKE_JOBS} || exit 1
    ${MAKE} -j${MAKE_JOBS} install || exit 1
    CFLAGS="$TEMP_CFLAGS"
    touch ${TMPINST}/sed-${SED_VERSION}-installed
  fi
fi
