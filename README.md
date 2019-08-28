# Creating A SafeNode Paper Wallet 
     
Remember to store the recovery phrase or password, ideally in more than one place. Do not lose these otherwise your SafeCoins will be lost. It is not recommended to import your SafeNode private keys into a desktop wallet. After creating a paper wallet, you will need to fund the collateral address. To start receiving rewards, an amount of 10,000 SafeCoin is needed minimum. You will need a Safekey (not private key) to setup your SafeNode.
    
     https://safenodes.org/

     https://apps.apple.com/us/app/safepay-cryptocurrency-wallet/id1465180332?ls=1

     https://play.google.com/store/apps/details?id=org.safecoin.safepay 

     https://safepay.safecoin.org/

# SafeNode Install
Bash script for easily installing a SafeNode on a linux vps

Note: This script is a beta and has only been tested on Ubuntu 16.04 (Thanks Stinkfist), 18.04, and 19.04. Report any bugs and I will do my best to fix them.

## Create a sudo user so you are not running as root
Replace username with an actual username such as "safenode"
```
adduser username
usermod -aG sudo username
su - username
```

## Run the script and enter your SafeKey when prompted
```
bash -c "$(wget -qO - https://raw.githubusercontent.com/zzzpotato/Safenode-Install/master/install-safenode.sh)"
```

## Thanks

If you need assistance or find an issue within the script, contact me on discord at potato#9721 and I will try to help you resolve it. For large issues, you may need to open an issue on the repo so it can be addressed.
