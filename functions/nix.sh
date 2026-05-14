nix_install_channel(){
  nix-channel add https://$1 $2
  nix-channel --update
}

nix_install(){
    if [[ $OS != "nix" && $NO_NIX != true ]];then
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
    else
        echo -e "nix wasn't installed: you either have nixOS or disabled nix in arguments."
    fi
}