#!/bin/bash

if [ "$1" == "clean" ]; then

read -p "Do you really want to delete existing packages? [y/N]"
[[ $REPLY == [yY] ]] && { rm -fr zoneminder*.build zoneminder*.changes zoneminder*.deb; echo "Existing package files deleted";  } || { echo "Packages have NOT been deleted"; }
exit;

fi

DEBUILD=`which debuild`;

if [ "$DEBUILD" == "" ]; then
  echo "You must install the devscripts package.  Try sudo apt-get install devscripts";
  exit;
fi

for i in "$@"
do
case $i in
    -b=*|--branch=*)
    BRANCH="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--distro=*)
    DISTROS="${i#*=}"
    shift # past argument=value
    ;;
    -i=*|--interactive=*)
    INTERACTIVE="${i#*=}"
    shift # past argument=value
    ;;
    -p=*|--ppa=*)
    PPA="${i#*=}"
    shift # past argument=value
    ;;
    -r=*|--release=*)
    RELEASE="${i#*=}"
    shift
    ;;
    -s=*|--snapshot=*)
    SNAPSHOT="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--type=*)
    TYPE="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--urgency=*)
    URGENCY="${i#*=}"
    shift # past argument=value
    ;;
    -f=*|--fork=*)
    GITHUB_FORK="${i#*=}"
    shift # past argument=value
    ;;
    -v=*|--version=*)
    PACKAGE_VERSION="${i#*=}"
    shift
    ;;
    -x=*|--debbuild-extra=*)
    DEBBUILD_EXTRA="${i#*=}"
    shift
    ;;
    --dput=*)
    DPUT="${i#*=}"
    shift
    ;;
    --default)
    DEFAULT=YES
    shift # past argument with no value
    ;;
    *)
    # unknown option
    read -p "Unknown option $i, continue? (Y|n)"
    [[ $REPLY == [yY] ]] && { echo "continuing..."; } || exit 1;
    ;;
esac
done

DATE=`date -R`
if [ "$TYPE" == "" ]; then
  echo "Defaulting to source build"
  TYPE="source";
else 
  echo "Doing $TYPE build"
fi;

if [ "$DISTROS" == "" ]; then
  DISTROS=`lsb_release -a 2>/dev/null | grep Codename | awk '{print $2}'`;
  echo "Defaulting to $DISTROS for distribution";
else
  echo "Building for $DISTROS";
fi;

# Release is a special mode...  it uploads to the release ppa and cannot have a snapshot
if [ "$RELEASE" != "" ]; then
  if [ "$SNAPSHOT" != "" ]; then
    echo "Releases cannot have a snapshot.... exiting."
    exit 0;
  fi
  if [ "$GITHUB_FORK" != "" ] && [ "$GITHUB_FORK" != "ZoneMinder" ]; then
    echo "Releases cannot have a fork ($GITHUB_FORK).... exiting."
    exit 0;
  else
    GITHUB_FORK="ZoneMinder";
  fi
  # We use a tag instead of a branch atm.
  BRANCH=$RELEASE
else
  if [ "$GITHUB_FORK" == "" ]; then
    echo "Defaulting to ZoneMinder upstream git"
    GITHUB_FORK="ZoneMinder"
  fi;
fi;

# Instead of cloning from github each time, if we have a fork lying around, update it and pull from there instead.
# if [ ! -d "zoneminder_release" ]; then 
#   if [ -d "${GITHUB_FORK}_ZoneMinder.git" ]; then
#     echo "Using local clone ${GITHUB_FORK}_ZoneMinder.git to pull from."
#     cd "${GITHUB_FORK}_ZoneMinder.git"
#     echo "git pull..."
#     git pull
#     cd ../

