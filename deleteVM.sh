##!/bin/sh
# ESXi Scripts - VM creation

echo "    _________  ___             __     "
echo "   / __/ __/ |/_(_) ___ ___ __/ /____ "
echo "  / _/_\ \_>  </ / / _ \`/ // / __/ _ \\"
echo " /___/___/_/|_/_/  \_,_/\_,_/\__/\___/"
echo "  @MemoriasIT - Dec/2019 "
echo 

# %%%%%%%%%%%%%%%% INTIIAL VALUES %%%%%%%%%%%%%%%%
                    # >>  General info
DATASTOREPATH=$1            # /vmfs/volumes/datastore1/
VMNAME=$2                   # vm-name
    
                    # >>  Graceful shutdown
WAITTIME=$3                 # time to wait in s for gracefull power off
TRIES=$4                    # number of tries to wait


# %%%%%%%%%%%%%%%%   FUNCTIONS   %%%%%%%%%%%%%%%%
# Print Help if required
help(){
    echo "[!] - WAIT TIME AND TRIES REQUIRE VMWARE TOOLS INSTALLED!"
    echo "(Do not specify them if not installed!)"
    echo ""
    echo "Usage: ./deleteVM.sh datastorepath vmname waittime tries"
    echo ""
    echo "\$1 - datastorepath: full path to the datastore"
    echo "\$2 - vmname: name for the VM"
    echo "\$3 - waittime: time to wait in s for gracefull power off"
    echo "\$4 - tries: number of tries to wait"
    echo ""
}

# List all VMs
list_vm() { vim-cmd vmsvc/getallvms | tail -n +2 | egrep "[[:digit:]]+[[:space:]]+$1[[:space:]]"; } #Use: list_vm vm_name

# Check if machine exists
exist_vm() { list_vm $1 >/dev/null ; }          #Use: exist_vm vm_name

# Try graceful shutdown, if fail -> force shutdown
gracefulShutdown() {
    vim-cmd vmsvc/power.getstate $VMID | grep -i "off\|Suspended" > /dev/null 2<&1
    ERRNO=$?

    if [ $ERRNO -ne 0]; then
        if [ $TRY -lt $TRIES]; then
            echo "[~] Waiting for graceful shutdown, TRY:"$TRY
            TRY=$($TRY +1)
            sleep $WAITTIME
            gracefulShutdown
        fi
    else
        echo "[!] Sometimes killing is the only option, enjoy last "$VMNAME"\'s beep boop..."
        vim-cmd vmsvc/power.off $VMID
        sleep $WAITTIME
    fi

}

# %%%%%%%%%%%%%%%% INITIAL CHECK %%%%%%%%%%%%%%%%
# if no arguments passed
if [ $# -eq 0 ]; then
    help
    exit 3
fi


# Check if VM exists
exist_vm $VMNAME
if [ $? -ne 0 ]; then
    echo "[!] A machine with the name $VMNAME doesn't exists, try another one."
    exit 3
fi


# %%%%%%%%%%%%%%%%  CONFIRMATION  %%%%%%%%%%%%%%%%
# Confirmation to erase
read -p "[!] The machine $VMNAME will be erased completely, are you sure (y/n)?" choice
case "$choice" in 
  y|Y ) echo "Erasing...";;
  n|N ) exit 0;;
  *   ) echo "Invalid option"; exit 3;;
esac


# %%%%%%%%%%%%%%%%  SWITCH OFF  %%%%%%%%%%%%%%%%
VMID=$(list_vm $VMNAME | awk '{print $1}';)
# Switch off machine if needed
vim-cmd vmsvc/power.getstate $VMID | grep -i "off\|Suspended" > /dev/null 2<&1
ERRNO=$?

# Check if it's needed and shutdown (try graceful if possible)
if [ $ERRNO -ne 0 ]; then
    # vmware tools installed, graceful shutdown
    if [ $# -gt 2 ]; then
        echo "Graceful shutdown of VM: "$VMNAME
        vim-cmd vmsvc/power.shutdown $VMID

        TRY=0
        gracefulShutdown
    else
        echo "[!] VMware Tools not installed, gracefull shutdown not available..."
        vim-cmd vmsvc/power.off $VMID
    fi

    echo "[~] TANG0 D0WN"
else
    echo "[~] VM "$VMNAME" was already powered off."
fi


# %%%%%%%%%%%%%%%%  DESTROY VM  %%%%%%%%%%%%%%%%
# Destroy VM
echo "[~] Evidence now will be destroyed..."
vim-cmd vmsvc/destroy $VMID
# Unregister not required in my version: vim-cmd vmsvc/unregister $VMID

#Listar todas las máquinas para comprobar que se ha borrado
echo "[!] DONE - Listing all VMs"
vim-cmd vmsvc/getallvms


