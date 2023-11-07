SET OLDPATH=%CD%
cd C:\src\github.com\MetaFFI\metaffi-core\out\ubuntu\x64\debug
docker build --progress=plain -f %OLDPATH%\Dockerfile -t tscs/metaffi:0.0.1 .
cd %OLDPATH%
docker push tscs/metaffi:0.0.1
docker tag tscs/metaffi:0.0.1 tscs/metaffi:latest
docker push tscs/metaffi:latest