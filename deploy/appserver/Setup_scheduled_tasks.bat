REM ================================
REM == Create the scheduled tasks ==
REM ================================

SET BATCH.DIRECTORY=D:\pingr\deploy\appserver\
SET START.BAT=D:\pingr\start.bat
SET BACKUP.BAT=D:\pingr\deploy\appserver\mongobackup.bat

SchTasks /RU system /Create /SC DAILY /TN "PINGR Data Loader" /TR "\"%BATCH.DIRECTORY%RunPINGRLoaderScript_ST_DEBUG.bat\"" /RI 20 /ST 00:12 /DU 23:00
SchTasks /RU system /Create /SC ONSTART /TN "PINGR web app" /TR "\"%START.BAT%\""
SchTasks /RU system /Create /SC DAILY /TN "PINGR MongoDB backup" /TR "\"%BACKUP.BAT%\"" /ST 21:10