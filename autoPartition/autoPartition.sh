#!/bin/bash
# by wyettLei

##
## variables define
##
VERSION=1.0.0

# args list
ARG_0=$0
ARG_N="$@"

# path and file
PROGNAME0="autoPartition"
PROGNAME="${PROGNAME0}.sh"
DIRNAME=$(dirname $0)
VERSION=1.0.0
CURRENT_DATE=$(date '+%Y%m%d')

# LOG
declare -ri MIN_DISK_FREE_SPACE_KB=$((20*1024))
declare -ri MAX_RETETION_DAYS_FOR_LOG=30
LOGDIR="/var/log/"
LOG=$LOGDIR/${PROGNAME0}.log

# TMPFILE
TMPFILE=$DIRNAME/${PROGNAME0}.${CURRENT_DATE}.tmp


# DbName : database name
# PCount : save partition count
DbName=""
PCount=""

##
## Functions
##

# log model
wlog(){
  declare _f=$1
  declare _log=$2
  declare _t=$(date +%F' '%T)
  case "$_f" in
    info) _tmpflag='[INFO]' ;;
    err) _tmpflag='[ERROR]' ;;
    warn) _tmpflag='[WARNING]' ;;
  esac
  echo "$_t $_tmpflag $_log" >>$LOG 2>>$LOG
}


# read args
read_param() {
  declare _arg=""
  #[[ -z $_arg ]] && usage && exit 0
  for _arg; do
    case "$_arg" in
      --dbname=*) DbName=${_arg#--dbname=} ;;
      --saveCount=*) PCount=${_arg#--saveCount=} ;;
      --help|-h) usage; exit 0 ;;
    esac
  done
  return 0
}

# usage
usage(){
  cat <<EOF
Usage: $PROGNAME --dbname={database name} --saveCount={save count}
EOF
}

# get mysql instance role
getDBRole(){
  $DIRNAME/getInstanceRole.sh
}

# connect mysql
connMysql(){
  declare _sql=$1
  mysql -e "use $DbName;$_sql;" | sed -n '2,$'p
}

# upper to lower
toLower(){
  declare _s=$1
  echo $_s| tr '[A-Z]' '[a-z]'
}

# lower to upper 
toUpper(){
  declare _s=$1
  echo $_s| tr '[a-z]' '[A-Z]'
}

# get next partition name
#getNextPartitionName(){
#  wlog 'info' 'get next partition name...'
#  declare _f=$1
#  declare _i=$2
#  if [ $(toLower $_f) == "day" && $_i -eq 1 ];then
#    echo 'p'$(date -d tomorrow +%Y%m%d)
#  elif [ $(toLower $_f) == "day" && $_i -eq 7 ];then
#    echo 'p'$(date -d +7day +%Y%m%d)
#  elif [ $(toLower $_f) == "week" && $_i -eq 1 ];then
#    echo 'p'$(date -d +7day +%Y%m%d)
#  elif [ $(toLower $_f) == "month" && $_i -eq 1];then
#    echo 'p'$(date -d +1month +%Y%m)
#  else
#    echo "not support" && echo 1
#  fi 
#}

# minus two number
substract(){
  wlog 'info' 'substract,,,'
  declare _s=$1
  num1=$(echo $_s | cut -d' ' -f1 )
  num2=$(echo $_s | cut -d' ' -f2 )
  if [ $num1 -gt $num2 ];then
    echo `expr $num1 - $num2`
  else
    echo `expr $num2 - $num1`
  fi
}

# read from template file
readTmp(){
  declare _tb=$1
  declare _m=$2
  wlog 'info' "readTmp $_tb $_m..."
  case "$_m" in
    "table") awk '{print $2}' | sort | uniq ;;
    "lastname") sed -n "/$_tb/p" $TMPFILE | tail -1 | awk '{print $3}' ;;  
    "lboname") sed -n "/$_tb/p" $TMPFILE | tail -2 | head -1 | awk '{print $3}' ;;  
    "interval") sed -n "/$_tb/p" $TMPFILE | tail -3 | head -2 | awk '{print $6}' ;;  
    "method") sed -n "/$_tb/p" $TMPFILE | tail -1 | awk '{print $4}' ;;  
    "func") sed -n "/$_tb/p" $TMPFILE | tail -1 | awk '{print $5}' ;;  
    #"desc") sed -n "/$_tb/p" $TMPFILE | tail -1 | awk '{print $6}' ;;  
    "namelist") sed -n "/$_tb/p" $TMPFILE | awk '{print $3}' ;;  
    #"namelist") sed -n "/$_tb/p" $TMPFILE | awk '{print $3}' ;;  
    *) echo "not surport value" && exit 1 ;;
  esac
}

