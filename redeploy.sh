#!/usr/bin/env bash

templatefile="template.yaml"
awsprofile="<AWSPROFILE>"
s3bucket="<S3-BUCKET>"
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
    -pf | --parameters)
        shift
        parameterfile=$1
        ;;
    esac
    shift
done

[ ! -f ./$templatefile ] && echo "$templatefile doesn't exist" && exit   


if [ "$deletestack" = "1" ]; then
    echo "Deleting Cloudformation stack $stackname"
    aws cloudformation delete-stack --stack-name "$stackname" --profile "$awsprofile"
    aws cloudformation wait stack-delete-complete --stack-name "$stackname"
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
