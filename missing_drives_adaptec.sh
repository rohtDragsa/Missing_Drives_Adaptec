#!/bin/bash
#Created:radpawel
#Modified:2.3
#color
RED='\033[0;31m'
NC='\033[0m' # No Color
arrConf="/opt/Adaptec/bin/arcconf getconfig "
lsPSI="/sbin/lspci"
#get nbr of ctrls
nbrAdap=$($lsPSI | grep -i 'Adaptec' | wc -l)
#get DB type
dbType=`grep -i server_type_id /etc/hardware.amazon.stanza | cut -d = -f 2 | sed 's/ *//g'`
new_array=()

if [[ `ps aux | grep -v grep | grep pmon` ]]; then
  #statements
    printf '\e[33m%-79s\e[m\n' "##############################################################################";
    printf '\e[33m%-79s\e[m\n' "#                         CAUTION  DB instance running                        #";
    printf '\e[33m%-79s\e[m\n' "##############################################################################";

    echo -n "Continue? (y/n) ";
    read -e answer </dev/tty;
    if [[ ! $answer =~ ^[Yy]$ ]]; then
  	   exit 0;
    fi
 fi


 if [[ -n `$lsPSI | grep "Adaptec Series 6"` ||  -n `$lsPSI | grep -i "Adaptec "` ]]; then
   case $dbType in
       DBLARGE12) expectedhdd=116;;
       DBMID12)   expectedhdd=68;;
       DBSMALL12) expectedhdd=43;;
       *) echo "Expected host type is not found";exit 1;;
   esac
fi

for i in $(seq $nbrAdap )
   do # x value adjusted for stanza added to the string later
       x=$(($i-1))
       repNum=`$arrConf $i PD | egrep -c "(Online|Spare|Ready)"`
       repFail=`$arrConf $i PD | egrep -c -i "(Failed)"`
       totalFail=$((totalFail+$repFail))
       printf "\n%s%d%s%d%s\n" "Controller:" "$i" " reports " "$repNum" " drives"
       total=$((total+$repNum))
       arrconfHdd=($($arrConf $i PD | egrep -A5 '(Device is a Hard drive)' | grep -i "Reported Channel,Device(T:L)" | cut -d : -f3 | cut -d \( -f2 | sort -n))
       stanzaHdd=($(grep -i hardware_storage_physical_$x /etc/hardware.amazon.stanza | cut -d : -f 3 | sort -n))

       [ ${#arrconfHdd[*]} != ${#stanzaHdd[*]} ] && { printf "%s" "Missing drive"; }

        for (( j = 0; j < ${#stanzaHdd[*]}; j++  ))
            do
                if [[ "${stanzaHdd[$j]}" != "${arrconfHdd[$j]}" ]];then

                    printf "$RED\n%s$NC\n" "Missing drive >>> 0:${stanzaHdd[$j]}"
                    #Create array excluding missing elements
                    for value in "${stanzaHdd[@]}"
                        do
                            [[  $value != ${stanzaHdd[$j]} ]] && new_array+=($value)
                        done
                        stanzaHdd=("${new_array[@]}")
                        unset new_array
                fi
            done
             printf "$RED%s$NC\n" "Num of failed drives:$repFail"
    done
echo -e "\nNumber of expected drives for $dbType $expectedhdd"
echo -e "Number of detected drives for $dbType $total\n"

if [[ $total -ne $expectedhdd  &&  -n $totalFail ]];then
   printf "$RED%s\n$NC\n" "Total num of faild drives: $totalFail"

fi