sec2Day(){
  declare -i _s=$1
  echo $(($_s/24/60/60))
}

getNextTime(){
  declare _f=$1
  declare _i=$2
  wlog 'info' "get next time, $_f $_i..."
  if [ $(toLower $_f) == "to_days" ] && [ $_i -eq 1 ];then
    echo $(date -d tomorrow +%Y-%m-%d)
  elif [ $(toLower $_f) == "to_days" ] && [ $_i -eq 7 ];then
    echo $(date -d +7day +%Y-%m-%d)
  elif [ $(toLower $_f) == "to_days" ] && [ $_i -gt 27 ];then
    echo $(date -d +1month +%Y-%m)'-01'
  elif [ $(toLower $_f) == "yearweek" ] && [ $_i -eq 1 ];then
    echo $(date -d +7day +%Y-%m-%d)
  elif [ $(toLower $_f) == "none" ] && [ $(sec2Day $_i) -eq 1 ];then
    echo $(date -d tommorrow +%Y-%m-%d)
  elif [ $(toLower $_f) == "none" ] && [ $(sec2Day $_i) -eq 7 ];then
    echo $(date -d +7day +%Y-%m-%d)
  elif [ $(toLower $_f) == "none" ] && [ $(sec2Day $_i) -gt 27 ];then
    echo $(date -d 1month +%Y-%m)'-01'
    #echo $(date -d "$nextmonth" +%s)
  else
    echo "not support" && exit 1
  fi 
}

# get next partition name
getNextPartitionName(){
  declare _f=$1
  declare _i=$2
  declare _flower=$(toLower "$_f")
  declare _res=""
  _s=$(getNextTime "$_f" "$_i")
  if [ "$?" -eq 0 ] && [ -n "$_s" ];then
    if [ "$_flower" == "yearweek" ];then
      _res='p'$(date -d "$_s" +%G%g)
    elif [ "$_flower" == "to_days" ];then
      _res='p'$(date -d "$_s" +%Y%m%d)
    elif [ "$_flower" == "none" ];then
      _res='p'$(date -d "$_s" +%Y%m%d)
    fi
  fi
  echo "$_res"
}

# get expression
getExpression(){
  declare _f=$1
  declare _i=$2
  declare _flower=$(toLower "$_f")
  declare _res=""
  _s=$(getNextTime "$_f" "$_i")
  if [ "$?" -eq 0 ] && [ -n "$_s" ];then
    if [ "$_flower" == "to_days" ]; then
      _res=$_flower'('\'$_s\'')'
    elif [ "$_flower" == "yearweek" ]; then
      _res=$_flower'('\'$_s\'')'
    elif [ "$_flower" == "none" ]; then
      _res='('$(date -d "$_s" +%s)')'
    fi
  fi
  echo "$_res"
}

# get interval value between contiguous partition
getInterval(){
  declare _tb=$1
  substract "$(readTmp $_tb 'interval')"
}

# check if str1 contants str2
findInStr(){
  declare _s1=$1
  declare _s2=$2
  if [ -n $(echo $_s1 | grep -b -o "$_s2") ];then
    echo 'true'
  else
    echo 'false'
  fi
}

# get partition function
getFunc(){
  declare _tb=$1
  exp=$(readTmp $_tb 'func')
  if [ $(findInStr $exp '(') == "true" ];then
    echo $exp | cut -d'(' -f1
  else
    return 'None'
  fi
}

# get partition info of database $DbName
getPartitionInfo(){
  connMysql "select TABLE_SCHEMA, \
                    TABLE_NAME, \
                    PARTITION_NAME, \
                    PARTITION_METHOD, \
                    PARTITION_EXPRESSION, \
                    PARTITION_DESCRIPTION, \
                    PARTITION_ORDINAL_POSITION \
             from information_schema.partitions \
             where table_schema='$DbName' \
                and partition_name is not null;" > $TMPFILE
}

# check if the string is number, and return it
isNumber(){
  declare _n=$1
  echo $_n | sed -n '/^[0-9]*$/p'
}

# get length of string
strLen(){
  declare _n=$1
  echo $_n | awk '{print length($0)'
}

# convert datetime to seconds
toSeconds(){
  declare _n=$1
  if [ -n $(isNumber "$_n") && $(strLen "$_n") -eq 6 ]; then
    _n="$_n"'01'
  elif [ -n $(isNumber "$_n") && $(strLen "$_n") -eq 4 ]; then
    _n="$_n"'0101'
  fi 
  echo $(date -d "$_n" +%s)
}

