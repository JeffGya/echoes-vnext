#!/usr/bin/env bash
# Profile run: patches core+test files, runs fingerprint_guide_spirit once, restores everything.
cd /home/user/echoes-vnext || exit 1
P=/tmp/claude-0/prof; PATCH=${1:?patch file}; TAG=${2:?tag}; SUITE=${3:-fingerprint_guide_spirit}
git diff --quiet -- core tests ui || { echo "tree not clean at start" >> $P/$TAG.status; exit 1; }
restore() { git checkout -q -- core tests ui; rm -f tests/TimingProbeAcc.gd tests/TimingProbeAcc.gd.uid; echo restored >> $P/$TAG.status; }
trap restore EXIT
cp $P/TimingProbeAcc.gd tests/TimingProbeAcc.gd
python3 $PATCH || { echo "patch failed" >> $P/$TAG.status; exit 1; }
export GODOT_BIN=/usr/local/bin/godot
rm -rf /tmp/echoes-vnext-prof; start=$(date +%s)
ECHOES_TEST_SAVE_DIR=/tmp/echoes-vnext-prof /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 "$GODOT_BIN" --headless --quit --path "$PWD" -- tests =$SUITE > $P/$TAG.out 2>&1
echo "done wall=$(( $(date +%s) - start ))s" >> $P/$TAG.status
