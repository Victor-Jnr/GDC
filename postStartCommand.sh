#!/usr/bin/env bash

if [[ "$USE_HOST_HOME" = "yes" && "$USE_HOME_BIN" = "yes" && -r ~/home-host/bin ]]; then
    cp -a ~/home-host/bin ~
    rm ~/bin/*.exe ~/bin/*.bat 2>/dev/null || true
    dos2unix ~/bin/* || true
fi

if [ "$USE_AWS" = "yes" ]; then
    if [[ "$USE_HOST_HOME" = "yes" && -r ~/home-host/.aws ]]; then
        echo "Using host .aws folder"
        cp -a ~/home-host/.aws ~
        dos2unix ~/.aws/*
    elif [ -r ~/shared/.aws ]; then
        echo "Using container ~/shared/.aws folder"
        ln -s ~/shared/.aws ~/.aws
    else
        echo "Creating container ~/shared/.aws folder"
        mkdir -p ~/shared/.aws
        chmod 700 ~/shared/.aws
        ln -s ~/shared/.aws ~/.aws
    fi
    chmod og-rwx ~/.aws -R
fi

if [[ "$USE_HOST_HOME" = "yes" &&  -r ~/home-host/.gitconfig ]]; then
    echo "Copying .gitconfig from host"
    cp -a ~/home-host/.gitconfig ~
elif [ -n "$GIT_NAME" ]; then
    echo "Setting up new ~/.gitconfig"
    cat <<EOF >~/.gitconfig
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
EOF
else
    echo "No .gitconfig setup. please set (GIT_NAME and GIT_EMAIL) or USE_HOST_HOME environment variables"
fi

if [ -r /usr/local/pyenv ]; then
    export PYENV_ROOT=/usr/local/pyenv
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
#    eval "$(pyenv virtualenv-init -)"

    if [ "$USE_PRECOMMIT" = "yes" ]; then
        if [[ ! -r /workspace/.git/hooks/pre-commit ||  "$(grep -c "File generated by pre-commit" /workspace/.git/hooks/pre-commit)" = "0" ]]; then
            echo "installing pre-commit hooks..."
            cd /workspace && pre-commit install --allow-missing-config
        else
            echo "pre-commit hooks already installed, skipping..."
        fi
        if [ -r /workspace/.git/hooks/pre-commit.legacy ]; then
            rm /workspace/.git/hooks/pre-commit.legacy
        fi
    fi
elif [ "$USE_PRECOMMIT" = "yes" ]; then
    echo "USE_PRECOMMIT=yes but python is not enabled. Please set PYTHON_VERSION environment variable"
fi

if [ -n "$PULUMI_VERSION" ]; then
    pulumi plugin install resource docker
    pulumi plugin install resource command
    pulumi plugin install resource aws
    pulumi plugin install resource postgresql
    pulumi plugin install resource mysql
fi


#if [ "$USE_LOCALSTACK_DNS" = "yes" ]; then
#  if [ -z "$LS_MAIN_CONTAINER_NAME" ]; then
#    echo "LS_MAIN_CONTAINER_NAME is not set! Ignoring USE_LOCALSTACK_DNS..."
#  else
#    LS_IP=$(host -4 "$LS_MAIN_CONTAINER_NAME" | cut -d' ' -f4)
#    if [ -n "$LS_IP" ]; then
#      echo "LOCALSTACK IP $LS_IP"
#      echo "nameserver $LS_IP" > /tmp/resolv.conf
#      cp /etc/resolv.conf /etc/resolv.conf.org
#      cat /etc/resolv.conf >> /tmp/resolv.conf
#      mv /tmp/resolv.conf /etc/resolv.conf
#    else
#      echo "LOCALSTACK IP COULD NOT BE FOUND! Ignoring USE_LOCALSTACK_DNS..."
#    fi
#  fi
#fi


mkdir -p ~/.ssh
if [[ "$USE_HOST_HOME" = "yes" &&   -r ~/home-host/.ssh ]]; then
    cp -a ~/home-host/.ssh/* ~/.ssh
    dos2unix ~/.ssh/*
fi
chmod 700 ~/.ssh
chmod og-rwx ~/.ssh/*
chown -R root.root ~/.ssh
if [ -n "$SSH_KEYSCAN_HOSTS" ]; then
  ssh-keyscan $SSH_KEYSCAN_HOSTS >>~/.ssh/known_hosts
fi

#echo ~/.ssh/id_ed25519 | ssh-keygen -t ed25519 -N ''

if [ -n "$SSH_SERVER_PORT" ]; then
    echo "Enabling ssh server on host port $SSH_SERVER_PORT"
    systemctl enable ssh
    # ensure ssh is started
    service ssh restart
fi
