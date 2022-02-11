#!/bin/sh
# Helm Chart S3 Repo 

set -e
read -p 'Version of Chart: ' version

echo 'Updating dependencies...'
helm dependency update

echo 'Packaging the Chart...'
helm package .

packaged_file="app-$version.tgz"
if [ -f "$packaged_file" ]; then
    echo "$packaged_file created."
else
    echo "$packaged_file not exists."
    exit 1;
fi

echo 'Pushing packaged file to S3 Chart Repository...'
helm s3 push ./app-$version.tgz stable-app-base --force

echo 'Updatind Helm Repository...'
helm repo update

echo 'Chacking Helm Repository version and your Chart version...'
if helm search repo stable-app-base --version $version| grep $version ; then
    echo 'Chart was successfully uploaded.';
else
    echo 'cannot find the version in Chart Repository.';
    exit 1;
fi

echo 'pulling override.yaml from S3...'
aws s3 cp s3://app-helm-charts/stable/app-base/override.yaml override.yaml

echo 'Validating override.yaml...'
if grep -Fq "null" override.yaml
then
    echo 'Found `null` in override.yaml. Please check the file.';
    exit 1;
fi

echo 'Updating release...'
helm upgrade --install --wait --atomic --timeout 60s -f override.yaml stable-app-base stable-app-base/app --version $version -n app-base

echo 'Done.'
