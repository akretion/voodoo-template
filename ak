#!/usr/bin/env bash
# This command is a bit like a Makefile: if your are outside a Docker 
# container it will send you inside a new Docker container and then it
# will give you shortcuts to main project commands.

IMAGE=${IMAGE:="akretion/voodoo"}
PORT=${PORT:="8069"}
POLLING_PORT=${POLLING_PORT:="8072"}
SSH_USER=${SSH_USER:="api"}
SERVER=${SERVER:="$2.akretion.com"}


if [ ! -d /.devstep ]; then
  # we are out of the container, this is the bash equivalent of Vagrant with the Docker provider:
  in_container=false
  if [[ -z $1 || $1 == "up" || $1 == "run" || $1 == "build" || $1 == "debug" || $1 == "console" && -z $2 || $1 == "psql" || $1 == "help" ]]; then

    if [[ ! -z "$(git remote -v | grep origin | grep "github.com/akretion/voodoo")" ]]; then
      git remote remove origin # avoid Akretion team to re-push accidentally on repo
    fi

    if [[ ! $(docker images | grep "$IMAGE") ]]; then
      echo "Socker $IMAGE not found!"
      echo "Warning! We will now download 1.6 GB (but only once)"
      docker pull ubuntu:trusty
      docker pull fgrehm/devstep:v0.1.0
      docker pull akretion/voodoo
    fi


    VOLUMES="-v $PWD:/workspace"
    odoo_dir=$(sed -n 's/^odoo-directory *= *\([^ ]*.*\)/\1/p' < buildout.dev.cfg)
    if [ ! -z "$odoo_dir" ]; then
      eval odoo_dir=$odoo_dir        # eval ~
      odoo_dir=$(dirname "$odoo_dir/fake") # expands to absolute path
      echo "assuming shared Odoo directory: $odoo_dir"
      VOLUMES="$VOLUMES -v $odoo_dir:/.devstep/addons/voodoo/odoo"
    fi
    eggs_dir=$(sed -n 's/^eggs-directory *= *\([^ ]*.*\)/\1/p' < buildout.dev.cfg)
    if [ ! -z "$eggs_dir" ]; then
      eval eggs_dir=$eggs_dir        # eval ~
      eggs_dir=$(dirname "$eggs_dir/fake") # expands to absolute path
      echo "assuming shared eggs directory: $eggs_dir"
      [ ! -d "$eggs_dir" ] &&  mkdir -p "$eggs_dir"
      VOLUMES="$VOLUMES -v $eggs_dir:/.devstep/addons/voodoo/host_eggs"
    fi
    echo "Entering Docker warp zone with shared volumes:"
    echo "$VOLUMES"


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


    docker run -ti -e POSTGRESQL_DB=db -e POSTGRESQL_DATA=/workspace/.db --rm=true --name voodoo-${PWD##*/} $PORTS $VOLUMES -w /workspace $IMAGE -- /bin/bash -c "'/workspace/ak $@'"
    exit

  else
    api=true
  fi


else # when we are inside the container
  in_container=true
  export PYTHONPATH=$PYTHONPATH:/.devstep/.pip_packages
  eggs_dir=/.devstep/addons/voodoo/host_eggs
  if [ -d $eggs_dir ]; then
    if [ ! $(ls "$eggs_dir" | grep reportlab) ]; then
      echo "initializing shared host eggs directory from Docker image"
      sudo chown -R developer $eggs_dir
      cp /.devstep/addons/voodoo/eggs/. $eggs_dir -R
    fi
  else
    eggs_dir=/.devstep/addons/voodoo/eggs
  fi

  if [ ! -f bin/buildout ]; then 
    echo "Bootstrapping Buildout..."
    cd /tmp
    cp /workspace/buildout.cfg .
    wget https://raw.github.com/buildout/buildout/master/bootstrap/bootstrap.py
    python bootstrap.py --allow-site-packages
    cp -rf bin /workspace/bin
    cd /workspace
  fi

  if [ ! -d /.devstep/.pip_packages ]; then
    PROJECT_PIP_DIR=/.devstep/.pip_packages
    # NOTE sadly we cannot persit .pip_packages inside /workspace because of this pip bug https://github.com/pypa/pip/issues/1489
    # TODO see if Devstep has a better solution for this
    [ ! $(cat requirements.txt | grep -v "^#" | grep "[a-z]" | wc -l) = "0" ] && \
    echo "installing requirements.txt with pip" && \
    pip install -r requirements.txt --target=$PROJECT_PIP_DIR
    export PYTHONPATH=$PYTHONPATH:$PROJECT_PIP_DIR
  fi

  [ ! -d parts ] && mkdir parts
  [ -f /.devstep/addons/voodoo/odoo/setup.py ] && [ ! -f parts/odoo/setup.py ] && ln -s /.devstep/addons/voodoo/odoo parts/odoo


  case $1 in

  wait_postgres)
    [ -f /.devstep/log/postgresql.log ] && r=$(grep "ready to accept connections" /.devstep/log/postgresql.log)
    [ -z "$r" ] && echo "waiting for Postgresql embedded server to start..."
    while [ -z "$r" ]
    do
      sleep 0.1
      [ -f  /.devstep/log/postgresql.log ] && r=$(grep "ready to accept connections" /.devstep/log/postgresql.log)
    done
    sleep 0.01
    if [ -z "$(psql -l | grep db | grep developer)" ]; then
      sleep 0.3
      psql -c 'ALTER DATABASE db OWNER TO developer;'
      sleep 0.3
    fi
    exit
    ;;

  run)
    shift
    [ ! -f bin/start_openerp ] || [ ! -f parts/odoo/setup.py ] && export FROM_BASH=true && ak build
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

    if [ ! -d /workspace/parts/odoo ]; then
    cat<<EOF

      WARNING you didn't set any valid existing odoo repo in your buildout.dev.cfg odoo-directory
      if you continue the recipe will do a FULL CLONE of Odoo into this directory
      this clone will download ~400 Mo and can take a while...

      Alternatively you can abort and close the container and set a valid existing odoo-directory
      in buildout.dev.cfg if you already have some with the right branch on your computer.

      will now clone odoo...

EOF
    fi

    echo "building project with Anybox Buildout recipe..."
    python bin/buildout "$@" "-c" "buildout.dev.cfg" \
    "buildout:eggs-directory=$eggs_dir" \
    "buildout:openerp-downloads-directory=/.devstep/addons/voodoo/downloads" \
    "buildout:develop-eggs-directory=/.devstep/addons/voodoo/develop-eggs" \
    "openerp:options.db_user=developer" "openerp:options.db_name=db" "openerp:options.data_dir=.filestore"
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

  help)
    cat<<EOF

    available commands are:
    run, debug, build, up, console, psql, help

EOF
    ;;

  *)
    [ ! -z "$1" ] && api=true
    ;;

  esac

fi


[ "$1" = "api" ] && args="help" || args="$@"
[ "$api" = true ] && exec ssh "$SSH_USER@$SERVER" "$args"
[ "$FROM_BASH" != true ] && [ "$in_container" = true ] && export FROM_BASH=true && exec /bin/bash
