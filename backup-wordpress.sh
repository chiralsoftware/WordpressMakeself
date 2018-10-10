#!/bin/bash

echo Creating self-extracting Wordpress site

type mysqldump >/dev/null 2>&1 || { echo >&2 "I require mysqldump command"; exit 1; }
type mysql >/dev/null 2>&1 || { echo >&2 "I require mysql command"; exit 1; }
type makeself >/dev/null 2>&1 || { echo >&2 "I require makeself command"; exit 1; }
type brotli >/dev/null 2>&1 || { echo >&2 "I require brotli command"; exit 1; }
type php >/dev/null 2>&1 || { echo >&2 "I require php command"; exit 1; }

# save a copy of this script into the backup file
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

SAVED_DIR=$PWD

WORK_DIR=$(mktemp -d)
chmod go-rwx $WORK_DIR

BACKUP_DATE=$(date "+%Y-%m-%d-%H-%M")

# echo Backup date is: $BACKUP_DATE

# echo "working directory: $WORK_DIR"
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo "Could not create temp dir"
    exit 1
fi

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   
    echo -n "$var"
}

cd $SCRIPTPATH
readarray LINES \
	  <<< $({ cat wp-config.php; echo 'echo DB_USER . "\n" . DB_PASSWORD . "\n" . DB_HOST . "\n" . DB_NAME . "\n";'; } \
		    | php | sed '/^\s*$/d')

DB_USER=$(trim ${LINES[0]})
DB_PASSWORD=$(trim ${LINES[1]})
DB_HOST=$(trim ${LINES[2]})
DB_NAME=$(trim ${LINES[3]})

#echo db access: $DB_USER, $DB_PASSWORD, $DB_HOST, $DB_NAME

mysql -u $DB_USER -p$DB_PASSWORD --host=$DB_HOST $DB_NAME -e ";" || { echo >&2 "could not connect to mysql"; exit 1; }

SITE_NAME=$(mysql -B --skip-column-names -u $DB_USER -p$DB_PASSWORD --host=$DB_HOST $DB_NAME -e "select option_value from wp_options where option_name = 'blogname';"  | sed -e 's/ /-/g')

echo mysql connection works

mysqldump -u $DB_USER -p$DB_PASSWORD --host=$DB_HOST --add-drop-database --databases $DB_NAME | \
    brotli -c --quality=9 > $WORK_DIR/database-$BACKUP_DATE.sql.br \
    || { echo >&2 "mysqldump command failed"; exit 1; }

#cp $WORK_DIR/database-$BACKUP_DATE.sql.br /tmp
#echo I created $WORK_DIR/database-$BACKUP_DATE.sql.br


SITE=$(basename $SCRIPTPATH)

cd $SCRIPTPATH/..
tar --exclude-backups --exclude=.svn -c -f - $SITE | brotli --quality=9 > $WORK_DIR/html-$BACKUP_DATE.tar.br \
    || { echo >&2 "tar command failed"; exit 1; }

ME=`basename "$0"`
cp $SCRIPTPATH/$ME $WORK_DIR/$ME || { echo >&2 "Failed to copy $SCRIPTPATH/$ME"; exit 1; }

cd $SCRIPTPATH/..
INSTALLPATH=$PWD

echo "#!/bin/bash" > $WORK_DIR/install.sh
chmod u+x $WORK_DIR/install.sh
chmod go-rwx $WORK_DIR/install.sh
echo "echo Wordpress backup of $(date)" >> $WORK_DIR/install.sh
echo "echo" >> $WORK_DIR/install.sh
echo "rm -rf $SCRIPTPATH" >> $WORK_DIR/install.sh
echo "echo Replacing database" >> $WORK_DIR/install.sh
echo "brotli --decompress < ./database-$BACKUP_DATE.sql.br | mysql -u $DB_USER -p$DB_PASSWORD --host=$DB_HOST " >> $WORK_DIR/install.sh
echo "echo Replacing HTML" >> $WORK_DIR/install.sh
echo "brotli --decompress < ./html-$BACKUP_DATE.tar.br  | tar -x -f - --directory=$INSTALLPATH" >> $WORK_DIR/install.sh
echo "echo Performing chown" >> $WORK_DIR/install.sh
echo "chown -R www-data:www-data $SCRIPTPATH" >> $WORK_DIR/install.sh
echo 'a2query >/dev/null 2>&1 || { echo >&2 "a2query not found, so apache installation is incomplete"; exit 1; }' >> $WORK_DIR/install.sh
echo 'TEST=$(a2query  -m rewrite)' >> $WORK_DIR/install.sh
echo 'if [ "$TEST" = "rewrite (enabled by site administrator)" ] ; then' >> $WORK_DIR/install.sh
echo '    echo mod_rewrite is enabled' >> $WORK_DIR/install.sh
echo 'else' >> $WORK_DIR/install.sh
echo '    echo mod_rewrite is not enabled, so your Apache installation is incorrect or incomplete' >> $WORK_DIR/install.sh
echo 'fi' >> $WORK_DIR/install.sh

cd $SAVED_DIR

makeself $WORK_DIR $SITE_NAME-wordpress-$BACKUP_DATE.sh Wordpress-backup ./install.sh

chmod go-rwx $SITE_NAME-wordpress-$BACKUP_DATE.sh

# TODO
# add some option to automatically SCP this over
