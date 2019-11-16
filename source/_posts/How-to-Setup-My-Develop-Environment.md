---
title: How to Setup My Develop Environment
date: 2017-07-01 07:21:18
tags:
- howto
---

# How to Setup My Develop Environment

The following settings are based on Ubuntu 14.04 LTS.

## How to Setup GitHub Client

Follow this [official document](http://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) to setup GitHub auth key.

## How to Setup My rc Files

Follow my [dotfile](http://github.com/weasellin/dotfile)'s document to setup my `.bashrc`, `.inputrc`, and `.vimrc`.

Where the term, "rc", originated from could found in [here](http://stackoverflow.com/questions/11030552/what-does-rc-mean-in-dot-files).

## How to Setup Python pyenv

Follow this [document](http://github.com/pyenv/pyenv/wiki/Common-build-problems#requirements) to install required libraries:

```bash
$ sudo apt-get install -y \
    make \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev
```

Then by this [document](http://github.com/pyenv/pyenv-installer#github-way-recommended) to install pyenv:

```bash
$ curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash

...

# Load pyenv automatically by adding
# the following to ~/.bash_profile:

export PATH="/home/weasellin/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```

Install some python versions to pyenv:

```bash
$ pyenv install --list
   ...
$ pyenv install 2.7.8
$ pyenv install 3.6.0
$ pyenv install pypy3-2.4.0
$ pyenv versions
* system (set by /home/weasellin/.pyenv/version)
  2.7.8
  3.6.0
  pypy3-2.4.0
```

Create virtual env from installed versions:

```bash
$ pyenv virtualenv 2.7.8 myenv-2.7.8
$ pyenv virtualenv 3.6.0 myenv-3.6.0
$ pyenv virtualenv pypy3-2.4.0 myenv-pypy3-2.4.0
```

Activate & deactivate virtual env:

```bash
$ pyenv activate myenv-3.6.0
$ pyenv deactivate
```

## How to Setup Docker

Follow this [official document](http://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-repository) to install Docker CE.
Then be sure to follow the [post-install steps](http://docs.docker.com/engine/installation/linux/linux-postinstall/#manage-docker-as-a-non-root-user) to allow non-super-user to use docker.

```bash
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
$ sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $$(lsb_release -cs) \
      stable"
$ sudo apt-get update
$ sudo apt-get install docker-ce
$ sudo gpasswd -a ${USER} docker
$ newgrp docker
$ docker run hello-world
========================
Hello from Docker!
This message shows that your installation appears to be working correctly.
......
```
