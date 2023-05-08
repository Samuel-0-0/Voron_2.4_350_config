#!/bin/bash


#####################################################################
### Please set the paths accordingly. In case you don't have all  ###
### the listed folders, just keep that line commented out.        ###
#####################################################################
### Path to your config folder you want to backup
config_folder=~/printer_data

### Path to your Klipper folder, by default that is '~/klipper'
klipper_folder=~/klipper

### Path to your Moonraker folder, by default that is '~/moonraker'
moonraker_folder=~/moonraker

### Path to your Mainsail folder, by default that is '~/mainsail'
mainsail_folder=~/mainsail

### Path to your Fluidd folder, by default that is '~/fluidd'
fluidd_folder=~/fluidd

#####################################################################
#####################################################################


#####################################################################
################ !!! DO NOT EDIT BELOW THIS LINE !!! ################
#####################################################################
grab_version(){
  if [ ! -z "$klipper_folder" ]; then
    echo -n "Getting klipper version="
    cd "$klipper_folder"
    klipper_commit=$(git rev-parse --short=7 HEAD)
    m1="Klipper: $klipper_commit"
    echo $klipper_commit
    cd ..
  fi
  if [ ! -z "$moonraker_folder" ]; then
    echo -n "Getting moonraker version="
    cd "$moonraker_folder"
    moonraker_commit=$(git rev-parse --short=7 HEAD)
    m2="Moonraker: $moonraker_commit"
    echo $moonraker_commit
    cd ..
  fi
  if [ ! -z "$mainsail_folder" ]; then
    echo -n "Getting mainsail version="
    mainsail_ver=$(head -n 1 $mainsail_folder/.version)
    m3="Mainsail: $mainsail_ver"
    echo $mainsail_ver
  fi
  if [ ! -z "$fluidd_folder" ]; then
    echo -n "Getting fluidd version="
    fluidd_ver=$(head -n 1 $fluidd_folder/.version)
    m4="Fluidd: $fluidd_ver"
    echo $fluidd_ver
  fi
}

push_config(){
  cd $config_folder
  echo Pushing updates ...
  #从远程仓库拉取更新
  git pull -v
  #合并
  git add . -v
  current_date=$(date +"%Y-%m-%d %T")
  read -p "Content:" babala
  git commit -m "$babala[$m1,$m2,$m3,$m4]"
  git push
}

grab_version
push_config
