#!/usr/bin/env bash

if [[ "$USE_HOST_HOME" = "yes" && "$USE_HOME_BIN" = "yes" && -r ~/home-host/bin ]]; then
    cp -a ~/home-host/bin ~
    rm ~/bin/*.exe ~/bin/*.bat 2>/dev/null || true
    dos2unix ~/bin/* || true
fi

if [ "$USE_AWS" = "yes" ]; then
    if [[ "$USE_HOST_HOME" = "yes" && -r ~/home-host/.aws ]]; then
        echo "Using host .aws folder"
        if [ "$USE_AWS_SYMLINK" = "yes" ]; then
          ln -s ~/home-host/.aws ~/.aws
        else
          cp -a ~/home-host/.aws ~
          dos2unix ~/.aws/*
        fi
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
    pulumi plugin install resource azure-native
    pulumi plugin install resource postgresql
    pulumi plugin install resource mysql
fi

if [[ -n "$PROXY_URL" && "$PROXY_AUTO_EXPORT_ENV" = "yes" ]]; then
  export HTTP_PROXY=$PROXY_URL
  export HTTPS_PROXY=$PROXY_URL_SSL
fi

if [[ -n "$USE_PROXY" && "$USE_PROXY" != "no" && "$USE_PROXY_CA" = "yes" ]]; then
  if [ -r /workspace/proxy_volume/mitmproxy-ca-cert.pem ]; then
    echo "Setting up proxy CA..."
    cp /workspace/proxy_volume/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
    update-ca-certificates
    cat /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt >> "$(python -m certifi)"
    export AWS_CA_BUNDLE=/usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
  else
    echo "Unable to locate mitmproxy-ca-cert.pem. Please ensure the proxy_volume is mounted"
  fi
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
