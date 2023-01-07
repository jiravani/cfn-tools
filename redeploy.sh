#!/usr/bin/env bash

templatefile="template.yaml"
awsprofile="<AWS Profile>"
s3bucket="<S3 Bucket>"
username=$(echo "${USER//./}")
stackname=$username-stack-$(date +"%Y-%m-%d")

while [ "$1" != "" ]; do
    case "$1" in
    -f | --template-file)
        shift
        templatefile=$1
        ;;
    -s | --stack-name)
        shift
        stackname=$1
        ;;
    -t | --teardown)
        shift
        teardown=1
        deletestack=1
        ;;
    -d | --delete)
        deletestack=1
        ;;
    -p | --profile)
        shift
        awsprofile=$1
        ;;
    -po | --parameter-overrides)
        shift
        parameterfile=$1
        ;;
    -h | --help)
        shift
        help=1
        ;;
    esac
    shift
done

if [ "$help" = "1" ]; then
    echo \
    "This script (re)deploys a cloudformation stack for fast iteration.

    Usage: redeploy [options] ..
    -s, --stack-name            Override default stack name
    -f, --template-file         Override CloudFormation template file
    -po, --parameter-overrides  Provide a parameters.json CloudFormation parameters, maps to 'aws cloudformation deploy --parameter-overrides'
    -p, --profile               Override default AWS profile

    -d, --delete                Deletes the CloudFormation stack before redeploying
    -t, --teardown              Tear down CloudFormation stack, ignores all other parameters, exits program

    -h, --help                  This help.

    Examples:

    redeploy -t                 Tears down the CloudFormation stack with the default name and profile, exits program
    redeploy -d -s test         Deletes and redeploys a CloudFormation stack and renames the stack to 'test'
    redeploy -p sandbox -po parameter.json 
                                (Re)deploys a CloudFormation stack using the 'sandox' AWS profile and uses the CloudFormation parameters as defined in the 'parameters.json' file
    " 
    exit
fi;

[ ! -f ./$templatefile ] && echo "The expected template file $templatefile could not be found. Please specify your CloudFormation template file with -f or --template-file." && exit   


if [ "$deletestack" = "1" ]; then
    echo "Deleting Cloudformation stack $stackname"
    aws cloudformation delete-stack --stack-name "$stackname" --profile "$awsprofile"
    aws cloudformation wait stack-delete-complete --stack-name "$stackname"
    echo "$stackname was deleted."
    if [ "$teardown" = "1" ];then
        exit
    fi;
fi;  
    
aws cloudformation package  --template-file "$templatefile" \
                            --output-template-file "packaged-$templatefile" \
                            --s3-bucket "$s3bucket" --profile "$awsprofile" > /dev/null

echo "Successfully packaged artifacts and wrote output template to file packaged-$templatefile."
if [ -z "$parameters" ];
then  
    aws cloudformation deploy --template "packaged-$templatefile" \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name "$stackname" \
    --profile "$awsprofile" \
    --parameter-overrides "file://./$parameterfile" 
    
    aws cloudformation describe-stack-events --stack-name "$stackname" \
    --query 'StackEvents[].[Timestamp, ResourceStatus, LogicalResourceId, ResourceStatusReason]' \
    --output table

else
    aws cloudformation deploy --template "packaged-$templatefile" \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name "$stackname" \
    --profile "$awsprofile" 
    aws cloudformation describe-stack-events --stack-name "$stackname" \
    --query 'StackEvents[].[Timestamp, ResourceStatus, LogicalResourceId, ResourceStatusReason]' \
    --output table
fi;

