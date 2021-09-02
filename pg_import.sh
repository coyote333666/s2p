#!/bin/bash
#
# s2p - SQL Server to Postgresql database migration scripts  
#
# @see https://github.com/coyote333666/s2p The s2p GitHub project
#
# @author         Vincent Fortier coyote333666@gmail.com
# @copyright 2021 Vincent Fortier
# @license   http://www.gnu.org/copyleft/lesser.html GNU Lesser General Public License
# @note      This program is distributed in the hope that it will be useful - WITHOUT
#	 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#	 * FITNESS FOR A PARTICULAR PURPOSE.
#
#       NOTE 			: to be executed by the <database name> account
#
#		to check for the presence of a delimiter in a file :
#		perl -ne '$x++;if($_=/\x1D/){print"$x\n"}' <file name>.csv
#
#       to be executed in a crontab or on a command line:
#       ./pg_import.sh
#
#       to be executed preferably first in DEV in order to detect / correct the modifications to the structure of the DB
#       if there is a structural modification to the database, modify the affected files

localPath='<zip files directory name>'
sourcePath='<sql scripts directory name>'
email='<first email address>'
email2='<second email address>'

echo beginning of the script $(date +%F_%R)

# we convert the export file of the BCP command of MSSQL
# in import file for the COPY command of Postgresql 
# there are some UTF-8 characters on 2 bytes, they also need to be converted to ISO-8859-1 equivalent
for zipFile in $localPath*.zip
do 
unzip -o $zipFile -d $localPath 
rm $zipFile
f=${zipFile%.*}.csv
iconv -f ISO-8859-1 -t UTF-8 $f > $f.tmp1
rm $f
awk -v a="$f.tmp2" -v b="$f.dis" 'BEGIN {FS="\x1F"; RS="\x1E"; OFS="\x1F"; ORS="\n"; }
NR == 1 {nb_champs = NF}
{if(NF != nb_champs) 
{gsub("\x0","",$0); 
 gsub("\r\n","\n",$0); 
 gsub("\r","",$0); 
 gsub("\n","<br>",$0); 
 gsub("\x22","\\\x22",$0); 
 gsub("\x8","",$0); 
 gsub("\xc2\x92","\x27",$0); 
 gsub("\xc2\x9c","oe",$0); 
 print $0 > b} 
else {gsub("\x0","",$0); 
 gsub("\r\n","\n",$0); 
 gsub("\r","",$0); 
 gsub("\n","<br>",$0); 
 gsub("\x22","\\\x22",$0); 
 gsub("\x8","",$0); 
 gsub("\xc2\x92","\x27",$0); 
 gsub("\xc2\x9c","oe",$0); 
 print $0 > a}}' $f.tmp1
rm $f.tmp1
cp $f.tmp2 $f.utf8
rm $f.tmp2

# we compare the header of the current file with that of the last load
# to check if the database structure has changed
if [ ! -f "$f.header_before" ]
then
head -1 $f.utf8 > $f.header_before
fi	
head -1 $f.utf8 > $f.header_after
diff $f.header_before $f.header_after > $f.diff
rm $f.header_after
head -1 $f.utf8 > $f.header_before

# we put a header to the rejects file
if [ -f "$f.dis" ]
then
cat $f.header_before $f.dis > $f.discards
rm $f.dis
fi	

# we stop the script if a modification in the structure of the database has been made
if [ -s "$f.diff" ]
then 
echo '<html><body>Hi,<br><br>
A modification in the structure of the file in object has been made since the last loading<br><br>
Please take action to correct the structure in the database.<br><br>
Have a nice day ! <br><br> ' > $f.email_body
echo '</body></html>' > $f.email_end
cat $f.email_body $f.diff $f.email_end > $f.email
rm $f.email_body
rm $f.email_end
cat $f.email | /usr/bin/mail -a "Content-Type: text/html; charset=UTF-8" -s "Database loading notification : ${f} file structure altered" ${email} ${email2}
sleep 2
exit
fi

# end of the script
done

echo drop table $(date +%F_%R)
psql -f $sourcePath'<drop table script>.sql'

echo create table $(date +%F_%R)
psql -f $sourcePath'<create table script>.sql'

echo insert $(date +%F_%R)
psql -f $sourcePath'<insert script>.sql'

echo create index $(date +%F_%R)
psql -f $sourcePath'<create index script>.sql'

# we send a confirmation email
echo '<html><body>Hi,<br><br>
Loading is completed.<br><br>
Please check if there are any .discards files on the database server<br><br>
Have a nice day!<br><br></body></html>' | /usr/bin/mail -a "Content-Type: text/html; charset=UTF-8" -s "Database loading notification : loading is completed" ${email} ${email2}

echo end of the script $(date +%F_%R)

