test -n "$DJGPP_VERSION" || return

echo "Copy long name executables to short name."
cd ${destdir}$PREFIX || exit 1
${SUDO} mkdir -p ${TARGET}/bin
SHORT_NAME_LIST="gcc g++ c++ addr2line c++filt cpp size strings dxegen dxe3gen dxe3res exe2coff gdb djasm"
for SHORT_NAME in $SHORT_NAME_LIST; do
  if [ -f bin/${TARGET}-$SHORT_NAME ]; then
    ${SUDO} cp -p bin/${TARGET}-$SHORT_NAME ${TARGET}/bin/$SHORT_NAME
  fi
done
${SUDO} cp -p bin/${TARGET}-g++ bin/${TARGET}-g++-${GCC_VERSION}

cat << STOP > ${BASE}/build/setenv-${TARGET}
export PATH="${PREFIX}/${TARGET}/bin/:${PREFIX}/bin/:\$PATH"
export GCC_EXEC_PREFIX="${PREFIX}/lib/gcc/"
export MANPATH="${PREFIX}/${TARGET}/share/man:${PREFIX}/share/man:\$MANPATH"
export INFOPATH="${PREFIX}/${TARGET}/share/info:${PREFIX}/share/info:\$INFOPATH"
STOP

cat << STOP > ${BASE}/build/setenv-${TARGET}.bat
@echo off
PATH=%~dp0${TARGET}\\bin;%~dp0bin;%PATH%
set GCC_EXEC_PREFIX=%~dp0lib\\gcc\\
STOP

case $TARGET in
*-msdosdjgpp)
  echo "export DJDIR=\"${PREFIX}/${TARGET}\""   >> ${BASE}/build/setenv-${TARGET}
  echo "set DJDIR=%~dp0${TARGET}"               >> ${BASE}/build/setenv-${TARGET}.bat
  ;;
esac

#echo "Installing setenv-${TARGET}"
#${SUDO} cp ${BASE}/build/setenv-${TARGET} ${destdir}${PREFIX}/
#${SUDO} cp ${BASE}/build/setenv-${TARGET}.bat ${destdir}${PREFIX}/ 2> /dev/null

cd ${BASE}/build

echo "Done."
echo "To remove temporary build files, use: rm -rf build/"
echo "To remove downloaded source packages, use: rm -rf download/"
