#!/bin/bash

# __author__ = "Alberto Pettarin"
# __copyright__ = "Copyright 2016, Alberto Pettarin (www.albertopettarin.it)"
# __license__ = "MIT"
# __version__ = "1.1.0"
# __email__ = "alberto@albertopettarin.it"
# __status__ = "Production"

#
# NOTE this script will create a directory with the following structure:
#
#      DESTINATION_DIRECTORY
#        |
#        | build_festival
#        |   | festival
#        |   |   | bin
#        |   |   |   | festival (exec)
#        |   |   |   | text2wave (exec)
#        |   |   |   | ...
#        |   |   |
#        |   |   | lib
#        |   |   |   | voices
#        |   |   |   | ...
#        |   |   | ...
#        |
#        | build_mbrola
#        |   | mbrola (exec)
#        |
#        | download_festival
#        |   | several .tar.gz files
#        |
#        | download_festival_voices
#        |   | several .tar.gz files
#        |
#        | download_mbrola
#        |   | several .tar.gz or .zip files
#        |
#        | download_mbrola_voices
#        |   | several.zip files
#        |
#

usage() {
    echo ""
    echo "Usage:"
    echo "  $ bash $0 PATH_TO_DEST_DIR ACTION"
    echo ""
    echo "Actions:"
    echo "  clean                   delete all DEST_DIR/build_* directories"
    echo "  clean-all               delete entire DEST_DIR directory"
    echo "  festival                download+compile Festival, install basic English voices"
    echo "  festival-mbrola-voices  download+install Festival wrappers for MBROLA"
    echo "  festival-voices         download+install all known Festival voices (WARNING: large download)"

    echo "  mbrola                  download MBROLA binary"
    echo "  mbrola-voices           download all known MBROLA voices (WARNING: large download)"
    echo ""
    echo "Examples:"
    echo "  $ bash $0 ~/st festival"
    echo "  $ bash $0 ~/st mbrola"
    echo "  $ bash $0 ~/st festival-mbrola-voices"
    echo "  $ bash $0 ~/st italian"
    echo "  $ bash $0 ~/st festival-voices        # WARNING: large download"
    echo "  $ bash $0 ~/st mbrola-voices          # WARNING: large download"
    echo "  $ bash $0 ~/st clean"
    echo "  $ bash $0 ~/st clean-all"
    echo ""
}



###############################################################################
#
# HELPER FUNCTIONS
#
###############################################################################

ensure_directory() {
  D=$1
  if [ ! -d "$D" ]
  then
    mkdir -p "$D"
    echo "[INFO] Created directory $D"
  fi
}

