#!/bin/bash

######################################
## SafeNode Setup Tool v0.10        ##
## Special thanks to:               ##
## @Team Safe                       ##
## @Safers                          ##
## Oleksandr                        ##
## Potato                           ##
######################################
######################################

### Check user
if [ "$EUID" -eq 0 ]
  then
        echo -e "Warning: You should not run this as root! Create a new user with sudo permissions!\nThis can be done with (replace username with an actual username such as node):\nadduser username\nusermod -aG sudo username\nsu username\ncd ~\n\nYou will be in a new home directory. Make sure you redownload the script or move it from your /root directory!"
        exit
fi

### Check if safekey was added
if [ -z "$1" ]
    then
        echo -e "No SafeKey supplied. Start over with your SafeKey included..."
        exit
fi

### Change to home dir (just in case)
cd ~

### Kill any existing processes
echo -e "Stopping any existing services..."
killall -9 safecoind

## Setup Vars
GENPASS="$(date +%s | sha256sum | base64 | head -c 32 ; echo)"
confFile=~/.safecoin/safecoin.conf

### Prereq
echo -e "Setting up prerequisites and updating the server..."
sudo apt-get update -y
sudo apt-get install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python python-zmq zlib1g-dev wget libcurl4-gnutls-dev bsdmainutils automake curl bc dc jq nano gpw -y


### Fetch Params
echo -e "Fetching Zcash-params..."
bash -c "$(wget -O - https://raw.githubusercontent.com/Fair-Exchange/safecoin/master/zcutil/fetch-params.sh)"

### Setup Swap
echo -e "Adding swap if needed..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

### Build Daemon
#cd ~ && git clone https://github.com/fair-exchange/safecoin --branch master --single-branch
#cd safecoin
#./zcutil/build.sh -j$(nproc)

### Download Daemon
echo -e "Grabbing the latest daemon..."
if [ ! -f safecoind ]; then
    echo -e "Found old binaries... Deleting them..."
    rm safecoind
    rm safecoin-cli
fi
wget -N https://github.com/Fair-Exchange/safewallet/releases/download/data/binary_linux.zip -O ~/binary.zip
unzip -o ~/binary.zip -d ~
rm ~/binary.zip
chmod +x safecoind safecoin-cli

### Initial .safecoin/
if [ ! -d ~/.safecoin ]; then
    echo -e "Created .safecoin directory..."
    mkdir .safecoin
fi
rm $confFile

### Download bootstrap
if [ ! -d ~/.safecoin/blocks ]; then
    echo -e "Grabbing the latest bootstrap (to speed up syncing)..."
    wget -N https://github.com/Fair-Exchange/safewallet/releases/download/data/blockchain_txindex.zip
    unzip -o ~/blockchain_txindex.zip -d ~/.safecoin
    rm ~/blockchain_txindex.zip
fi

### Final conf setup
if [ ! -f $confFile ]; then
    ### Grab current height
    HIGHESTBLOCK="$(wget -nv -qO - https://explorer.safecoin.org/api/blocks\?limit=1 | jq .blocks[0].height)"

    ### Write to safecoin.conf
    touch $confFile
    rpcuser=$(gpw 1 30)
    echo "rpcuser="$rpcuser >> $confFile
    rpcpassword=$(gpw 1 30)
    echo "rpcpassword="$rpcpassword >> $confFile
    echo "addnode=explorer.safecoin.org" >> $confFile
    echo "addnode=explorer.deepsky.space" >> $confFile
    echo "addnode=dnsseed.local.support" >> $confFile
    echo "addnode=dnsseed.fair.exchange" >> $confFile
    echo "rpcport=8771" >> $confFile
    echo "port=8770" >> $confFile
    echo "listen=1" >> $confFile
    echo "server=1" >> $confFile
    echo "txindex=1" >> $confFile
    echo "daemon=1" >> $confFile
    echo "parentkey=0333b9796526ef8de88712a649d618689a1de1ed1adf9fb5ec415f31e560b1f9a3" >> $confFile
    if echo $1; then
        echo "safekey=$1" >> $confFile
    fi
    echo "safepass=$GENPASS" >> $confFile
    echo "safeheight=$HIGHESTBLOCK" >> $confFile
fi

### Setup Service
echo -e "Creating service file..."

service="echo '[Unit]
Description=SafeNodes daemon
After=network-online.target
[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=$HOME/safecoind
WorkingDirectory=$HOME/.safecoin
User=$USER
KillMode=mixed
Restart=always
RestartSec=10
TimeoutStopSec=10
Nice=-20
ProtectSystem=full
[Install]
WantedBy=multi-user.target' >> /lib/systemd/system/safecoinnode.service"

echo $service
sudo sh -c "$service"

### Fire up the engines
./safecoind -daemon > /dev/null
sudo systemctl enable --now safecoinnode.service

sleep 5
x=1
echo "Waiting for startup to complete"
sleep 15
while true ; do
    echo "Wallet is opening, please wait. This step will take few minutes ($x)"
    sleep 1
    x=$(( $x + 1 ))
    ./safecoin-cli getinfo &> text.txt
    line=$(tail -n 1 text.txt)
    if [[ $line == *"..."* ]]; then
        echo $line
    fi
    if [[ $(tail -n 15 text.txt) == *"connections"* ]]; then
        echo
        echo "SafeNode successfully configured and launched!"
        echo
        echo "SafeKey: $1"
        echo "ParentKey: 0333b9796526ef8de88712a649d618689a1de1ed1adf9fb5ec415f31e560b1f9a3"
        echo "SafePass: $GENPASS"
        echo "SafeHeight: $HIGHESTBLOCK"
        echo
        sudo systemctl status safecoinnode
        break
    fi
	rm ~/text.txt
done
