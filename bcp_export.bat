REM
REM s2p - SQL Server to Postgresql database migration scripts  
REM
REM @see https://github.com/coyote333666/s2p The s2p GitHub project
REM
REM @author         Vincent Fortier coyote333666@gmail.com
REM @copyright 2021 Vincent Fortier
REM @license   http://www.gnu.org/copyleft/lesser.html GNU Lesser General Public License
REM @note      This program is distributed in the hope that it will be useful - WITHOUT
REM	 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
REM	 * FITNESS FOR A PARTICULAR PURPOSE.
REM 
REM For a remote connection, you must add the parameters -S, -P and -U
REM You need to install 7-zip (or other file compressor)
REM 7-zip runs on a client workstation. If a server is used, limit 7-zip to 4 cores by command parameters.

REM Remove the pause for a scheduled task
REM PAUSE

set BCP_EXPORT_DB=<database name>
set ZIPEXE="C:\Program Files\7-Zip\7z.exe"
set DEST="<name of destination directory>"

echo start : %date% - %time% > %DEST%\bcp_export.log

FOR %%G IN (<name of the first table to export>, <second table>, <third talbe>, ...) DO (
BCP "DECLARE @colnames VARCHAR(max);SELECT @colnames = COALESCE(@colnames + CHAR(31), '') + column_name from %BCP_EXPORT_DB%.INFORMATION_SCHEMA.COLUMNS where TABLE_NAME='%%G'; select @colnames;" queryout %DEST%\%%G.onlyHeaders.csv -c -T -r 0x1E -C ACP
BCP "DECLARE @colnames VARCHAR(max);SELECT @colnames = COALESCE(@colnames + ', ', '') + CASE WHEN column_name IN ('Description') THEN 'replace(replace(convert(varchar(8000),' + column_name  + '),char(30),'' ''),char(31),'' '')' ELSE column_name END from %BCP_EXPORT_DB%.INFORMATION_SCHEMA.COLUMNS where TABLE_NAME='%%G'; EXEC('select ' + @colnames + ' FROM  %BCP_EXPORT_DB%.dbo.%%G');" queryout %DEST%\%%G.withoutHeaders.csv -c -t 0x1F -T -r 0x1E -C ACP
copy /b %DEST%\%%G.onlyHeaders.csv+%DEST%\%%G.withoutHeaders.csv %DEST%\%%G.csv 
del %DEST%\%%G.withoutHeaders.csv
del %DEST%\%%G.onlyHeaders.csv
%ZIPEXE% a %DEST%\%%G.zip %DEST%\%%G.csv
del %DEST%\%%G.csv)

echo end : %date% - %time% >> %DEST%\bcp_export.log

