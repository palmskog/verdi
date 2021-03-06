opam init --yes --no-setup
eval $(opam config env)
opam repo add coq-released https://coq.inria.fr/opam/released
opam install coq.$COQ_VERSION coq-mathcomp-ssreflect.$MATHCOMP_VERSION coq-mathcomp-fingroup.$MATHCOMP_VERSION coq-mathcomp-algebra.$MATHCOMP_VERSION ounit.2.0.0 uuidm.0.9.6 --yes --verbose

pushd ..
  git clone 'http://github.com/uwplse/StructTact'
  pushd StructTact
    ./build.sh
  popd

  git clone 'http://github.com/palmskog/InfSeqExt'
  pushd InfSeqExt
    ./build.sh
  popd

  git clone 'http://github.com/uwplse/verdi' verdi-framework
  pushd verdi-framework
    ./build.sh
  popd

  git clone -b v8.5 https://github.com/coq-contribs/aac-tactics.git AAC_tactics
  pushd AAC_tactics
    make
  popd
popd

export Verdi_PATH=../verdi-framework

case $MODE in
  analytics)
    ./script/analytics.sh
    ;;
  tree-test)
    ./script/tree-test.sh
    ;;
  tree-dynamic-test)
    ./script/tree-dynamic-test.sh
    ;;
  aggregation-test)
    ./script/aggregation-test.sh
    ;;
  aggregation-dynamic-test)
    ./script/aggregation-dynamic-test.sh
    ;;
  *)
    ./build.sh
    ;;
esac
