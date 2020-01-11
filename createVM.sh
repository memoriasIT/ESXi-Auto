
##!/bin/sh
# esxi scripts - vm creation

echo "    _________  ___             __     "
echo "   / __/ __/ |/_(_) ___ ___ __/ /____ "
echo "  / _/_\ \_>  </ / / _ \`/ // / __/ _ \\"
echo " /___/___/_/|_/_/  \_,_/\_,_/\__/\___/"
echo "  @memoriasit - dec/2019 "
echo ""

# %%%%%%%%%%%%%%%% intial values %%%%%%%%%%%%%%%%
datastorepath="$1"  # /vmfs/volumes/datastore1/
vmname=$2           # vm-name
vmtype=$3           # vm os/type
vmsize=$4           # vm size
netcards=$5         # number of netcards to add

# %%%%%%%%%%%%%%%%   functions   %%%%%%%%%%%%%%%%
# print help if required
help(){
    echo "Usage: ./create-vm.sh datastorepath vmname vmtype vmsize netcards"
    echo ""
    echo "\$1 - datastorepath: full path to the datastore"
    echo "\$2 - vmname: name for the VM"
    echo "\$3 - vmtype: OS of the VM"
    echo "\$4 - vmsize: a disk will be created with this size (size in bytes)"
    echo "\$5 - netcards: number of generic netcards to add"
    echo ""
}
# list all vms
list_vm() { vim-cmd vmsvc/getallvms | tail -n +2 | egrep "[[:digit:]]+[[:space:]]+$1[[:space:]]"; } #use: list_vm vm_name


# generate random MAC
# https://stackoverflow.com/questions/42660218/bash-generate-random-mac-address-unicast 
generate_mac(){
    hexdump -n 6 -ve '1/1 "%.2x "' /dev/random | awk -v a="2,6,a,e" -v r="$RANDOM" 'BEGIN{srand(r);}NR==1{split(a,b,",");r=int(rand()*4+1);printf "%s%s:%s:%s:%s:%s:%s\n",substr($1,0,1),b[r],$2,$3,$4,$5,$6}'

}

# check if machine exists
exist_vm() { list_vm $1 >/dev/null ; }          #use: exist_vm vm_name

# get id of a vm
get_vmid() { list_vm $1 | awk '{print $1}'; }   #use: exist_vm vm_name

# generate nic with unique id
generate_nic(){
    # get all used ids (only numbers, might be "not set")
    vmid=$1
    usedlist=" $(vim-cmd vmsvc/device.getdevices $vmid |grep unitNumber|grep -oe '[0-9]*'|xargs) "

    # find not used id
    count=0
    echo "$usedlist" |grep -q " $count " 
    while [ $? -eq 0 ]; do 
        count=$(($count + 1))
        echo "$usedlist" |grep -q " $count " 
    done

    # add generic nic
    vim-cmd vmsvc/devices.createnic $vmid $count "e1000" "VM Network"

    
}

# %%%%%%%%%%%%%%%% initial check %%%%%%%%%%%%%%%%
# if no arguments passed
if [ $# -eq 0 ]; then
    help
    exit 3
fi

# check if vm exists before of creating a duplicate
exist_vm $vmname
if [ $? -eq 0 ]; then
    echo "[!] A machine with the name "$vmname" already exists, try another one." >&2
    exit 3
fi

# %%%%%%%%%%%%%%%% generate .vmx %%%%%%%%%%%%%%%%
# create folder and .vmx with vm name 
mkdir $datastorepath$vmname

echo "[~] generating .vmx"
vmid=$(vim-cmd vmsvc/createdummyvm "$vmname" "$datastorepath")
echo "ID: "$vmid
# add netcards with all different ids and macs 
for i in $(seq 1 $netcards); do
    echo "[~] Adding NIC"
    # generate nic with different ids
    generate_nic $vmid $i

done



# %%%%%%%%%%%%%%%% add new .vmdk %%%%%%%%%%%%%%%%
# remove dummy disk
echo "[~] generating .vmdk"
rm "$datastorepath$vmname"/*.vmdk
# key list from vms, grep key of virtualdisk and 5 lines after, parse number
diskid=$(vim-cmd vmsvc/device.getdevice $vmid | grep "VirtualLsiLogicController" -A 15 | grep busNumber | cut -d "=" -f 2- | sed 's/,//')
unitNumber=$(vim-cmd vmsvc/device.getdevice $vmid | grep $vmname".vmdk" -A 25 | grep unitNumber | cut -d "=" -f 2- | sed 's/,//')
vim-cmd vmsvc/device.diskremove $vmid $diskid $unitNumber $datastorepath$vmname"/"$vmname".vmdk"

# create vmdk
cd $pathtovmx
vmkfstools --createvirtualdisk $vmsize --diskformat thin $datastorepath$vmname"/"$vmname".vmdk"
# add disk to vm 
vim-cmd vmsvc/device.diskaddexisting $vmid $datastorepath$vmname"/"$vmname".vmdk" $diskid $unitNumber


# %%%%%%%%%%%%%%%% edit details for .vmx %%%%%%%%%%%%%%%%
# add machine type to .vmx and change guest OS
echo "typeos = \"$vmtype\"" >> $datastorepath$vmname"/"$vmname".vmx"
sed -i "s/guestOS = \"other\".*/guestOS = \"$vmtype\"/" $datastorepath$vmname"/"$vmname".vmx"

# allow nested vms (to run in a virtualized environment)
echo "vmx.allownested = \"true\"" >> $datastorepath$vmname"/"$vmname".vmx"


# Give unique macs to each card 
# (vim-cmd command deletes other config so it has to be done afterwards)
for i in $(seq 1 $netcards); do
    echo "[~] Generating unique MAC - "$i
    # give unique MAC using .vmx
    # https://pubs.vmware.com/workstation-9/index.jsp?topic=%2Fcom.vmware.ws.using.doc%2FGUID-5C55C285-79B0-404F-95A5-87F64C41E3DC.html 
    randomMAC=$(generate_mac)
    usedMACS=" $(cat $datastorepath$vmname'/'$vmname'.vmx'| egrep 'ethernet[0-9]+\.address'|xargs) "
    echo "$usedMACS" |grep -q " $randomMAC " 
    while [ $? -eq 0 ]; do 
        randomMAC=$(generate_mac)
        echo "$usedMACS" |grep -q " $randomMAC " 
    done

    echo "ethernet$i.address = \"$randomMAC\"" >> $datastorepath$vmname"/"$vmname".vmx"
done

# %%%%%%%%%%%%%% list and power up %%%%%%%%%%%%%%%
# list all vms - new vm should be there
echo "[~] list of all vms:"
vim-cmd vmsvc/getallvms


# power on machine
vim-cmd vmsvc/power.on $vmid

echo "[!] - All done my friend! Your VM should be up and running!"


