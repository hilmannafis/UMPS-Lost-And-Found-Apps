@echo off
echo Configuring CORS for Firebase Storage...
echo.
echo Make sure you have gsutil installed and authenticated.
echo If not, install from: https://cloud.google.com/storage/docs/gsutil_install
echo.
echo Running: gsutil cors set cors.json gs://lostandfound-c39bd.firebasestorage.app
echo.
gsutil cors set cors.json gs://lostandfound-c39bd.firebasestorage.app
echo.
echo CORS configuration complete!
echo Please wait a few minutes for changes to propagate, then refresh your browser.
pause


