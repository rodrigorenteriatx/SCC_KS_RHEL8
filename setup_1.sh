#!/bin/bash
set -e

echo "Applying custom configs..."

# Repo config
cp auto.share1 /etc/auto.share1
cp auto.master /etc/auto.master


echo "Configs applied."

