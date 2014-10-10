#!/usr/bin/env bash
# This command is a bit like a Makefile: if your are outside a Docker 
# container it will send you inside a new Docker container and then it
# will give you shortcuts to main project commands.

IMAGE=${IMAGE:="akretion/voodoo"}
NAME=${NAME:="voodoo-${PWD##*/}"}
PORT=${PORT:="8069"}
POLLING_PORT=${POLLING_PORT:="8072"}
SERVER=${SERVER:="$2.akretion.com"}
POSTGRESQL_DB=${POSTGRESQL_DB:="db"}
POSTGRESQL_DATA=${POSTGRESQL_DATA:="/workspace/.db"}
WORKDIR=${WORKDIR:="/workspace"}
START_OPTIONS=${START_OPTIONS:="-ti"}
CONTAINER_FILE=${CONTAINER_DIR:="/.devstep"}
PIP_DIR=${PIP_DIR:="/.devstep/.pip_packages"}
SHARED_EGGS_DIR=${SHARED_EGGS_DIR:="/.devstep/addons/voodoo/host_eggs"}
IMAGE_EGGS_DIR=${IMAGE_EGGS_DIR:="/.devstep/addons/voodoo/eggs"}
SHARED_ODOO_DIR=${SHARED_ODOO_DIR:="/.devstep/addons/voodoo/odoo"}
DOCKER_USER=${DOCKER_USER:="developer"}
DOCKER_RM=${DOCKER_RM:="true"}
SSH_USER=${SSH_USER:="api"}
SSH_KEY=${SSH_KEY:=""}
BUILDOUT=${BUILDOUT:="buildout.dev.cfg"}


# *****************************************************************************
if [ ! -d "$CONTAINER_DIR" ]; then
  # we are outside of the container,
  # this is the bash equivalent of Vagrant with the Docker provider

  if [[ -z $1 || $1 == "up" || $1 == "run" || $1 == "build" || $1 == "debug" || \
     $1 == "console" && -z $2 || $1 == "psql" || $1 == "help" && -z $2 ]]; then

    if [[ ! -z "$(git remote -v | grep "github.com/akretion/voodoo")" ]]; then
      git remote remove origin # avoid push to wrong remote
    fi

    if [[ ! $(docker images | grep "$IMAGE") ]]; then
      echo "Docker $IMAGE not found!"
      echo "Warning! We will now download 1.6 GB (but only once)"
      docker pull ubuntu:trusty
      docker pull fgrehm/devstep:v0.2.0
      docker pull akretion/voodoo
    fi


    VOLUMES="-v $PWD:$WORKDIR"
    odoo_dir=$(sed -n 's/^odoo-directory *= *\([^ ]*.*\)/\1/p' < $BUILDOUT)
    if [ ! -z "$odoo_dir" ]; then
      eval odoo_dir=$odoo_dir        # eval ~
      odoo_dir=$(dirname "$odoo_dir/fake") # expands to absolute path
      echo "assuming shared Odoo directory: $odoo_dir"
      VOLUMES="$VOLUMES -v $odoo_dir:$SHARED_ODOO_DIR"
    fi
    eggs_dir=$(sed -n 's/^eggs-directory *= *\([^ ]*.*\)/\1/p' < $BUILDOUT)
    if [ ! -z "$eggs_dir" ]; then
      eval eggs_dir=$eggs_dir        # eval ~
      eggs_dir=$(dirname "$eggs_dir/fake") # expands to absolute path
      echo "assuming shared eggs directory: $eggs_dir"
      [ ! -d "$eggs_dir" ] &&  mkdir -p "$eggs_dir"
      VOLUMES="$VOLUMES -v $eggs_dir:$SHARED_EGGS_DIR"
    fi
    echo "Entering Docker warp zone with shared volumes:"
    echo "$VOLUMES"

    [[ ! -z $SSH_KEY ]] && cp $SSH_KEY .id_rsa

    containers=$(docker ps -a | grep " $NAME " | awk '{ print $1 }') || true
    if [ ! -z $containers ]; then
      echo "killing existing container(s)"
      docker rm -v -f $containers 2>/dev/null || true
    fi

    nc -z 127.0.0.1 "$PORT"
    while [ $? = 0 ]
    do
      echo "WARNING port $PORT seems busy, trying to offset ports"
      PORT=$((PORT+10))
      POLLING_PORT=$((POLLING_PORT+10))
      nc -z 127.0.0.1 "$PORT"
    done
    echo "Odoo will run on port $PORT"
    PORTS="-p $PORT:8069 -p $POLLING_PORT:8072"

    docker run $START_OPTIONS -e POSTGRESQL_DB="$POSTGRESQL_DB" \
               -e POSTGRESQL_DATA="$POSTGRESQL_DATA" \
               -u $DOCKER_USER \
               --rm=$DOCKER_RM --name $NAME $PORTS $VOLUMES -w "$WORKDIR" $IMAGE \
               -- /bin/bash -c "'$WORKDIR/ak $@'"

  else
    exec ssh "$SSH_USER@$SERVER" "$@"
  fi


