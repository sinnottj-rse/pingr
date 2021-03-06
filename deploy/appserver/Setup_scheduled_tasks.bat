REM ================================
REM == Create the scheduled tasks ==
REM ================================

SET BATCH.DIRECTORY=D:\pingr\deploy\appserver\
SET START.BAT=D:\pingr\start.bat
SET BACKUP.BAT=D:\pingr\deploy\appserver\mongobackup.bat

SchTasks /RU system /Create /SC DAILY /TN "PINGR Data Loader" /TR "\"%BATCH.DIRECTORY%RunPINGRLoaderScript_ST_DEBUG.bat\"" /RI 20 /ST 00:12 /DU 23:00
SchTasks /RU system /Create /SC HOURLY /TN "PINGR Email Reminder" /TR "\"%BATCH.DIRECTORY%RunEmailReminderScript_ST_DEBUG.bat\"" /ST 04:03
SchTasks /RU system /Create /SC DAILY /TN "PINGR Logs to dropbox" /TR "\"%BATCH.DIRECTORY%RunLogCopyScript_ST_DEBUG.bat\"" /ST 06:30
SchTasks /RU system /Create /SC ONSTART /TN "PINGR web app" /TR "\"%START.BAT%\""
SchTasks /RU system /Create /SC DAILY /TN "PINGR MongoDB backup" /TR "\"%BACKUP.BAT%\"" /ST 21:10

REM Might need to restart TaskEng.exe to pick up new env variables
REM Also if you setup a task with a /RI and a /DU then it doesn't pick of env vars - but if you do it without then it's fine:
REM e.g. the following fails:
REM SchTasks /RU system /Create /SC DAILY /TN "PINGR Email Reminder" /TR "\"%BATCH.DIRECTORY%RunEmailReminderScript_ST_DEBUG.bat\"" /RI 60 /ST 04:03 /DU 23:00
REM but if you modify it to:
REM SchTasks /RU system /Create /SC HOURLY /TN "PINGR Email Reminder" /TR "\"%BATCH.DIRECTORY%RunEmailReminderScript_ST_DEBUG.bat\"" /ST 04:03
REM then it works!.
