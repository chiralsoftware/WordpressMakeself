# WordpressMakeself
Use Makeself to create self-extracting and self-installing Wordpress backups

# How to use

Store this file in the root of your Wordpress installation, usually /var/www/html. From some other location in the filesystem,
run it, like:

   /var/www/html/backup-wordpress.sh
   
This will create a self-extracting file. It copies the database by extracting database username and password
from the Wordpress config file. 

To use the file, simply run it. It will replace the database and the HTML files. 
