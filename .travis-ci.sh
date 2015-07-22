wget http://homes.cs.washington.edu/~jrw12/coq-8.5beta2-build.tgz
tar xf coq-8.5beta2-build.tgz
export PATH="$(pwd)/coq-8.5beta2/bin:$PATH"
./build.sh
