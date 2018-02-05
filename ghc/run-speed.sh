#!/bin/bash

function say {
	echo
	echo "$@"
	echo
}

function run {
	echo "$@"
	"$@"
}

function runt {
	echo "$@"
	timeout -k 4h 3h "$@"
}

rev="$1"
if [ -z "$rev" ]
then
  echo "$0 <rev>"
fi

set -e


cd ~/logs/

echo Updating ~/all-repo-cache
git -C ~/all-repo-cache/ fetch --all --quiet

if [ -e "ghc-tmp-$rev" ]
then
	echo "ghc-tmp-$rev already exists"
	exit 1
fi

#logfile="$rev-$(date --iso=minutes).log"
logfile="$rev.log"
exec > >(sed -e "s/ghc-tmp-$rev/ghc-tmp-REV/g" | tee "$logfile".tmp)
exec 2>&1

set -o errtrace

function failure {
	test -f "$logfile".tmp || cd ..
	say "Failure..."
	run mv "$logfile".tmp "$logfile".broken
	run rm -rf "ghc-tmp-$rev"
}
trap failure ERR

say "Begin building"

date -R

say "Cloning"

run git clone --reference ~/all-repo-cache/ git://git.haskell.org/ghc "ghc-tmp-$rev"
cd "ghc-tmp-$rev"
run git checkout "$rev"

# Fixup 1
if git merge-base --is-ancestor  15b9bf4ba4ab47e6809bf2b3b36ec16e502aea72 $rev &&
   ! git merge-base --is-ancestor  d55a9b4fd5a3ce24b13311962bca66155b17a558 $rev
then
   echo "In range 15b9bf4..d55a9b4; applying patch d55a9b4"
   git cherry-pick d55a9b4fd5a3ce24b13311962bca66155b17a558
fi

# Fixup 2
if git merge-base --is-ancestor  cea7141851ce653cb20207da3591d09e73fa396d $rev &&
   ! git merge-base --is-ancestor  03c7dd0941fb4974be54026ef3e4bb97451c3b1f $rev
then
   echo "In range cea71418..03c7dd09; applying patch 03c7dd09"
   git cherry-pick 03c7dd0941fb4974be54026ef3e4bb97451c3b1f
fi

if git merge-base --is-ancestor  8ae263ceb3566a7c82336400b09cb8f381217405 $rev &&
   ! git merge-base --is-ancestor  7b8827ab24a3af8555f1adf250b7b541e41d8f5d $rev
then
   echo "In range 8ae263c..7b8827a; applying patch 7b8827a"
   git cherry-pick 7b8827ab24a3af8555f1adf250b7b541e41d8f5d
fi

if git merge-base --is-ancestor  063e0b4e5ea53a02713eb48555bbd99d934a3de5 $rev &&
   ! git merge-base --is-ancestor  e29912125218aa4e874504e7d403e2f97331b8c9 $rev
then
   echo "In range 063e0b..e29912; applying patch e29912"
   git cherry-pick e29912125218aa4e874504e7d403e2f97331b8c9
fi

git submodule update --reference ~/all-repo-cache/ --init

say "Identifying"

run git log -n 1

#say "Code stats"
#
#run ohcount compiler/
#
#run ohcount rts/
#
#run ohcount testsuite/

say "Booting"

runt perl boot

say "Configuring"

echo "Try to match validate settings"
echo 'GhcHcOpts  = '                               >> mk/build.mk # no -Rghc-timing
echo 'GhcLibWays := $(filter v dyn,$(GhcLibWays))' >> mk/build.mk
echo 'GhcLibHcOpts += -O -dcore-lint'              >> mk/build.mk
echo 'GhcStage1HcOpts += -O'                       >> mk/build.mk
echo 'GhcStage2HcOpts += -O -dcore-lint'           >> mk/build.mk
echo 'SplitObjs          = NO'                     >> mk/build.mk
echo 'SplitSections      = NO'                     >> mk/build.mk
echo 'BUILD_PROF_LIBS    = NO'                     >> mk/build.mk
echo 'HADDOCK_DOCS       = NO'                     >> mk/build.mk
echo 'BUILD_SPHINX_HTML  = NO'                     >> mk/build.mk
echo 'BUILD_SPHINX_PDF   = NO'                     >> mk/build.mk


runt ./configure

say "Building"

runt /usr/bin/time -o buildtime make -j8 V=0
echo "Buildtime was:"
cat buildtime

say "Running the testsuite"

run make -C testsuite fast VERBOSE=4 THREADS=8 || true

say "Running nofib"

runt make -C nofib boot mode=fast -j8
runt make -C nofib EXTRA_RUNTEST_OPTS='-cachegrind +RTS -V0 -RTS' NoFibRuns=1 mode=fast -j8

say "Total space used"

run du -sc .

say "Cleaning up"

run cd ..
run rm -rf "ghc-tmp-$rev"
run mv "$logfile".tmp "$logfile"

say "Done building"

date -R

