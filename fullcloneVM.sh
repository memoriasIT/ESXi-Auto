##!/bin/sh

echo "    _________  ___             __     "
echo "   / __/ __/ |/_(_) ___ ___ __/ /____ "
echo "  / _/_\ \_>  </ / / _ \`/ // / __/ _ \\"
echo " /___/___/_/|_/_/  \_,_/\_,_/\__/\___/"
echo "  @MemoriasIT - Dec/2019 "
echo 


# %%%%%%%%%%%%%%%% INTIIAL VALUES %%%%%%%%%%%%%%%%
                    # >>  General info
DATASTOREPATH=$1        # /vmfs/volumes/datastore1/
VMNAME=$2               # vm name to copy
VMCLONENAME=$3          # vm name that will be produced
                    # >>  Graceful shutdown
WAITTIME=$4             # time to wait in s for gracefull power off
TRIES=$5                # number of tries to wait


# %%%%%%%%%%%%%%%%   FUNCTIONS   %%%%%%%%%%%%%%%%
# Print Help if required
help(){
    echo ""
    echo "[!] - WAIT TIME AND TRIES REQUIRE VMWARE TOOLS INSTALLED!"
    echo "(Do not specify them if not installed!)"
    echo ""
    echo "Usage: ./fullcloneVM.sh datastorepath vmname vmclonename"
    echo ""
    echo "\$1 - datastorepath: full path to the datastore"
    echo "\$2 - vmname: name for the VM"
    echo "\$3 - vmclonename: name that will be produced with the clone"
    echo "\$4 - waittime: time to wait in s for gracefull power off"
    echo "\$5 - tries: number of tries to wait"
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

# Check if VM to clone exists
exist_vm $VMNAME
if [ $? -ne 0 ]; then
    echo "[!] A machine to clone with the name $VMNAME doesn't exists, try another one."
    exit 3
fi

# Check if clone name doesn't already exist
exist_vm $VMCLONENAME
if [ $? -eq 0 ]; then
    echo "[!] A machine with the name $VMCLONENAME does exists, a clone won't be created."
    exit 3
fi

# %%%%%%%%%%%%%%%%  SWITCH OFF  %%%%%%%%%%%%%%%%
VMID=$(list_vm $VMNAME | awk '{print $1}';)
# Switch off machine if needed
vim-cmd vmsvc/power.getstate $VMID | grep -i "off\|Suspended" > /dev/null 2<&1
ERRNO=$?

# Check if it's needed and shutdown (try graceful if possible)
if [ $ERRNO -ne 0 ]; then
    # vmware tools installed, graceful shutdown
    if [ $# -gt 3 ]; then
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



# %%%%%%%%%%%%%%%% COPY AND REG  %%%%%%%%%%%%%%%%
# Create future clone, basic vm with dummyvm
VMID="$(vim-cmd vmsvc/createdummyvm "$VMCLONENAME" "$DATASTOREPATH$VMCLONENAME/$VMCLONENAME")"

# Copy .vmx and disk
cp -i $DATASTOREPATH$VMNAME/$VMNAME.vmx $DATASTOREPATH$VMCLONENAME/$VMCLONENAME.vmx
echo "[~] Copying disk..."
vmkfstools -i $DATASTOREPATH$VMNAME/$VMNAME.vmdk  $DATASTOREPATH$VMCLONENAME/$VMCLONENAME.vmdk

# Avoid "I copied it" prompt
# You can also do: vim-cmd vmsvc/message $VMID 0 2 -> answer question 0 with option 2 (copied it)
echo uuid.action = "create" >> $DATASTOREPATH$VMCLONENAME/$VMCLONENAME.vmx

# Register VM
echo "[~] VM is getting registered"
vim-cmd solo/registervm $DATASTOREPATH$VMCLONENAME/$VMCLONENAME.vmx



# %%%%%%%%%%%%%%%% FIX NEW VMX   %%%%%%%%%%%%%%%%
sed -i "s/$VMNAME/$VMCLONENAME/" $DATASTOREPATH$VMCLONENAME"/"$VMCLONENAME".vmx"
sed -i "s/$VMNAME/$VMCLONENAME/" $DATASTOREPATH$VMCLONENAME"/"$VMCLONENAME".vmx"


# %%%%%%%%%%%%%%%% LIST AND POWER UP %%%%%%%%%%%%%%%%
# List all VMs to check if present
echo "[~] List of all VMs:"
vim-cmd vmsvc/getallvms

# Power on VM
VMCLONEID=$(list_vm $VMCLONENAME | awk '{print $1}';)
vim-cmd vmsvc/power.on $VMCLONEID




