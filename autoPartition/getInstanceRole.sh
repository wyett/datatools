#!/bin/bash

# upper to lower
toLower(){
  tr '[A-Z]' '[a-z]'
}

# lower to upper 
toUpper(){
  tr '[a-z]' '[A-Z]'
}

# connect mysql
connMySQL(){
  declare _sql=$1
  mysql -e "$_sql;" | sed -n '2,$'p 
}

# get mysql variable
getMySQLVariable(){
  declare _v=$1
  connMySQL "show variables like '$_v'" | awk '{print $2}' | toLower
}

# get mysql status
getMySQLState(){
  declare _s=$1
  connMySQL "show status like '$_s'" | awk '{print $2}' | toLower
}

# get mysql version
getMySQLVersion() {
  connMySQL "show variables like 'version_comment" | awk '{print $2}'
}

# get 
#getMasterSlaveType(){
#  declare _r=$1
#  case $_r in
#    "wsrep") getWsrepVariable "wsrep_on";;
#    "replicate") getReplicateRole ;;
#    *) exit 0;;
#  esac
#}

getWsrepRole(){
  declare _w=$(getMySQLVariable "wsrep_on"  )
  if [ -n $_w ] && [[ $_w == 'on' ]]; then
    echo 'true'
  fi

  if [[ $_w == 'off' ]] || [[ -z $_w ]]; then
    echo 'false'
  fi

}


getReplicateState(){
  declare _res=$(connMySQL "show slave status\G;" \
                 | grep 'Slave\_[[:alpha:]]*\_Running' | toLower)
  if [[ -z "$_res" ]]; then
    echo 'none' && exit 0
  fi 

  if [ $(echo $_res|awk '{print $2}') == 'no' ] \
       && [ $(echo $_res|awk '{print $4}') == 'no' ] ;then
    echo 'false'
  fi

  if [ $(echo $_res|awk '{print $2}') == 'yes' ] \
       || [ $(echo $_res|awk '{print $4}') == 'yes' ] ;then
    echo 'true'
  fi
}

getReplicateRole() {
  declare _res=$(getReplicateState)
  declare _slavecount=$(mysql -e " show processlist;" \
                        | sed -n '/Binlog Dump/p' | wc -l)
  declare _rw=$(getMySQLVariable 'read_only') 
  if [ "$_res" == 'none' ] && [ $_slavecount -eq 0 ];then
    echo 'none'
  fi

  if [ "$_res" == 'false' ] && [ $_slavecount -gt 0 ] \
       && [ "$_rw" == 'off' ]; then
    echo "master"
  fi

  if [ "$_res" == 'true' ] && [ "$_rw" == on ]; then
    echo "slave"
  fi
}

main(){
  declare _r=$(getReplicateRole)
  declare _w=$(getWsrepRole)

  #echo $_r $_w

  if [ "$_w" == 'true' ];then
    echo 'master'
  fi

  if [ "$_r" == 'none' ] && [ "$_w" == 'false' ]; then
    echo 'single'
  fi

  if [ "$_r" == 'master' ] && [ "$_w" == 'true' ]; then
    echo 'master'
  fi

  if [ "$_r" == 'master' ] && [ "$_w" == 'false' ]; then
    echo 'master'
  fi

  if [ "$_r" == 'slave' ]; then
    echo 'slave'
  fi
}

main














