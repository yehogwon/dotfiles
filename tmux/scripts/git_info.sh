#!/bin/bash

cwd=$1
cd $cwd

check_git=$(git rev-parse --is-inside-work-tree 2> /dev/null)
check_git_error=$?

if [ "$check_git_error" -eq 0 ]; then
    branch=$(git branch --show-current)

    untracked=$(git status --porcelain | grep -c "^??")
    added=$(git status --porcelain | grep -c "^ A")
    modified=$(git status --porcelain | grep -c "^ M")
    deleted=$(git status --porcelain | grep -c "^ D")

    message="$branch"
    if [ $added -gt 0 ]; then
        message="$message $added""A"
    fi
    if [ $modified -gt 0 ]; then
        message="$message $modified""M"
    fi
    if [ $deleted -gt 0 ]; then
        message="$message $deleted""D"
    fi
    if [ $untracked -gt 0 ]; then
        message="$message $untracked""U"
    fi

    echo "$message"
else
    echo "NoGit"
fi
