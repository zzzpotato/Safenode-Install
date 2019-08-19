#!/bin/bash
clear

######################################
## SafeNode Setup Tool v0.13        ##
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
        clear
        echo -e "Warning: You should not run this as root! Create a new user with sudo permissions!\nThis can be done with (replace username with an actual username such as node):\nadduser username\nusermod -aG sudo username\nsu username\ncd ~\n\nYou will be in a new home directory. Make sure you redownload the script or move it from your /root directory!"
        exit
fi

### Check if safekey was added
if [ -z "$1" ]
    then
        clear
        echo -e "No SafeKey supplied. Start over with your SafeKey included..."
        exit
fi

### Confirm SafeKey before continuing
length=${#1}
if [ "$length" == 66 ]
then
    clear
    echo -e "Is \"$1\" the correct SafeKey you would like to use for this installation?"
    read -p "Y/n: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            clear
            echo -e "Please re-run the script with the correct SafeKey!"
            exit
        fi
else
    echo -e "Double check you have entered the correct SafeKey in full!"
    exit
fi

### Change to home dir (just in case)
cd ~

### Kill any existing processes
echo -e "Stopping any existing SafeNode services..."
sudo systemctl stop safecoinnode
killall -9 safecoind

## Setup Vars
GENPASS="$(date +%s | sha256sum | base64 | head -c 32 ; echo)"
confFile=~/.safecoin/safecoin.conf
HIGHESTBLOCK="$(wget -nv -qO - https://explorer.safecoin.org/api/blocks\?limit=1 | jq .blocks[0].height)"

### Prereq
echo -e "Setting up prerequisites and updating the server..."
sudo apt-get update -y
sudo apt-get install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python python-zmq zlib1g-dev wget libcurl4-gnutls-dev bsdmainutils automake curl bc dc jq nano gpw -y


### Fetch Params
echo -e "Fetching Zcash-params..."
bash -c "$(wget -qO - https://raw.githubusercontent.com/Fair-Exchange/safecoin/master/zcutil/fetch-params.sh)"

### Setup Swap
echo -e "Adding swap if needed..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

### Check if old binaries exist
clear
if [ -f safecoind ]; then
    echo -e "Found old binaries... Deleting them..."
    rm safecoind
    rm safecoin-cli
fi

### Prompt user to build or download
echo -e "Would you prefer to build the daemon from source or download an existing daemon binary?"
echo -e "1 - Build from source"
echo -e "2 - Download binary"
read -p "Choose: " downloadOption

### Compile or Download based on user selection
if [ "$downloadOption" == "1" ]; then
    ### Build Daemon
    echo -e "Begin compiling of daemon..."
    if [ ! -d safecoin ]
    then
        cd ~ && git clone https://github.com/fair-exchange/safecoin --branch master --single-branch
    else
        cd safecoin && git pull
    fi
    cd safecoin
    ./zcutil/build.sh -j$(nproc)
    cd ~
    cp safecoin/src/safecoind safecoin/src/safecoin-cli .
    chmod +x safecoind safecoin-cli
else
    ### Download Daemon
    echo -e "Grabbing the latest daemon..."
    wget -N https://github.com/Fair-Exchange/safewallet/releases/download/data/binary_linux.zip -O ~/binary.zip
    unzip -o ~/binary.zip -d ~
    rm ~/binary.zip
    chmod +x safecoind safecoin-cli
fi

### Initial .safecoin/
if [ ! -d ~/.safecoin ]; then
    echo -e "Created .safecoin directory..."
    mkdir .safecoin
fi

### Download bootstrap
if [ ! -d ~/.safecoin/blocks ]; then
    echo -e "Grabbing the latest bootstrap (to speed up syncing)..."
    wget -N https://github.com/Fair-Exchange/safewallet/releases/download/data/blockchain_txindex.zip
    unzip -o ~/blockchain_txindex.zip -d ~/.safecoin
    rm ~/blockchain_txindex.zip
fi

### Check if safecoin.conf exists and prompt user about overwriting it
if [ -f "$confFile" ]
then
    clear
    echo -e "A safecoin.conf already exists. Do you want to overwrite it?"
    read -p "Y/n: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            rm -fv $confFile
        fi
fi

### Final conf setup
if [ ! -f $confFile ]; then
    ### Grab current height
    HIGHESTBLOCK="$(wget -nv -qO - https://explorer.safecoin.org/api/blocks\?limit=1 | jq .blocks[0].height)"
    if [ -z "$HIGHESTBLOCK" ]
    then
        clear
        echo -e "Unable to fetch current block height from explorer. Please enter it manually. You can obtain it from https://explorer.safecoin.org or https://explorer.deepsky.space/"
        read -p "Current Height: " HIGHESTBLOCK
    fi

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
else 
    clear
    echo -e "safecoin.conf exists. Skipping..."
fi

### Setup Service
echo -e "Creating service file..."

### Remove old service file
if [ -f /lib/systemd/system/safecoinnode.service ]; then
  sudo systemctl disable --now safecoinnode.service
  sudo rm /lib/systemd/system/safecoinnode.service
fi

service="echo '[Unit]
Description=SafeNodes daemon
After=network-online.target
[Service]
User=$USER
Group=$USER
Type=forking
Restart=always
RestartSec=120
RemainAfterExit=true
ExecStart=$HOME/safecoind -daemon
ProtectSystem=full
[Install]
WantedBy=multi-user.target' >> /lib/systemd/system/safecoinnode.service"

#echo $service
sudo sh -c "$service"

### Fire up the engines
sudo systemctl enable safecoinnode.service
sudo systemctl start safecoinnode

echo "Safecoind started... Waiting for startup to finish"
sleep 60
newHighestBlock="$(wget -nv -qO - https://explorer.safecoin.org/api/blocks\?limit=1 | jq .blocks[0].height)"
currentBlock="$(~/safecoin-cli getblockcount)"

### We need to add some failed start detection here with troubleshooting steps
### error code: -28

if [ -z "$newHighestBlock" ]
then
    echo
    echo -e "Unable to fetch current block height from explorer. Please enter it manually. You can obtain it from https://explorer.safecoin.org or https://explorer.deepsky.space/"
    read -p "Current Height: " newHighestBlock
    newHighestBlockManual="$newHighestBlock"
fi

echo -e "Current Height is now $newHighestBlock"

while  [ "$newHighestBlock" != "$currentBlock" ]
do
    clear
    if [ -z "$newHighestBlockManual" ]
        then
            newHighestBlock="$(wget -nv -qO - https://explorer.safecoin.org/api/blocks\?limit=1 | jq .blocks[0].height)"
        else
            newHighestBlock="$newHighestBlockManual"
    fi
    currentBlock="$(~/safecoin-cli getblockcount)"
    echo "Comparing block heights to ensure server is fully synced every 10 seconds";
    echo "Highest: $newHighestBlock";
    echo "Currently at: $currentBlock";
    echo "Checking again in 10 seconds... The install will continue once it's synced.";echo
    echo "Last 10 lines of the log for error checking...";
    echo "===============";
    tail -10 ~/.safecoin/debug.log
    echo "===============";
    echo "Just ensure the current block height is rising over time...";
    sleep 10
done

clear
echo "Chain is fully synced with explorer height!"
echo
echo "SafeNode successfully configured and launched!"
echo
echo "SafeKey: $1"
echo "ParentKey: 0333b9796526ef8de88712a649d618689a1de1ed1adf9fb5ec415f31e560b1f9a3"
echo "SafePass: $GENPASS"
echo "SafeHeight: $HIGHESTBLOCK"
echo
echo "##################################################"
echo "Send 1 SAFE to the address below. This will power the SafeNode for 1 year!"
### Generate address to fuel safenode
~/safecoin-cli getnewaddress
echo "##################################################"
echo
echo -e "A message of \"Validate SafeNode\" will appear when your SafeNode Is activated. This will happen roughly 10 blocks after the safeheight above."
echo
echo -e "Checking the safecoind service status..."
### Check health of service
sudo systemctl status safecoinnode

if [ -d ~/safecoin ]
then
    echo -e "Cleaning up... Do you want to remove your safecoin build directory?"
    read -p "Y/n: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            rm -rf ~/safecoin
            echo -e "Build directory removed..."
        fi
fi

exit
