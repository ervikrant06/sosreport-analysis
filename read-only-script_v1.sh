#!/bin/bash
###  Combining all functions here
###  Info need to be printed
###  1) Version Information 2) List of filesystems in RO mode 3) Checking the underlying devices of a filesystem.
#set -x

###  Usage Part : Need to give the name of directory on which the script is supposed to be run that name will go into the variable sos

if [ $# -ne 1 ]; then
echo "Usage : $0 <extracted sosreport>"
exit 1
else
sos=$1
fi

###  Die function 

function die() {
printf "\n exiting the script \n"
exit 1
}

###  Printing the version Information.

function versioninfo() {
version1=$(awk -F# '{print $1}' $sos/uname)
version2=$(cat $sos/etc/redhat-release)
version3=$(grep -w e2fsprogs $sos/installed-rpms | grep -v lib | awk '{print $1}')
printf "\n--> Version Information\n"
echo "~~~"
echo "$version1 $version2 $version3"
echo "~~~"
}

###   Checking file locations in sosreport and initializing the variables accordingly.
###   In sosreports starting from RHEL 6.7 paths have been changed.

function locatingfiles() {
version4=$(echo "$version2" | awk '{print $(NF-1)}')
if [[  $(echo "$version4 <= 6.6" | bc) -eq 1 ]]
 then
   if [ -f $sos/sos_commands/devicemapper/lvs_-a_* ]
    then
    lvsfile=$(ls $sos/sos_commands/devicemapper/lvs_-a_*)
   else
   echo "lvs_-a_-o_devices file not found in sosreport"
   fi
   if [ -f $sos/sos_commands/devicemapper/dmsetup_info* ]
    then
    dmsetupfile=$(ls $sos/sos_commands/devicemapper/dmsetup_info*)
   else
   echo "dmsetinfo file is not present in sosreport"
   fi
   if [ -f $sos/var/log/messages ]
    then
    messagefile=$(ls $sos/var/log/messages)
   else
   echo "Message file is not present in sosreport"
   fi
   if [ -f $sos/proc/mounts ]
    then
    procfile=$(ls $sos/proc/mounts)
   else
   echo "/proc/mounts file is not present in sosreport"
   die
   fi
   if [ -f $sos/sos_commands/devicemapper/multipath_-v4* ]
    then
    multipathfile=$(ls $sos/sos_commands/devicemapper/multipath_-v4*)
   else
   echo "multipath output file is not present in sosreport or it may be configured on server"
   fi
elif [[ $(echo "$version4 > 6.6" | bc) -eq 1 ]]
 then
   if [ -f $sos/sos_commands/lvm2/lvs_-a_* ]
    then
    lvsfile=$(ls $sos/sos_commands/lvm2/lvs_-a_*)
   else
   echo "lvs_-a_-o_devices file not found in sosreport"
   fi
   if [ -f $sos/sos_commands/devicemapper/dmsetup_info* ]
   then
   dmsetupfile=$(ls $sos/sos_commands/devicemapper/dmsetup_info*)
   else
   echo "dmsetinfo file is not present in sosreport"
   fi
   if [ -f $sos/var/log/messages ]
    then
    messagefile=$(ls $sos/var/log/messages)
   else
   echo "Message file is not present in sosreport"
   fi
   if [ -f $sos/proc/mounts ]
    then
    procfile=$(ls $sos/proc/mounts)
   else
   echo "/proc/mounts file is not present in sosreport"
   die
   fi
   if [ -f $sos/sos_commands/multipath/multipath_-v4* ]
    then
    multipathfile=$(ls $sos/sos_commands/multipath/multipath_-v4*)
   else
   echo "multipath output file is not present in sosreport or it may be configured on server"
   fi
fi
}


###  Function called to print the messages corresponding to underlying disk if the filesystem is created direcly on disk.
###  This function is used at many points to print the messages from log file.

function messageprint1 {
messagelinecount1=`echo $(grep "$1" $messagefile | wc -l)`
printf "\n     ============Start of messages for $1 ============== \n"
  if [ `echo $messagelinecount1` -eq 0 ]
  then
  echo "No message reported in current log file"
  elif [ `echo $messagelinecount1` -gt 15 ]
  then
        let g++
        echo "$(grep $1 $messagefile | tail )"
  else
        echo "$(grep $1 $messagefile)"
  fi
printf "      ============End of messages for $1 ============== \n\n"
if [[ "$g" -ge 1 ]] ; then
printf "      ============Number of messages reported for $1 only 15 messages are displayed here for the sake of brevity\n"
fi
}

###   Printing the paths of a multipath device.
###   Calling the messageprint1 function for each path of the device.

function multipaths {
m=0
printf "\n     -> Checking the multipath_v4 output for the health of devices used to create RO filesystem \n"
echo "~~~"
if [[ $1 == dm-?* ]]; then
search=") $1"
else
search="$1"
fi
echo "$(grep -A 12 "$search" "$multipathfile")" | while read "l" ; do
let m++
  if [[ $m -eq 1 || $m -eq 2 || $m -eq 3 ]]
  then
  echo "     $l"
  elif [ $m -ge 4 ]
   then
   if [[ "$(echo "$l" | cut -c1)" == [A-Za-z0-9] ]]
   then
   #die 2>/dev/null
   exit 34
   else
   echo "     $l"
   messageprint1 "$(echo "$l" | awk '{print $3}')"
   fi
  fi
done
echo "~~~"
}

###  Function to grep only read-only messages in sosreport.

function readonlyprint() {
printf "\n--> Checking recent message file for read-only messages.\n"
readonly=$(cat $messagefile | awk '/read-only/ && /(dm-?? || sd?? )/ {print $0;}')
#readonly=$(grep "read-only" $messagefile)
if [ "$readonly" != " " ]
then
printf "  Found below message in log file with  read-only keyword  \n"
echo "~~~"
echo "$readonly"
echo "~~~"
else
printf "  Didn't find any filesystems message about RO mode in recent log file i.e var/log/messages \n"
fi
}


###   Printing the read-only filesystems present on server.

function readonly1() {
printf "\n--> Checking the read-only filesystems mounted on server.\n"
count1=$(grep ^/ $procfile | grep -w ro)
if [ "$count1" != "" ]
then
printf "\n  Found below list of filesystems in RO mode. \n\n"
echo "~~~"
echo "$count1"
echo "~~~"
else
printf "\n  Didn't find any filesystems in RO mode may be the sosreport is captured after the reboot. \n \n"
readonlyprint
die
fi
}


function devicemappercall {
value1=`echo "dm-$(grep -w "$1" $dmsetupfile |awk '{print $3}')"`
printf "\n  -> $value1 number of $1 RO filesystem.\n"
messageprint1 $value1
}

### Function called by Underlyingdevices to determine the nature of underlyingtype devices.

function underlyingtype() {
let u++
 echo "$1" | while IFS="/" read var1 var2 var3 var4  
 do
# Matching condition like /dev/mapper/mpath. Calling function to find the multipaths for the device.
 if [ "$var4" != "" ]
 then
 printf "\n      $u) multipath device /$var2/$var3/$var4 used by $third-$fourth \n"
 messageprint1 `echo $var4 | awk -F"(" '{print $1}'`
 multipaths `echo $var4 | awk -F"(" '{print $1}'`
# Matching for devices like sd which can be called as a direct disks. Calling function to print the messages for these disks.
 elif [[ "$var4" == "" && "$var3" == sd??* ]]
 then
 printf "\n      $u) disk used by $third-$fourth is $var3 \n"
 printf "\n   -> Checking for messages corresponding to disk "$var3" in recent message file i.e /var/log/messages \n"
 messageprint1 `echo $var3 | awk -F"(" '{print $1}'`
# Matching the cases like /dev/dm-? in which the filesystem is created on top of multipath dm device.
# Calling function multipaths to determine the paths.
 elif [[ "$var4" == "" && "$var3" == dm-??* ]]
 then
 printf "\n      $u) multipath device $var3 used by $fourth \n"
 printf "\n   -> Checking for messages corresponding to disk "$var3" in recent message file i.e /var/log/messages \n"
 messageprint1 `echo $var3 | awk -F"(" '{print $1}'`
 multipaths `echo $var3 | awk -F"(" '{print $1}'`
# Matching the cases like /dev/emcpower in which the EMC multipathing is used.
 elif [[ "$var4" == "" && "$var3" == emcpower* ]]
 then
 printf "\n      $u) EMC multipath /$var2/$var3 device used by $third-$fourth \n"
 fi
 done
#done
}
###  Function called by "Determining the type of underlying device used to create the filesystems".

function underlyingdevices() {
# Converting the input from VG-LV format to LV VG format so that match can be found in output lvs-a-o+devices
for i in "$(echo "$1" | sed 's/-/ /' | awk '{print $2 ,$1}')"; do
 for j in "$(awk '{$1=$1; print}' $lvsfile | grep "$i" | egrep -v "^(#|$)")"; do
 if [ "$j" == "" ]
 then
 exit 23
 else
 printf "\n   -> Finding the underlying disk of $third-$fourth filesystem \n\n"
 for p in `echo "$j" | awk '{print $NF}'` ; do
 let z++
 array1+=($p)
 done
 fi
 done
done
  if [ "$z" -gt 1 ]
   then
   printf "\n     -> $z disks are used for creating filesystem \n\n"
    for y in `printf '%s \n' "${array1[@]}"`; do
    underlyingtype "$y"
    echo "$y"
    done
     else
    printf "\n     -> Filesystem created on a single disk "${array1[@]}" \n\n"
    underlyingtype "${array1[@]}"
  fi
}

###  Main function calling underlyingdevices and underlyingtype

function main {
printf "\n--> Checking the underlying device and possible device-mappers of every read-only filesystem \n"
for i in $(grep ^/ "$procfile" | grep -w ro | awk '{print $1}') ; do
# Putting the value of device mapper in different variables to determine the nature of device-mapper
echo "$i" | while IFS="/" read first second third fourth
do
# First condition to match the device mappers like /dev/mapper/vgsas-lvsas1
if [[ "$third" == "mapper" && "$fourth" == *[\-]* ]]
 then
 # Calling mapper function using vgsas-lvsas1"
 devicemappercall "$fourth"
 underlyingdevices "$fourth"
# Second condition to match the device mappers like /dev/mapper/diaglog
 elif [[ "$third" == "mapper" && "$fourth" != *[\-]* ]]
 then
 echo "Found a multipath device on which filesystem directly created"
 multipaths "$fourth"
# Third condition to match the device mappers like /dev/dm-9
 # Calling messageprint1 and multipath check
 elif [[ "$third" == dm-* && "$fourth" == "" ]]
 then
 printf "\n  ## $i is created on multipath dm device \n"
 printf "\n   -> Checking for messages corresponding to disk "$third" in recent message file i.e /var/log/messages \n"
 messageprint1 $third
 multipaths "$third"
 # In this case directly grep for the device mapper in multipath configuration file.
 # grep $third $sos/sos_commands/devicemapper/multipath_-v4_-ll
# Fourth condition to match the device mappers like /dev/vgp00/lvopt
 elif [[ "$third" != "mapper" && "$fourth" != "" ]]
 then
 printf "\n  ## $i is created on VG-LV setup \n"
 # echo "call function using $third-$fourth"
 # Calling the function using vgp00-lvopt
 underlyingdevices "$third-$fourth"
 devicemappercall "$third-$fourth"
# Otherwise it's created directly on top of the disk.
 elif [ "$fourth" == "" ]
 then
 printf "\n  ## $i is created directly physical disk \n"
 printf "\n   -> Checking for messages corresponding to disk "$third" in recent message file i.e /var/log/messages \n"
 messageprint1 "$third"
 elif [ "$third" == emcpower* && "$fourth" == "" ]
 then
 printf "\n  ## $i is created directly on EMC multipath device \n"
 else
 echo "NONE OF THE ABOVE CONDITION MATCH. PLEASE VERIFY MANUALLY"
 die
fi
done
done
}

###   Calling various functions

versioninfo
locatingfiles
readonly1
main
