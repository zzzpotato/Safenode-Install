# SafeNode Install
Bash script for easily installing a SafeNode on a linux vps

Note: This script is a beta and has only been tested on ubuntu 18.04. Report any bugs and I will do my best to fix them.

## Create a sudo user so you are not running as root
Replace username with an actual username such as "safenode"
```
adduser username
usermod -aG sudo username
su username
cd ~
```

## Run the script
```
MYSAFEKEY=PASTE_YOUR_SAFE_KEY_HERE
bash -c "$(wget -qO - https://raw.githubusercontent.com/zzzpotato/Safenode-Install/master/install-safenode.sh)" '' $MYSAFEKEY
```

## Thanks

If you need assistance or find an issue within the script, contact me on discord at potato#4515 and I will try to help you resolve it. 