# check if new partition name is fit
isExistPartition(){
  declare _tb=$1
  declare _nextpn=$2
  declare _interval=$(getInterval $_tb)
  declare _lbonum=$(readTmp $_tb 'lboname' | awk -F'p' '{print $2}')
  declare _fname=$(getFunc $_tb)
  
  wlog 'info' "check if $_nextpn has been created in $_tb..."

  _n=$(echo $_nextpn | awk -F'p' '{print $2}')
  if [ "$_lbonum" -lt "$_n" ]; then
    wlog 'info' "$_tb:$_nextpn is not existed"
    echo 0
  else 
    wlog 'info' "$_tb:$_nextpn is existed"
    echo 1
  fi
}

# add new partition
addPartition(){
  declare _tb=$1
  declare _fname=$(getFunc $_tb)
  declare _interval=$(getInterval $_tb)
  declare _nextpn=$(getNextPartitionName "$_fname" "$_interval")
  declare _fexpression=$(getExpression "$_fname" "$_interval")
  declare _engine=$(getEngine "$_tb")
  declare _lpn=$(readTmp "$_tb" 'lastname')

  wlog 'info' "add partition $_nextpn in $_tb..."

  if [ $(isExistPartition "$_tb" "$_nextpn") -eq 0 ];then
    if [ "$_lpn" == "pother" ];then
      reorganizePartition "$_tb" "$_nextpn" "$_fexpression" "$_engine"
    else
      addNewPartition "$_tb" "$_nextpn" "$_fexpression" "$_engine"
    fi
  fi
}

#reorganize partition
reorganizePartition(){
  declare _tb=$1
  declare _pn=$2
  declare _fu=$3
  declare _e=$4

  wlog 'info' "reorganize partition ..."

  connMysql "alter table $_tb reorganize partition pother into \
             (partition $_pn values less than ($_fu) engine=$_e, \
              partition pother values less than MAXVALUE engine=$_e);"
}

# get engine
getEngine(){
  declare _tb=$1

  wlog 'info' "get engine of table $_tb..."

  connMysql "select engine from information_schema.tables \
             where TABLE_SCHEMA='$DbName' 
               and TABLE_NAME='$_tb' 
             limit 1;"
}

# add new Partition
addNewPartition(){
  declare _tb=$1
  declare _pn=$2
  declare _fu=$3
  declare _e=$4

  wlog 'info' "add partition $_pn directly into $_tb..."

  connMysql "alter table $_tb add \
             (partition $_pn values less than ($_fu) engine=$_e;"
}

# get old partition list
getOldList(){
  declare _tb=$1
  declare _pc=$(readTmp $_tb 'namelist')
  declare _lpn=$(readTmp "$_tb" 'lastname')

  wlog 'info' "get expired partition list of $_tb..."

  _c=$(echo $_pc|tr ' ' '\n' |wc -l)
  if [ "$_lpn" == 'pother' ]; then
    if [ "$_c" -gt $(( $PCount + 1)) ];then
      _tmp=$(( $_c - $PCount -1 ))
      echo $_pc | tr ' ' '\n' | sed -n "1,$_tmp"p
    fi
  else 
    if [ "$_c" -gt $PCount ];then
      _tmp=$(( $_c - $PCount ))
      echo $_pc | tr ' ' '\n' | sed -n "1,$_tmp"p
    fi
  fi
}

# drop old partition
dropOldestPartition(){
  declare _tb=$1
  declare _pn=$2

  wlog 'info' "drop partition $_tb:$_pn ..."

  connMysql "alter table $_tb drop partition $_pn;"
}




main(){
  wlog 'info' 'function main()...'
  read_param "$@"

  # add partition
  wlog 'info' 'get partition info before add partition...'
  getPartitionInfo

  for tbname in $(awk '{print $2}' $TMPFILE|sort | uniq)
  do
    if [ $(getDBRole) == 'DbRole=MS' ];then
      addPartition "$tbname"
    fi
  done

  # drop partition
  wlog 'info' 'get partition info before drop partition...'
  getPartitionInfo
  
  for tbname in $(awk '{print $2}' $TMPFILE|sort | uniq)
  do
    pl=$(getOldList $tbname)
    for pname in $(echo $pl)
    do
      if [ $(getDBRole) == 'DbRole=MS' ];then
        dropOldestPartition $tbname $pname
        #wlog 'info' "$tbname $pname"
      fi
    done
  done
}

main "$@"






















