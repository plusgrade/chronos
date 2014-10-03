#!/bin/bash
set -o errexit -o nounset -o pipefail

chronos_home="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd -P )"
echo "Chronos home set to $chronos_home"
export JAVA_LIBRARY_PATH="/usr/local/lib:/lib:/usr/lib"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-/lib}"
export LD_LIBRARY_PATH="$JAVA_LIBRARY_PATH:$LD_LIBRARY_PATH"
export CHRONOS_VERSION="${CHRONOS_VERSION:-}"
export CHRONOS_EXTRA_OPTS="${CHRONOS_EXTRA_OPTS:-}"
export CHRONOS_EXTRA_CLASSPATH="${CHRONOS_EXTRA_CLASSPATH:-}"

flags=( "$@" )

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# skip automatic hostname detection if caller wants to set hostname
if ! containsElement "--hostname" "${flags[@]}"
then
  echo "No --hostname parameter.  Creating one... "
  #If we're on Amazon, let's use the public hostname so redirect works as expected.
  if public_hostname="$( curl -sSf --connect-timeout 1 http://169.254.169.254/latest/meta-data/public-hostname )"
  then
    flags+=( --hostname ${public_hostname} )
    echo "Used ec2 public name: ${public_hostname}."
  else
    # use fully qualified hostname. -f is redundant on some systems but ubuntu, for instance, returns unqualified
    # hostname by default
    hostname=$(hostname -f)
    flags+=( --hostname ${hostname} )
    echo "Used full host name: ${hostname}"
  fi
else
  echo "Have --hostname parameter.  Params = ${flags[@]}"
fi

if [[ -z "$CHRONOS_VERSION" ]]
then
  jar_files=( "$chronos_home"/target/chronos*.jar )
else
  # Optionally support version parameter -- useful in deployment testing scenarios in which you might have more
  # than one jar version present in the installed location
  jar_files=( "$chronos_home"/target/chronos-${CHRONOS_VERSION}.jar )
fi
echo "Using jar file: ${jar_files[0]}"

if [[ -n "$CHRONOS_EXTRA_CLASSPATH" ]]; then
  chronos_classpath="${CHRONOS_EXTRA_CLASSPATH}:${jar_files[0]}"
else
  chronos_classpath="${jar_files[0]}"
fi

heap=384m

#
# This is a workaround to redirect the output from the libmesos.so -- not currently written to honor glog env vars
#
if [[ "$MESOS_LIB_LOG_TO_SYSLOG" == "true" ]]; then
  exec 1> >(exec logger -p syslog.info -t chronos.libmesos)
  exec 2> >(exec logger -p syslog.info -t chronos.libmesos)
fi
exec java -Xmx"$heap" -Xms"$heap" $CHRONOS_EXTRA_OPTS -cp "$chronos_classpath" \
     com.airbnb.scheduler.Main \
     "${flags[@]}"

