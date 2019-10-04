#!/usr/bin/env bash

source script/init.sh

export DJGPP_DOWNLOAD_BASE="http://www.mirrorservice.org/sites/ftp.delorie.com/pub"

prepend BINUTILS_CONFIGURE_OPTIONS "--disable-werror
                                    --disable-nls"

prepend GCC_CONFIGURE_OPTIONS "--disable-nls
                               --enable-libquadmath-support
                               --enable-version-specific-runtime-libs
                               --enable-fat
                               --enable-libstdcxx-filesystem-ts"

prepend GDB_CONFIGURE_OPTIONS "--disable-werror
                               --disable-nls"

prepend CFLAGS_FOR_TARGET "-O2"

if [ -z $1 ]; then
  echo "Usage: $0 [packages...]"
  echo "Supported packages:"
  ls djgpp/
  ls common/
  exit 1
fi

while [ ! -z $1 ]; do
  PKG="$1"
  shift
  if [ ! -x djgpp/$PKG ] && [ ! -x common/$PKG ]; then
    echo "Unsupported package: $PKG"
    exit 1
  fi

  [ -e djgpp/$PKG ] && source djgpp/$PKG || source common/$PKG
done

DEPS=""

if [ -z ${IGNORE_DEPENDENCIES} ]; then
  [ ! -z ${GCC_VERSION} ] && DEPS+=" djgpp binutils"
  [ ! -z ${BINUTILS_VERSION} ] && DEPS+=" "
  [ ! -z ${GDB_VERSION} ] && DEPS+=" "
  [ ! -z ${DJGPP_VERSION} ] && DEPS+=" binutils gcc"
  [ ! -z ${BUILD_DXEGEN} ] && DEPS+=" djgpp binutils gcc"
  
  for DEP in ${DEPS}; do
    case $DEP in
      djgpp)
        [ -z ${DJGPP_VERSION} ] \
          && source djgpp/djgpp
        ;;
      binutils)
        [ -z "`ls ${destdir}${PREFIX}/${TARGET}/etc/binutils-*-installed 2> /dev/null`" ] \
          && [ -z ${BINUTILS_VERSION} ] \
          && source djgpp/binutils
        ;;
      gcc)
        [ -z "`ls ${destdir}${PREFIX}/${TARGET}/etc/gcc-*-installed 2> /dev/null`" ] \
          && [ -z ${GCC_VERSION} ] \
          && source common/gcc
        ;;
      gdb)
        [ -z "`ls ${destdir}${PREFIX}/${TARGET}/etc/gdb-*-installed 2> /dev/null`" ] \
          && [ -z ${GDB_VERSION} ] \
          && source common/gdb
        ;;
      dxegen)
        [ -z "`ls ${destdir}${PREFIX}/${TARGET}/etc/dxegen-installed 2> /dev/null`" ] \
          && [ -z ${BUILD_DXEGEN} ] \
          && source djgpp/dxegen
        ;;
    esac
  done
fi

