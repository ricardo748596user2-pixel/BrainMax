@echo off
REM Brain Max - inicia o relay local (Windows).
REM O app no iPad fala HTTP com este relay; o relay faz HTTPS com as APIs.
cd /d "%~dp0"
echo Iniciando Brain Max relay na porta 8890...
node server.js
pause