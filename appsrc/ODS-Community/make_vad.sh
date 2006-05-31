#!/bin/sh
LOGDIR=`pwd`
VERSION="0.0.996"
LOGFILE="${LOGDIR}/make_vad.log"
STICKER="${LOGDIR}/make_vad.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" != "x" ]
then
  TEMPFILE="`cygpath -m $TMP/isql.$$`"
  STICKER="`cygpath -m $STICKER`"
  if [ "x$SRC" != "x" ]
  then
    HOME=$SRC
  else
    HOME="`cygpath -m $HOME`"
  fi
  LN="cp -rf"
  RM="rm -rf"
else
  TEMPFILE=/tmp/isql.$$
  LN="ln -fs"
  RM="rm -f"
fi
VOS=0
if [ -f ../../autogen.sh ]
then
    VOS=1
fi

if [ "z$SERVER" = "z" ]  
then
    if [ "x$HOST_OS" != "x" ]
    then
	SERVER=virtuoso-odbc-t.exe
    else
	SERVER=virtuoso
    fi
fi

rm -rf vad

. $HOME/binsrc/tests/suite/test_fn.sh

if [ -f /usr/xpg4/bin/rm ]
then
  myrm=/usr/xpg4/bin/rm
else
  myrm=$RM
fi

VERSION_INIT() 
{
  rm -f version.tmp
  for i in `find . -name 'Entries' | grep -v "vad/"`; do
        cat $i | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
  done
  VERSION=`cat version.tmp | awk ' BEGIN { cnt=9 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
  rm -f version.tmp
}

virtuoso_start() {
  echo "Starting $SERVER"
  ddate=`date`
  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
  timeout=600
  $myrm -f *.lck
  if [ "z$HOST_OS" != "z" ] 
  then
      "$SERVER" +foreground &
  else
      "$SERVER" +wait
  fi
  stat="true"
  while true
  do
    sleep 4
    echo "Waiting $SERVER start on port $PORT..."
    stat=`netstat -an | grep "[\.\:]$PORT " | grep LISTEN`
    if [ "z$stat" != "z" ]
		then
      sleep 7
      LOG "PASSED: $SERVER successfully started on port $PORT"
      return 0
    fi
    nowh=`date | cut -f 2 -d :`
    nows=`date | cut -f 3 -d : | cut -f 1 -d " "`
    nowh=`expr $nowh - $starth`
    nows=`expr $nows - $starts`
    nows=`expr $nows + $nowh \*  60`
    if test $nows -ge $timeout
    then
      LOG "***FAILED: Could not start $SERVER within $timeout seconds"
      exit 1
    fi
  done
}

do_command_safe () {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE
  if [ "x$HOST_OS" != "x"  -a "z$BUILD" != "z" ]
	then
	  $BUILD/../bin/isql.exe $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* > "${LOGFILE}.tmp"
	else
	  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* > "${LOGFILE}.tmp"
	fi
  if test $? -ne 0
  then
    LOG "***FAILED: starting $command"
  else
    if egrep -e '^\*\*\*' "${LOGFILE}.tmp" > /dev/null
    then
      LOG "***FAILED: execution of $command"
      msg=`cat ${LOGFILE}.tmp`
      echo "------------ SQL ERROR -------------"
      echo "$msg"
      echo "------------------------------------"
      echo "------------ SQL ERROR -------------"	>> $LOGFILE
      echo "$msg"	>> $LOGFILE
      echo "------------------------------------"	>> $LOGFILE
    else
      LOG "PASSED: $command"
    fi
  fi
  rm "${LOGFILE}.tmp" 2>/dev/null
}

do_command() {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

directory_clean() {
  $myrm -rf vad 2>/dev/null
  $myrm -rf vad.* 2>/dev/null
  $myrm make_vad.log 2>/dev/null
  $myrm make_vad.xml 2>/dev/null
  $myrm *.db 2>/dev/null
  $myrm *.trx 2>/dev/null
  $myrm *.tdb 2>/dev/null
  $myrm *.pxa 2>/dev/null
  $myrm *.log 2>/dev/null
  $myrm *.ini 2>/dev/null
}

directory_init() {
  mkdir vad
  mkdir vad/data
  mkdir vad/data/community

  for dir in `find sql www-root -type d -print | LC_ALL=C sort | grep -v CVS`
  do
    mkdir vad/data/community/$dir
  done

  for file in `find sql www-root -type f -print | LC_ALL=C sort | grep -v CVS`
  do
    cp $file vad/data/community/$file
  done
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  do_command_safe $DSN "shutdown" 2>/dev/null
  sleep 5
}

sticker_init() {
  LOG "VAD Community sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"Community\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"Community Application\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 2003 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\" />" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies>" >> $STICKER
  echo "  <require>" >> $STICKER
  echo "   <name package=\"Framework\">" >> $STICKER
  echo "   </name>" >> $STICKER
  echo "   <versions_later package=\"1.02.65\">" >> $STICKER
  echo "    <prop name=\"Date\" value=\"2005-04-28\" />" >> $STICKER
  echo "    <prop name=\"Comment\"" >> $STICKER
  echo "	  value=\"An incompatible version of WA\" />" >> $STICKER
  echo "   </versions_later>" >> $STICKER
  echo "  </require>" >> $STICKER
  echo "</dependencies>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\">log_enable(1);</sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\">" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      registry_set('_community_path_', '/DAV/VAD/community/');" >> $STICKER
  echo "      registry_set('_community_version_', '$VERSION');" >> $STICKER
  echo "      registry_set('_community_build_', '$PACKDATE');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/community/sql/exec_no_error.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/community/sql/tables.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/community/sql/procedures.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/community/sql/wa_install.sql', 1, 'report', 1);" >> $STICKER
  echo "      ODS.COMMUNITY.community_install();" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/community/sql/wa_uninstall.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"post-uninstall\"></sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER

  for file in `find vad -type f -print | LC_ALL=C sort`
  do
     if echo "$file" | grep -v "\.vsp" >/dev/null
     then
	      perms="110100100N"
     else
	      perms="111101101N"
     fi
     name=`echo "$file" | cut -b10-`
     echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"$perms\" makepath=\"yes\"/>" >> $STICKER
  done

  echo "</resources>" >> $STICKER
  echo "<registry>" >> $STICKER
  echo "</registry>" >> $STICKER
  echo "</sticker>" >> $STICKER
}

virtuoso_init() {
  LOG "Virtuoso.ini creation..."
  echo "
[Database]
DatabaseFile    = virtuoso.db
TransactionFile = virtuoso.trx
ErrorLogFile    = virtuoso.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog		= 0

;
;  Server parameters
;
[Parameters]
ServerPort           = $PORT
ServerThreads        = 100
CheckpointInterval   = 0
NumberOfBuffers      = 2000
MaxDirtyBuffers      = 1200
MaxCheckpointRemap   = 2000
UnremapQuota         = 0
AtomicDive           = 1
PrefixResultNames    = 0
CaseMode             = 2
DisableMtWrite       = 0
MaxStaticCursorRows  = 5000
AllowOSCalls         = 0
DirsAllowed          = $HOME
CallstackOnException = 1

;
; HTTP server parameters
;
; Timeout values are seconds
;

[HTTPServer]
ServerPort = $TPORT
ServerRoot = .
ServerThreads = 5
MaxKeepAlives = 10
EnabledDavVSP = 1

[Client]
SQL_QUERY_TIMEOUT  = 0
SQL_TXN_TIMEOUT    = 0
SQL_PREFETCH_ROWS  = 100
SQL_PREFETCH_BYTES = 16000
SQL_NO_CHAR_C_ESCAPE = 0

[AutoRepair]
BadParentLinks = 0
BadDTP         = 0

[Replication]
ServerName   = the_big_server
ServerEnable = 1
QueueMax     = 50000

" > virtuoso.ini
  if [ -f virtuoso.lic ]
  then
    echo "virtuoso.lic found"
  else
    cp $HOME/binsrc/tests/suite/virtuoso.lic virtuoso.lic 2>/dev/null
  fi
  virtuoso_start
}

vad_create() {
  echo $DSN;
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', 'ods_community_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

echo '------------------------'
echo 'Community VAD create'
echo '------------------------'

STOP_SERVER
directory_clean
VERSION_INIT
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
STOP_SERVER
chmod 644 ods_community_dav.vad
directory_clean

echo 'Successful create'

