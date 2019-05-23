%comspec% /k "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

cd %ROOT_DIR%\gpdb_src\src\tools\msvc
echo "our $config = {gss => 'C:/ext', openssl => 'c:/ext', zlib => 'c:/ext'};"  >config.pl

build client
install %ROOT_DIR%\greenplum-db-devel client
