#!/bin/bash
# Shell script to Upgrade MongoDB, Redis & Beanstalk environments
#
# Madura Dissanayake
#
# ===================================================================
# CONFIG - Only edit the below lines to setup the script
# ===================================================================
#
#AWS EC2 Instances 
MONGO_INSTANCE_ID=<EC2InstanceID>
REDIS_INSTANCE_ID=<EC2InstanceID>

#AWS Beanstalk Environments
GATEWAY_API_EB=<EnvironmentName>
TRIVIA_SERVICE_EB=<EnvironmentName>

#AWS EBConfigs
GATEWAY_API_CONFIG_FILE="file:///opt/automation-scripts/ebconfigs/prod-API-GW-downgrade.json"
TRIVIA_SERVICE_CONFIG_FILE="file:///opt/automation-scripts/ebconfigs/prod-trivia-downgrade.json"

#Get Beanstalk & EC2 HealthCheck status
MONGODB_HEALTH="$(aws ec2 describe-instances --instance-ids $MONGO_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
REDIS_HEALTH="$(aws ec2 describe-instances --instance-ids $REDIS_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"

#Get EC2 Instance stopped status
MONGODB_STOPPED_STATUS="$(aws ec2 describe-instances --filters "Name=instance-id,Values=$MONGO_INSTANCE_ID" | grep Code | sed 's/[a-z A-Z " : , . ]//g' | sed -e '1d;3d')"
RADIS_STOPPED_STATUS="$(aws ec2 describe-instances --filters "Name=instance-id,Values=$REDIS_INSTANCE_ID" | grep Code | sed 's/[a-z A-Z " : , . ]//g' | sed -e '1d;3d')"

checkMongoDBHealth (){
	for (( ; ; ))
	do
        	STATUS="$(aws ec2 describe-instances --instance-ids $MONGO_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
        	if [ "$STATUS" == "16" ]; then
                	echo "MongoDB is Running"
                	break
     	   	fi
	done

}

checkRedisServerHealth (){
        for (( ; ; ))
        do
                STATUS="$(aws ec2 describe-instances --instance-ids $REDIS_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
                if [ "$STATUS" == "16" ]; then
                        echo "Redis Server is Running"
                        break
                fi
        done

}

downgradeMongoDB (){
        aws ec2 stop-instances --instance-ids $MONGO_INSTANCE_ID > /dev/null 2>&1
	
	for (( ; ; ))
	do
        STATUS="$(aws ec2 describe-instances --instance-ids $MONGO_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
        if [ "$STATUS" == "80" ]; then
		aws ec2 modify-instance-attribute --instance-id $MONGO_INSTANCE_ID --instance-type "{\"Value\": \"t2.micro\"}" > /dev/null 2>&1
		aws ec2 start-instances --instance-ids $MONGO_INSTANCE_ID > /dev/null 2>&1
                break
        fi
	done
	checkMongoDBHealth

}

downgradeRedis (){
        aws ec2 stop-instances --instance-ids $REDIS_INSTANCE_ID > /dev/null 2>&1
	for (( ; ; ))
        do
        STATUS="$(aws ec2 describe-instances --instance-ids $REDIS_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
        if [ "$STATUS" == "80" ]; then
                aws ec2 modify-instance-attribute --instance-id $REDIS_INSTANCE_ID --instance-type "{\"Value\": \"t2.micro\"}" > /dev/null 2>&1
                aws ec2 start-instances --instance-ids $REDIS_INSTANCE_ID > /dev/null 2>&1
                break
        fi
        done
	checkRedisServerHealth

}

downgradeAPIGWservice (){

	aws elasticbeanstalk update-environment --environment-name $GATEWAY_API_EB --option-settings $GATEWAY_API_CONFIG_FILE > /dev/null 2>&1
	for (( ; ; ))
	do
        	STATUS="$(aws elasticbeanstalk describe-environment-health --environment-name $GATEWAY_API_EB --attribute-names Status | awk -F "[, ]+" '/"Status":/{print}' | awk 'NR == 1 {print $2}' |  sed 's/[" , .]//g')"
        	if [ "$STATUS" == "Ready" ]; then
                	echo -e "\nDowngrading GATEWAY API EB"
                	break
        	fi
	done

}

downgradeTriviaService (){

	aws elasticbeanstalk update-environment --environment-name $TRIVIA_SERVICE_EB --option-settings $TRIVIA_SERVICE_CONFIG_FILE > /dev/null 2>&1
	for (( ; ; ))
	do
        	STATUS="$(aws elasticbeanstalk describe-environment-health --environment-name $TRIVIA_SERVICE_EB --attribute-names Status | awk -F "[, ]+" '/"Status":/{print}' | awk 'NR == 1 {print $2}' |  sed 's/[" , .]//g')"
        	if [ "$STATUS" == "Ready" ]; then
                	echo -e "\nDowngrading TRIVIA SERVICE"
                	break
        	fi
	done
}

# Main Script starts from here
# Downgrading MongoDB
for (( ; ; ))
do
        STATUS="$(aws ec2 describe-instances --instance-ids $MONGO_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
        if [ "$STATUS" == "16" ]; then
                downgradeMongoDB
                break
        fi
done

# Downgrading Redis
for (( ; ; ))
do
        STATUS="$(aws ec2 describe-instances --instance-ids $REDIS_INSTANCE_ID | awk -F "{,}+" '/"Code":|^"Name":/{print}' | sed 's/[a-z A-Z " : , .]//g' | sed '/^\s*$/d')"
        if [ "$STATUS" == "16" ]; then
                downgradeRedis
                break
        fi
done

# Downgrading GateWayAPI
for (( ; ; ))
do
        STATUS="$(aws elasticbeanstalk describe-environment-health --environment-name $GATEWAY_API_EB --attribute-names Status | awk -F "[, ]+" '/"Status":/{print}' | awk 'NR == 1 {print $2}' |  sed 's/[" , .]//g')"
        if [ "$STATUS" == "Ready" ]; then
                downgradeAPIGWservice
                break
        fi
done

# Downgrading Trivia Service
for (( ; ; ))
do
        STATUS="$(aws elasticbeanstalk describe-environment-health --environment-name $TRIVIA_SERVICE_EB --attribute-names Status | awk -F "[, ]+" '/"Status":/{print}' | awk 'NR == 1 {print $2}' |  sed 's/[" , .]//g')"
        if [ "$STATUS" == "Ready" ]; then
                downgradeTriviaService
                break
        fi
done