if [ ! -z ${GCC_VERSION} ] && [ -z ${DJCROSS_GCC_ARCHIVE} ]; then
  DJCROSS_GCC_ARCHIVE="${DJGPP_DOWNLOAD_BASE}/djgpp/rpms/djcross-gcc-${GCC_VERSION}/djcross-gcc-${GCC_VERSION}.tar.bz2"
  # djcross-gcc-X.XX-tar.* maybe moved from /djgpp/rpms/ to /djgpp/deleted/rpms/ directory.
  OLD_DJCROSS_GCC_ARCHIVE=${DJCROSS_GCC_ARCHIVE/rpms\//deleted\/rpms\/}
fi

source ${BASE}/script/download.sh

source ${BASE}/script/build-tools.sh

cd ${BASE}/$BLDSUF || exit 1
BUILDDIR=`pwd`

if [ ! -z ${BINUTILS_VERSION} ]; then
  mkdir -p bnu${BINUTILS_VERSION}s
  cd bnu${BINUTILS_VERSION}s
  if [ ! -e binutils-unpacked ]; then
    echo "Unpacking binutils..."
    unzip -oq ../../download/bnu${BINUTILS_VERSION}s.zip || exit 1

    # patch for binutils 2.27
    [ ${BINUTILS_VERSION} == 227 ] && (patch gnu/binutils-*/bfd/init.c ${BASE}/patch/patch-bnu27-bfd-init.txt || exit 1 )

    touch binutils-unpacked
  fi
  cd gnu/binutils-* || exit 1

  # exec permission of some files are not set, fix it.
  for EXEC_FILE in install-sh missing configure; do
    echo "chmod a+x $EXEC_FILE"
    chmod a+x $EXEC_FILE || exit 1
  done

  source ${BASE}/script/build-binutils.sh
fi

cd $BUILDDIR || exit 1

if [ -n "${DJGPP_VERSION}" ]; then
  if [ "${DJGPP_VERSION}" == "cvs" ]; then
    if [ -z "${DJGPP_GIT_PATH}" ]; then
      download_git ${DJGPP_GIT_URL} ${DJGPP_GIT_BRANCH}
    else
      rm -rf djgpp-cvs
      ln -sf "${DJGPP_GIT_PATH}" djgpp-cvs
    fi
    cd djgpp-cvs
  else
    echo "Unpacking djgpp..."
    rm -rf djgpp-${DJGPP_VERSION}/
    mkdir -p djgpp-${DJGPP_VERSION}/
    cd djgpp-${DJGPP_VERSION}/ || exit 1
    unzip -uoq ../../download/djdev${DJGPP_VERSION}.zip || exit 1
    unzip -uoq ../../download/djlsr${DJGPP_VERSION}.zip || exit 1
    unzip -uoq ../../download/djcrx${DJGPP_VERSION}.zip || exit 1
    patch -p1 -u < ../../patch/patch-djcrx${DJGPP_VERSION}.txt || exit 1
    cat ../../patch/djlsr${DJGPP_VERSION}/* | patch -p1 -u || exit 1
  fi

  cd src
  unset COMSPEC
  sed -i "50cCROSS_PREFIX = ${TARGET}-" makefile.def
  sed -i "61cGCC = \$(CC) -g -O2 ${CFLAGS}" makefile.def
  ${MAKE} misc.exe makemake.exe ../hostbin || exit 1
  ${MAKE} -C djasm native || exit 1
  ${MAKE} -C stub native || exit 1
  cd ..

  case `uname` in
  MINGW*) EXE=.exe ;;
  MSYS*) EXE=.exe ;;
  *) EXE= ;;
  esac

  echo "Installing djgpp headers (stage 1)"
  mkdir -p ${BUILDDIR}/tmpinst$PREFIX/${TARGET}/sys-include || exit 1
  cp -rp include/* ${BUILDDIR}/tmpinst$PREFIX/${TARGET}/sys-include/ || exit 1
  mkdir -p ${BUILDDIR}/tmpinst$PREFIX/bin || exit 1
  cp -p hostbin/stubify.exe ${BUILDDIR}/tmpinst$PREFIX/bin/${TARGET}-stubify${EXE} || exit 1
  cp -p hostbin/stubedit.exe ${BUILDDIR}/tmpinst$PREFIX/bin/${TARGET}-stubedit${EXE} || exit 1
  mkdir -p ${BUILDDIR}/tmpinst$PREFIX/${TARGET}/bin || exit 1
  cp -p hostbin/stubify.exe ${BUILDDIR}/tmpinst$PREFIX/${TARGET}/bin/stubify${EXE} || exit 1
  cp -p hostbin/stubedit.exe ${BUILDDIR}/tmpinst$PREFIX/${TARGET}/bin/stubedit${EXE} || exit 1
  echo "Installing djgpp headers (stage 2)"
  ${SUDO} mkdir -p ${destdir}$PREFIX/${TARGET}/sys-include || exit 1
  ${SUDO} cp -rp include/* ${destdir}$PREFIX/${TARGET}/sys-include/ || exit 1
  ${SUDO} mkdir -p ${destdir}$PREFIX/bin || exit 1
  ${SUDO} cp -p hostbin/stubify.exe ${destdir}$PREFIX/bin/${TARGET}-stubify${EXE} || exit 1
  ${SUDO} cp -p hostbin/stubedit.exe ${destdir}$PREFIX/bin/${TARGET}-stubedit${EXE} || exit 1
  ${SUDO} mkdir -p ${destdir}$PREFIX/${TARGET}/bin || exit 1
  ${SUDO} cp -p hostbin/stubify.exe ${destdir}$PREFIX/${TARGET}/bin/stubify${EXE} || exit 1
  ${SUDO} cp -p hostbin/stubedit.exe ${destdir}$PREFIX/${TARGET}/bin/stubedit${EXE} || exit 1
fi

cd $BUILDDIR

if [ ! -z ${GCC_VERSION} ]; then
  # build gcc
  untar ${DJCROSS_GCC_ARCHIVE} || exit 1
  cd djcross-gcc-${GCC_VERSION}/
  SRCDIR=`pwd`

  export PATH="${BUILDDIR}/tmpinst/bin:${BUILDDIR}/tmpinst${PREFIX}/bin:$PATH"

  if [ ! -e gcc-unpacked ]; then
    rm -rf $BUILDDIR/gnu/

    if [ `uname` = "FreeBSD" ]; then
      # The --verbose option is not recognized by BSD patch
      sed -i 's/patch --verbose/patch/' unpack-gcc.sh || exit 1
    fi
    patch -p1 -u < ${BASE}/patch/patch-unpack-gcc.txt || exit 1

    mkdir gnu/
    cd gnu/ || exit 1
    untar ${GCC_ARCHIVE}
    cd ..

    echo "Running unpack-gcc.sh"
    sh unpack-gcc.sh --no-djgpp-source || exit 1

    # patch gnu/gcc-X.XX/gcc/doc/gcc.texi
    echo "Patch gcc/doc/gcc.texi"
    cd gnu/gcc-*/gcc/doc || exit 1
    sed -i "s/[^^]@\(\(tex\)\|\(end\)\)/\n@\1/g" gcc.texi || exit 1
    cd -

    # download mpc/gmp/mpfr/isl libraries
    echo "Downloading gcc dependencies"
    cd gnu/gcc-${GCC_VERSION} || exit 1
    if [ -f "${BASE}/download/gcc-${GCC_VERSION}-dep/download_prerequisites" ]; then
      cp -f ${BASE}/download/gcc-${GCC_VERSION}-dep/download_prerequisites contrib
    else
      sed -i 's/ftp/http/' contrib/download_prerequisites
    fi
    source ./contrib/download_prerequisites || exit 1

    # apply extra patches if necessary
    [ -e ${BASE}/patch/patch-djgpp-gcc-${GCC_VERSION}.txt ] && patch -p 1 -u -i ${BASE}/patch/patch-djgpp-gcc-${GCC_VERSION}.txt
    patch -p0 < ${BASE}/patch/patch-gcc-config.txt || exit 1
    # need to autoconf after patching config
    autoconf || exit 1
    cd -

    touch gcc-unpacked
  else
    echo "gcc already unpacked, skipping."
  fi

  echo "Building gcc (stage 1)"

  TEMP_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS $GCC_EXTRA_CFLAGS"

  mkdir -p djcross
  cd djcross || exit 1

  GCC_CONFIGURE_OPTIONS_1="$GCC_CONFIGURE_OPTIONS --target=${TARGET} ${HOST_FLAG} ${BUILD_FLAG}
                           --enable-languages=${ENABLE_LANGUAGES} --prefix=$BUILDDIR/tmpinst${PREFIX}"
  strip_whitespace GCC_CONFIGURE_OPTIONS_1

  if [ ! -e configure-prefix ] || [ ! "`cat configure-prefix`" == "${GCC_CONFIGURE_OPTIONS_1}" ]; then
    rm -rf *
    eval "../gnu/gcc-${GCC_VERSION}/configure ${GCC_CONFIGURE_OPTIONS_1}" || exit 1
    echo ${GCC_CONFIGURE_OPTIONS_1} > configure-prefix
  else
    echo "Note: gcc already configured. To force a rebuild, use: rm -rf $(pwd)"
  fi

  ${MAKE} -j${MAKE_JOBS} all-gcc || exit 1
  echo "Installing gcc (stage 1)"
  ${MAKE} -j${MAKE_JOBS} install-gcc || exit 1

  cd $SRCDIR

  mkdir -p djcross-stage2
  cd djcross-stage2 || exit 1

  GCC_CONFIGURE_OPTIONS_2="$GCC_CONFIGURE_OPTIONS --target=${TARGET} ${HOST_FLAG} ${BUILD_FLAG}
                           --enable-languages=${ENABLE_LANGUAGES} --prefix=${PREFIX}
                           --with-build-time-tools=$BUILDDIR/tmpinst${PREFIX}"
  strip_whitespace GCC_CONFIGURE_OPTIONS_2

  if [ ! -e configure-prefix ] || [ ! "`cat configure-prefix`" == "${GCC_CONFIGURE_OPTIONS_2}" ]; then
    rm -rf *
    eval "../gnu/gcc-${GCC_VERSION}/configure ${GCC_CONFIGURE_OPTIONS_2}" || exit 1
    echo ${GCC_CONFIGURE_OPTIONS_2} > configure-prefix
  else
    echo "Note: gcc already configured. To force a rebuild, use: rm -rf $(pwd)"
  fi

  export CFLAGS="$TEMP_CFLAGS"
fi

# gcc done

if [ ! -z ${DJGPP_VERSION} ]; then
  echo "Building djgpp libc"
  cd $BUILDDIR/djgpp-${DJGPP_VERSION}/src
  TEMP_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS_FOR_TARGET"
  sed -i 's/Werror/Wno-error/' makefile.cfg
  ${MAKE} config || exit 1
  ${MAKE} -j${MAKE_JOBS} -C mkdoc || exit 1
  ${MAKE} -j${MAKE_JOBS} -C libc || exit 1

  echo "Installing djgpp libc (stage 1)"
  mkdir -p $BUILDDIR/tmpinst${PREFIX}/${TARGET}/lib
  cp -rp ../lib/* $BUILDDIR/tmpinst$PREFIX/${TARGET}/lib || exit 1
  CFLAGS="$TEMP_CFLAGS"
  echo "Installing djgpp libc (stage 2)"
  ${SUDO} mkdir -p ${destdir}${PREFIX}/${TARGET}/lib
  ${SUDO} cp -rp ../lib/* ${destdir}$PREFIX/${TARGET}/lib || exit 1
  CFLAGS="$TEMP_CFLAGS"
fi

if [ ! -z ${GCC_VERSION} ]; then
  TEMP_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS $GCC_EXTRA_CFLAGS"

  echo "Building gcc (stage 2.1)"
  cd $SRCDIR/djcross || exit 1
  ${MAKE} -j${MAKE_JOBS} || exit 1
  echo "Installing gcc (stage 2.1)"
  ${MAKE} -j${MAKE_JOBS} install-strip || exit 1
  ${MAKE} -j${MAKE_JOBS} -C mpfr install

  echo "Building gcc (stage 2.2)"
  cd $SRCDIR/djcross-stage2 || exit 1

  ${MAKE} -j${MAKE_JOBS} || exit 1
  echo "Installing gcc (stage 2.2)"
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install-strip DESTDIR=${destdir} || exit 1
  # for some reason it creates include dir
  ${SUDO} rm -rf ${destdir}${PREFIX}/include
  CFLAGS="$TEMP_CFLAGS"

  ${SUDO} rm -f ${destdir}${PREFIX}/${TARGET}/etc/gcc-*-installed
  ${SUDO} touch ${destdir}${PREFIX}/${TARGET}/etc/gcc-${GCC_VERSION}-installed
fi

if [ ! -z ${DJGPP_VERSION} ]; then
  echo "Building djgpp libraries"
  cd $BUILDDIR/djgpp-${DJGPP_VERSION}/src
  TEMP_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS_FOR_TARGET"
  ${MAKE} -j${MAKE_JOBS} -C utils native || exit 1
  ${MAKE} -j${MAKE_JOBS} -C dxe native || exit 1
  ${MAKE} -j${MAKE_JOBS} -C debug || exit 1
  ${MAKE} -j${MAKE_JOBS} -C libemu || exit 1
  ${MAKE} -j${MAKE_JOBS} -C libm || exit 1
  ${MAKE} -j${MAKE_JOBS} -C docs || exit 1
#  ${MAKE} -j${MAKE_JOBS} -C ../zoneinfo/src
  ${MAKE} -j${MAKE_JOBS} -f makempty || exit 1
  CFLAGS="$TEMP_CFLAGS"
  cd ..

  echo "Installing djgpp libraries and utilities"
  ${SUDO} cp -rp lib/* ${destdir}$PREFIX/${TARGET}/lib || exit 1
  ${SUDO} cp -p hostbin/exe2coff.exe ${destdir}$PREFIX/bin/${TARGET}-exe2coff${EXE} || exit 1
  ${SUDO} cp -p hostbin/djasm.exe ${destdir}$PREFIX/bin/${TARGET}-djasm${EXE} || exit 1
  ${SUDO} cp -p hostbin/dxegen.exe  ${destdir}$PREFIX/bin/${TARGET}-dxegen${EXE} || exit 1
  ${SUDO} ln -sf ${TARGET}-dxegen${EXE} ${destdir}$PREFIX/bin/${TARGET}-dxe3gen${EXE} || exit 1
  ${SUDO} cp -p hostbin/dxe3res.exe ${destdir}$PREFIX/bin/${TARGET}-dxe3res${EXE} || exit 1
  ${SUDO} mkdir -p ${destdir}${PREFIX}/${TARGET}/share/info
  ${SUDO} cp -rp info/* ${destdir}${PREFIX}/${TARGET}/share/info

  ${SUDO} rm -f ${destdir}${PREFIX}/${TARGET}/etc/djgpp-*-installed
  ${SUDO} touch ${destdir}${PREFIX}/${TARGET}/etc/djgpp-${DJGPP_VERSION}-installed
fi

cd ${BASE}/build

source ${BASE}/script/build-gdb.sh

source ${BASE}/script/finalize.sh
