@echo off
REM Brain Max - inicia o servidor web local (PC).
REM O iPad (Safari) abre a pagina servida por este servidor; o servidor fala com as APIs.
cd /d "%~dp0"
echo Iniciando Brain Max servidor web na porta 8890...
echo Abra no iPad:  http://SEU-IP-DESTE-PC:8890
node server.js
pause