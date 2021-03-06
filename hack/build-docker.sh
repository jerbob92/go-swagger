#!/bin/bash

set -e -o pipefail
go test -v -race $(go list ./... | grep -v vendor) | go-junit-report -dir /usr/share/testresults

# Run test coverage on each subdirectories and merge the coverage profile.
echo "mode: ${GOCOVMODE-count}" > profile.cov
repo_pref="github.com/${CIRCLE_PROJECT_USERNAME-"$(basename `pwd`)"}/${CIRCLE_PROJECT_REPONAME-"$(basename `pwd`)"}/"
# Standard go tooling behavior is to ignore dirs with leading underscores
for dir in $(go list ./... | grep -v -E 'vendor|generator')
do
  pth="${dir//*$repo_pref}"
  go test -covermode=${GOCOVMODE-count} -coverprofile=${pth}/profile.tmp $dir
  if [ -f $pth/profile.tmp ]
  then
      cat $pth/profile.tmp | tail -n +2 >> profile.cov
      rm $pth/profile.tmp
  fi
done

go tool cover -func profile.cov
gocov convert profile.cov | gocov report
gocov convert profile.cov | gocov-html > /usr/share/coverage/coverage-${CIRCLE_BUILD_NUM-"0"}.html
go build -o /usr/share/dist/swagger ./cmd/swagger

go install ./cmd/swagger
for dir in $(ls fixtures/canary)
do
  pushd fixtures/canary/$dir
  rm -rf client models restapi cmd
  swagger generate client
  go test ./...
  swagger generate server
  go test ./...
  popd
done
