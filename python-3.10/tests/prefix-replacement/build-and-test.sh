#!/usr/bin/env bash

set -ex

if [[ $ppc_arch == "p10" ]]
then
    if [[ -z "${GCC_HOME}" ]];
    then
        echo "Please set GCC_HOME to the install path of gcc-toolset-11"
        exit 1
    else
        CC=${GCC_HOME}/bin/gcc
        CXX=${GCC_HOME}/bin/g++
        GCC=$CC
        AR=${GCC_HOME}/bin/ar
        LD=${GCC_HOME}/bin/ld
        NM=${GCC_HOME}/bin/nm
        OBJCOPY=${GCC_HOME}/bin/objcopy
        OBJDUMP=${GCC_HOME}/bin/objdump
        RANLIB=${GCC_HOME}/bin/ranlib
        STRIP=${GCC_HOME}/bin/strip
	READELF=${GCC_HOME}/bin/readelf
#        export PATH=$GCC_HOME/bin:$PATH
    fi
fi

if [[ "$PKG_NAME" == "libpython-static" ]]; then
  # see bpo44182 for why -L${CONDA_PREFIX}/lib is added
  ${CC} a.c $(python3-config --cflags) $(python3-config --embed --ldflags) -L${CONDA_PREFIX}/lib -o ${CONDA_PREFIX}/bin/embedded-python-static
  if [[ "$target_platform" == linux-* ]]; then
    if ${READELF} -d ${CONDA_PREFIX}/bin/embedded-python-static | rg libpython; then
      echo "ERROR :: Embedded python linked to shared python library. It is expected to link to the static library."
    fi
  elif [[ "$target_platform" == osx-* ]]; then
    if ${OTOOL} -l ${CONDA_PREFIX}/bin/embedded-python-static | rg libpython; then
      echo "ERROR :: Embedded python linked to shared python library. It is expected to link to the static library."
    fi
  fi
  ${CONDA_PREFIX}/bin/embedded-python-static

  # I thought this would prefer the shared library for Python. I was wrong:
  # EMBED_LDFLAGS=$(python3-config --ldflags)
  # re='^(.*)(-lpython[^ ]*)(.*)$'
  # if [[ ${EMBED_LDFLAGS} =~ $re ]]; then
  #   EMBED_LDFLAGS="${BASH_REMATCH[1]} ${BASH_REMATCH[3]} -Wl,-Bdynamic ${BASH_REMATCH[2]}"
  # fi
  # ${CC} a.c $(python3-config --cflags) ${EMBED_LDFLAGS} -o ${CONDA_PREFIX}/bin/embedded-python-shared

  # Brute-force way of linking to the shared library, sorry!
  rm -rf ${CONDA_PREFIX}/lib/libpython*.a
fi

${CC} a.c $(python3-config --cflags) \
    $(python3-config --embed --ldflags) \
    -L${CONDA_PREFIX}/lib -Wl,-rpath,${CONDA_PREFIX}/lib \
    -o ${CONDA_PREFIX}/bin/embedded-python-shared

if [[ "$target_platform" == linux-* ]]; then
  if ! ${READELF} -d ${CONDA_PREFIX}/bin/embedded-python-shared | rg libpython; then
    echo "ERROR :: Embedded python linked to static python library. We tried to force it to use the shared library."
  fi
elif [[ "$target_platform" == osx-* ]]; then
  if ! ${OTOOL} -l ${CONDA_PREFIX}/bin/embedded-python-shared | rg libpython; then
    echo "ERROR :: Embedded python linked to static python library. We tried to force it to use the shared library."
  fi
fi
${CONDA_PREFIX}/bin/embedded-python-shared

set +x