#     echo "git clone ${GITHUB_FORK}_ZoneMinder.git ${GITHUB_FORK}_zoneminder_release"
#     git clone "${GITHUB_FORK}_ZoneMinder.git" "${GITHUB_FORK}_zoneminder_release"
#   else
#     echo "git clone https://github.com/$GITHUB_FORK/ZoneMinder.git ${GITHUB_FORK}_zoneminder_release"
#     git clone "https://github.com/$GITHUB_FORK/ZoneMinder.git" "${GITHUB_FORK}_zoneminder_release"
#   fi
# else
#   # echo "release dir already exists. Please remove it."
#   # exit 0;
#   echo "release dir already exists. Continue..."
# fi;

echo "mark 2"
cd "zoneminder_release"

# Grab the ZoneMinder version from the contents of the version file
VERSION=$(cat version)
if [ -z "$VERSION" ]; then
  exit 1;
fi;
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"

cd ../

if [ "$SNAPSHOT" != "stable" ] && [ "$SNAPSHOT" != "" ]; then
  VERSION="$VERSION~$SNAPSHOT";
fi;

DIRECTORY="zoneminder_$VERSION";

echo "mark 2.5"
IFS=',' ;for DISTRO in `echo "$DISTROS"`; do 
  echo "Generating package for $DISTRO";
  cd zoneminder_release

#   if [ -e "debian" ]; then
#     rm -rf debian
#   fi;

#   # Generate Changelog
#   if [ "$DISTRO" == "beowulf" ]; then
#     cp -Rpd distros/beowulf debian
#   else
#     cp -Rpd distros/ubuntu2004 debian
#   fi;

  if [ "$DEBEMAIL" != "" ] && [ "$DEBFULLNAME" != "" ]; then
      AUTHOR="$DEBFULLNAME <$DEBEMAIL>"
  else
    if [ -z `hostname -d` ] ; then
        AUTHOR="`getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1` <`whoami`@`hostname`.local>"
    else
        AUTHOR="`getent passwd $USER | cut -d ':' -f 5 | cut -d ',' -f 1` <`whoami`@`hostname`>"
    fi
  fi

  if [ "$URGENCY" = "" ]; then
    URGENCY="medium"
  fi;

  if [ "$SNAPSHOT" == "stable" ]; then
  cat <<EOF > debian/changelog
zoneminder ($VERSION-$DISTRO${PACKAGE_VERSION}) $DISTRO; urgency=$URGENCY

  * Release $VERSION

 -- $AUTHOR  $DATE

EOF
  cat <<EOF > debian/NEWS
zoneminder ($VERSION-$DISTRO${PACKAGE_VERSION}) $DISTRO; urgency=$URGENCY

  * Release $VERSION

 -- $AUTHOR  $DATE
EOF
  else
  cat <<EOF > debian/changelog
zoneminder ($VERSION-$DISTRO${PACKAGE_VERSION}) $DISTRO; urgency=$URGENCY

  * 

 -- $AUTHOR  $DATE
EOF
  cat <<EOF > debian/changelog
zoneminder ($VERSION-$DISTRO${PACKAGE_VERSION}) $DISTRO; urgency=$URGENCY

  * 

 -- $AUTHOR  $DATE
EOF
  fi;

  echo "mark 3"
  cd ..
  if [ $TYPE == "binary" ]; then
    echo "mark 4"
	  sudo apt-get install devscripts equivs
	  sudo mk-build-deps -ir zoneminder_release/debian/control
	  echo "Status: $?"
	  DEBUILD=debuild
  else
	  if [ $TYPE == "local" ]; then
      echo "mark 5"
		  echo "Status: $?"
		  DEBUILD="debuild -i -us -uc -b"
	  else 
		  DEBUILD="debuild -S -sa"
	  fi;
  fi;

  echo "mark 6"
  cd zoneminder_release

  if [ "$DEBSIGN_KEYID" != "" ]; then
    DEBUILD="$DEBUILD -k$DEBSIGN_KEYID"
  fi
  # Add any extra options specified on the CLI
  DEBUILD="$DEBUILD $DEBBUILD_EXTRA"
  eval $DEBUILD
  if [ $? -ne 0 ]; then
    echo "Error status code is: $?"
    echo "Build failed.";
    exit $?;
  fi;

  cd ../

done; # foreach distro

