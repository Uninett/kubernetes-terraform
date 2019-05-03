#!/bin/bash
set -e

CREDS=$(aws sts get-session-token --serial-number arn:aws:iam::380748159050:mfa/$USER --token-code $1)

echo " export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq .Credentials.SecretAccessKey)"
echo " export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq .Credentials.AccessKeyId)"
echo " export AWS_SESSION_TOKEN=$(echo $CREDS | jq .Credentials.SessionToken)"
