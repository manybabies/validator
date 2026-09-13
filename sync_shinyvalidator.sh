#!/bin/bash

# Run this script to fetch updates from ShinyValidator

git fetch upstream

git checkout upstream/main -- app.R ui.R server.R common.R ErrorHandler.R

echo "ShinyValidator core files updated."
echo "Review the changes with: git diff"
echo "If everything looks correct, commit the changes."