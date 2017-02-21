#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

#
# Step 1 - get kubernetes source
#

# TODO: Check if we can use a release tarball instead of this checkout
# and partial build method.
CONFORMANCE_TAG="v1.5.3"
REPO="go/src/kubernetes/kubernetes"

# bring in required files
rm -rf $REPO
mkdir -p $REPO
export GOPATH="${PWD}/go"

pushd $REPO && \
    curl -sSL "https://github.com/kubernetes/kubernetes/archive/${CONFORMANCE_TAG}.tar.gz" | tar -xz --strip=1
    make all WHAT=cmd/kubectl && \
    make all WHAT=vendor/github.com/onsi/ginkgo/ginkgo && \
    make all WHAT=test/e2e/e2e.test
popd

#
# Step 2 - prepare test environment
#
export KUBECONFIG=${PWD}/../ansible/kubeconfig
export KUBERNETES_CONFORMANCE_TEST=y
export KUBERNETES_PROVIDER=skeleton

#
# Step 3a - run the tests
#
pushd "$REPO"
# Possible new style:
# go get -u k8s.io/test-infra/kubetest
# kubetest -v --check_version_skew=false --test --test_args="--ginkgo.focus=\[Conformance\]"

# For now, go with old style/shim:
go run hack/e2e.go -v --test --test_args="--ginkgo.focus=\[Conformance\]"

#
# Step 3b - Alternative, parallell way (2 parts):
# run all parallel-safe conformance tests in parallel, old style
#GINKGO_PARALLEL=y go run hack/e2e.go -v --test --test_args="--ginkgo.focus=\[Conformance\] --ginkgo.skip=\[Serial\]"
# ... and finish up with remaining tests in serial, old style
#go run hack/e2e.go -v --test --test_args="--ginkgo.focus=\[Serial\].*\[Conformance\]"