# *****************************************************************************
else # when we are inside of the container

  [[ -f /workspace/.id_rsa ]] && mkdir -p /.devstep/.ssh && mv /workspace/.id_rsa /.devstep/.ssh/id_rsa

  export PYTHONPATH=$PYTHONPATH:$PIP_DIR
  if [ ! -d $PIP_DIR ]; then
    # NOTE sadly we cannot persit .pip_packages inside /workspace
    # because of this pip bug https://github.com/pypa/pip/issues/1489
    [ ! $(cat requirements.txt | grep -v "^#" | grep "[a-z]" | wc -l) = "0" ] && \
    echo "installing requirements.txt with pip" && \
    pip install -r requirements.txt --target=$PIP_DIR
  fi

  if [ -d $SHARED_EGGS_DIR ]; then
    eggs_dir="$SHARED_EGGS_DIR"
    if [ ! $(ls "$SHARED_EGGS_DIR" | grep reportlab) ]; then
      echo "initializing shared host eggs directory from Docker image"
      sudo chown -R $DOCKER_USER $eggs_dir
      cp "$IMAGE_EGGS_DIR"/. $eggs_dir -R
    fi
  else
    eggs_dir="eggs"
  fi

  if [ ! -f bin/buildout ]; then 
    echo "Bootstrapping Buildout..."
    cd /tmp
    cp "$WORKDIR/buildout.cfg" .
    sudo pip install --upgrade setuptools
    wget https://raw.github.com/buildout/buildout/master/bootstrap/bootstrap.py
    python bootstrap.py --allow-site-packages
    cp -rf bin "$WORKDIR/bin"
    cd "$WORKDIR"
  fi

  [ ! -d parts ] && mkdir parts

  if [ -f "$SHARED_ODOO_DIR"/setup.py ]; then
    [ ! -f parts/odoo/setup.py ] && ln -s "$SHARED_ODOO_DIR" parts/odoo
  fi


  case $1 in # Command dispatch ***********************************************

  run)
    shift
    [ ! -f bin/start_openerp ] || [ ! -f parts/odoo/setup.py ] && \
    export FROM_BASH=true && ak build
    ak wait_postgres
    python bin/start_openerp "$@"
    ;;

  debug)
    shift
    ak wait_postgres
    python bin/start_openerp "$@" "--debug"
    ;;

  build)
    shift

    if [ ! -d parts/odoo ]; then
    cat<<EOF

      WARNING you didn't set any valid existing odoo repo in your
      buildout.dev.cfg odoo-directory.
      If you continue, the recipe will do a FULL CLONE of Odoo into this
      directory, this clone will download ~400 Mo and can take a while...

      Alternatively you can abort and close the container and set a valid
      existing odoo-directory in buildout.dev.cfg if you already have some
      with the right branch on your computer.

      will now clone odoo...

EOF
    fi

    echo "building project with Anybox Buildout recipe..."
    if [ -d /etc/service/postgresql ]; then
      python bin/buildout "$@" "-c" "$BUILDOUT" "buildout:eggs-directory=$eggs_dir" \
      "buildout:openerp-downloads-directory=/.devstep/addons/voodoo/downloads" \
      "buildout:develop-eggs-directory=/.devstep/addons/voodoo/develop-eggs" \
      "openerp:options.db_user=$DOCKER_USER" "openerp:options.db_name=db" "openerp:options.data_dir=.filestore"
    else
      python bin/buildout "$@" "-c" "$BUILDOUT" "buildout:eggs-directory=$eggs_dir"
    fi
    ;;

  up)
    shift
    export FROM_BASH=true
    ak build
    ak run "$@"
    ;;

  console)
    shift
    ak wait_postgres
    python bin/python_openerp "$@"
    ;;

  psql)
    shift
    ak wait_postgres
    if [ -z "$1" ]; then
      psql db
    else
      psql "$@"
    fi
    ;;

  wait_postgres)
    [ ! -d /etc/service/postgresql ] && exit
    [ -f /.devstep/log/postgresql.log ] && r=$(grep "ready to accept connections" /.devstep/log/postgresql.log)
    [ -z "$r" ] && echo "waiting for Postgresql embedded server to start..."
    while [ -z "$r" ]
    do
      sleep 0.1
      [ -f  /.devstep/log/postgresql.log ] && r=$(grep "ready to accept connections" /.devstep/log/postgresql.log)
    done
    sleep 0.01
    if [ -z "$(psql -l | grep db | grep $DOCKER_USER)" ]; then
      sleep 0.3
      psql -c "ALTER DATABASE db OWNER TO $DOCKER_USER;"
      sleep 0.3
    fi
    exit
    ;;

  help)
    cat<<EOF

    available commands are:
    run, debug, build, up, console, psql, help

EOF
    ;;

  *)
    [ ! -z "$1" ] && exec ssh "$SSH_USER@$SERVER" "$@"
    ;;

  esac


  [ "$FROM_BASH" != true ] && export FROM_BASH=true && exec /bin/bash
fi