absolute_path() {
  # from http://stackoverflow.com/a/3915420
  echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

get_file() {
  P=`pwd`
  R=$1
  REPO=$2
  URL=$3
  BASE=`basename $URL`

  ensure_directory "$R"
  ensure_directory "$R/$REPO"

  echo "[INFO] Downloading file $BASE ..."
  cd "$R"
  cd "$REPO"
  if [ ! -e "$BASE" ]
  then
    curl -O "$URL"
  fi
  echo "[INFO] Downloading file $BASE ... done"

  cd "$P"
}

untargz_file() {
  P=`pwd`
  R=$1
  REPO=$2
  BUILD=$3
  BASE=$4

  ensure_directory "$R"
  ensure_directory "$R/$REPO"
  ensure_directory "$R/$BUILD"

  echo "[INFO] Uncompressing file $BASE ..."
  cd "$R"
  cd "$BUILD"
  tar zxvf "../$REPO/$BASE"
  echo "[INFO] Uncompressing file $BASE ... done"

  cd "$P"
}

unzip_file() {
  P=`pwd`
  R=$1
  REPO=$2
  BUILD=$3
  BASE=$4
  DEST=$5

  if [ "$DEST" != "" ]
  then
    ensure_directory "$R"
    ensure_directory "$R/$REPO"
    ensure_directory "$R/$BUILD"
    ensure_directory "$R/$BUILD/festival/lib/voices/$DEST"
    cd "$R"

    echo "[INFO] Uncompressing file $BASE ..."
    unzip -o "$REPO/$BASE" -d "$BUILD/festival/lib/voices/$DEST"
    echo "[INFO] Uncompressing file $BASE ... done"

    cd "$P"
  fi
}

download_uncompress_festival_package() {
  R=$1
  REPO=$2
  BUILD=$3
  URL=$4
  BASE=`basename $URL`

  get_file "$R" "$REPO" "$URL"
  untargz_file "$R" "$REPO" "$BUILD" "$BASE"
}

download_uncompress_mbrola_voice() {
  R=$1
  REPO=$2
  BUILD=$3
  URL=$4
  BASE=`basename $URL`

  get_file "$R" "$REPO" "$URL"

  DEST=""
  
  if [ "$BASE" == "us1-980512.zip" ]
  then
    DEST="english/us1_mbrola/"
  elif [ "$BASE" == "us2-980812.zip" ]
  then
    DEST="english/us2_mbrola/"
  elif [ "$BASE" == "us3-990208.zip" ]
  then
    DEST="english/us3_mbrola/"
 
 fi
  unzip_file "$R" "$REPO" "$BUILD" "$BASE" "$DEST"
}

compile_festival() {
  P=`pwd`
  R=$1
  BUILD=$2

  cd "$R"
  cd "$BUILD"

  echo "[INFO] Compiling speech tools..."
  export ESTDIR="$P/speech_tools"
  cd speech_tools
  ./configure && make && make make_library
  cd ..
  echo "[INFO] Compiling speech tools... done"

  echo "[INFO] Compiling festival..."
  cd festival
  ./configure && make
  cd ..
  echo "[INFO] Compiling festival... done"

  cd "$P"
}



###############################################################################
#
# ACTUAL FUNCTIONS
#
###############################################################################

clean() {
  R=$1
  rm -rf "$R/build_festival"
  rm -rf "$R/build_mbrola"
  echo "[INFO] Removed directories $R/build_*"
}

clean_all() {
  R=$1
  if [ -d "$R/build_festival" ] || [ -d "$R/build_mbrola" ] || [ -d "$R/download_festival" ] || [ -d "$R/download_festival_voices" ] || [ -d "$R/download_mbrola" ] || [ -d "$R/download_mbrola_voices" ]
  then
    rm -rf "$R"
    echo "[INFO] Removed directory $R"
  else
    echo "[ERRO] Directory $R does not look like a valid Festival/MBROLA directory, aborting."
  fi
}

install_festival() {
  R=$1
  BUILD="build_festival"

  echo "[INFO] Installing Festival..."
  #
  # NOTE this will download the minimum number of files required
  #      to have a working Festival with UK and US basic voices:
  #
  #      Edinburgh speech tools (EST)
  #      Festival
  #      Festlex CMU, OALD, POSLEX lexica
  #      Diphone voices: don, kal, ked, rab
  #
  # NOTE order is important! Always have:
  #      first EST,
  #      then Festival,
  #      then lexica,
  #      then voices
  #
  REPO="download_festival"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/speech_tools-2.4-release.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/festival-2.4-release.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/festlex_CMU.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/festlex_OALD.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/festlex_POSLEX.tar.gz"

  REPO="download_festival_voices"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/voices/festvox_kallpc16k.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/2.4/voices/festvox_rablpc16k.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/1.95/festvox_don.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/1.95/festvox_kedlpc16k.tar.gz"

  compile_festival "$R" "$BUILD"
  echo "[INFO] Installing Festival... done"

  ABS=`absolute_path "$R/$BUILD/festival/bin"`
  echo ""
  echo "[INFO] You might want to append:"
  echo "[INFO]   $ABS"
  echo "[INFO] to your PATH environment variable."
  echo ""
}

install_festival_voices() {
  R=$1
  REPO="download_festival_voices"
  BUILD="build_festival"

  echo "[INFO] Installing additional voices..."
  declare -a URLS=(
    "http://festvox.org/packed/festival/1.95/festvox_cmu_us_awb_arctic_hts.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_cmu_us_bdl_arctic_hts.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_cmu_us_jmk_arctic_hts.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_cmu_us_slt_arctic_hts.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_cstr_us_awb_arctic_multisyn-1.0.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_cstr_us_jmk_arctic_multisyn-1.0.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_don.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_ellpc11k.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_kallpc8k.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_kedlpc16k.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_kedlpc8k.tar.gz"
    "http://festvox.org/packed/festival/1.95/festvox_rablpc8k.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_ahw_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_aup_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_awb_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_axb_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_bdl_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_clb_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_fem_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_gka_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_jmk_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_ksp_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_rms_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_rxr_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_cmu_us_slt_cg.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_kallpc16k.tar.gz"
    "http://festvox.org/packed/festival/2.4/voices/festvox_rablpc16k.tar.gz"
  )
  for URL in "${URLS[@]}"
  do
    download_uncompress_festival_package "$R" "$REPO" "$BUILD" "$URL"
  done
  echo "[INFO] Installing additional voices... done"
}

install_italian() {
  R=$1
  BUILD="build_festival"

  echo "[INFO] Installing additional Italian voices..."
  REPO="download_festival"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/italian_scm.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/festlex_IFD.tar.gz"

  REPO="download_festival_voices"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/festvox_pc_diphone.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/festvox_lp_diphone.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/festvox_pc_mbrola.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://www2.pd.istc.cnr.it/FESTIVAL/ifd/festvox_lp_mbrola.tar.gz"

  
}

install_mbrola() {
  P=`pwd`
  R=$1
  REPO="download_mbrola"
  BUILD="build_mbrola"

  ensure_directory "$R"
  ensure_directory "$R/$REPO"
  ensure_directory "$R/$BUILD"
  cd "$R"

  echo "[INFO] Installing mbrola..."
  cd "$REPO"
  UNAME=`uname`
  DOWNLOADED=0
  if [ "$UNAME" == "Linux" ]
  then
    # download mbrola for Linux
    echo "[INFO]   Downloading mbrola binary for Linux..."
    curl -O "http://tcts.fpms.ac.be/synthesis/mbrola/bin/pclinux/mbr301h.zip"
    echo "[INFO]   Downloading mbrola binary for Linux... done"

    # extract
    echo "[INFO]   Copying mbrola binary to $BUILD ..."
    unzip mbr301h.zip "mbrola-linux-i386" -d "../$BUILD/"
    mv "../$BUILD/mbrola-linux-i386" "../$BUILD/mbrola"
    chmod 744 "../$BUILD/mbrola"
    echo "[INFO]   Copying mbrola binary to $BUILD ... done"

    DOWNLOADED=1
  elif [ "$UNAME" == "Darwin" ]
  then
    # download mbrola for Mac OS X
    echo "[INFO]   Downloading mbrola binary for OS X..."
    curl -O "http://tcts.fpms.ac.be/synthesis/mbrola/bin/macintosh/mbrola"
    echo "[INFO]   Downloading mbrola binary for OS X... done"

    echo "[INFO]   Copying mbrola binary to $BUILD ..."
    chmod 744 "mbrola"
    cp "mbrola" "../$BUILD/mbrola"
    echo "[INFO]   Copying mbrola binary to $BUILD ... done"

    DOWNLOADED=1
  else
    # unknown OS
    echo "[ERRO]   Unknown OS, aborting."
  fi

  cd "$P"
  echo "[INFO] Installing mbrola... done"

  if [ "$DOWNLOADED" == "1" ]
  then
    ABS=`absolute_path "$R/$BUILD"`
    echo ""
    echo "[INFO] You might want to append:"
    echo "[INFO]   $ABS"
    echo "[INFO] to your PATH environment variable."
    echo ""
  fi
}

install_festival_mbrola_voices() {
  R=$1
  BUILD="build_festival"

  echo "[INFO] Installing festival-mbrola voices..."
  REPO="download_festival_voices"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/1.95/festvox_us1.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/1.95/festvox_us2.tar.gz"
  download_uncompress_festival_package "$R" "$REPO" "$BUILD" "http://festvox.org/packed/festival/1.95/festvox_us3.tar.gz"

  REPO="download_mbrola_voices"
 
  download_uncompress_mbrola_voice     "$R" "$REPO" "$BUILD" "http://web.mit.edu/kolya/sipb/afs/root.afs/sipb.mit.edu/project/speech-tools/src/mbrola/us1-980512.zip"
  download_uncompress_mbrola_voice     "$R" "$REPO" "$BUILD" "http://web.mit.edu/kolya/sipb/afs/root.afs/sipb.mit.edu/project/speech-tools/src/mbrola/us2-980812.zip"
  download_uncompress_mbrola_voice     "$R" "$REPO" "$BUILD" "http://web.mit.edu/kolya/sipb/afs/root.afs/sipb.mit.edu/project/speech-tools/src/mbrola/us3-990208.zip"

  UNAME=`uname`
  if [ "$UNAME" == "Darwin" ]
  then
    echo "[INFO]   Downloading and patching Festival wrappers for mbrola 3.01d ..."
    # on Mac OS X only mbrola 3.01d is available,
    # hence we need to download the patched Festival wrappers
    REPO="download_mbrola"
    URL="https://raw.githubusercontent.com/pettarin/setup-festival-mbrola/master/dist/patch_mbrola_301d.tar.gz"
    download_uncompress_festival_package "$R" "$REPO" "$BUILD" "$URL"
    echo "[INFO]   Downloading and patching Festival wrappers for mbrola 3.01d ... done"
  fi

  echo "[INFO] Installing festival-mbrola voices... done"
}

get_mbrola_voices() {
  P=`pwd`
  R=$1
  REPO="download_mbrola_voices"

  echo "[INFO] Downloading additional mbrola voices..."
  declare -a URLS=(
    )
  for URL in "${URLS[@]}"
  do
    get_file "$R" "$REPO" "$URL"
  done
  echo "[INFO] Downloading additional mbrola voices... done"
}



###############################################################################
#
# MAIN SCRIPT
#
###############################################################################

if [ "$#" -lt "2" ]
then
  usage
  exit 2
fi

DESTINATION=$1
ACTION=$2

if [ "$ACTION" == "clean" ]
then
  clean "$DESTINATION"
elif [ "$ACTION" == "clean_all" ]
then
  clean_all "$DESTINATION"
elif [ "$ACTION" == "festival" ]
then
  install_festival "$DESTINATION"
elif [ "$ACTION" == "mbrola" ]
then
  install_mbrola "$DESTINATION"
elif [ "$ACTION" == "festival-voices" ]
then
  install_festival_voices "$DESTINATION"
elif [ "$ACTION" == "festival-mbrola-voices" ]
then
  install_festival_mbrola_voices "$DESTINATION"
elif [ "$ACTION" == "mbrola-voices" ]
then
  get_mbrola_voices "$DESTINATION"

else
  usage
  exit 2
fi

exit 0
