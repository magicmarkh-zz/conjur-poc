#Conjur POC Install - Master install and base policies
#Please vet the commands ran before running this script in your environment

#Load ini variables
source <(grep = config.ini)

#Update CentOS
sudo yum update -y

#install Docker
sudo yum install yum-utils device-mapper-persistent-data lvm2 -y
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce -y

#config docker to start automatically and start the service
sudo systemctl start docker
sudo systemctl enable /usr/lib/systemd/system/docker.service

#Load the Conjur container. Place conjur-appliance-version.tar.gz in the same folder as this script
tarname=$(find conjur-app*)
conjur_image=$(sudo docker load -i $tarname)
conjur_image=$(echo $conjur_image | sed 's/Loaded image: //')

#create docker network
sudo docker network create conjur

#start docker master container named "conjur-master"
sudo docker container run -d --name $master_name --network conjur --restart=always --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $conjur_image

#creates tiaa namespace and configures conjur for secrets storage
sudo docker exec $master_name evoke configure master --hostname $master_name --admin-password Cyberark1 $company_name

#create CLI container
sudo docker container run -d --name conjur-cli --network conjur --entrypoint "" cyberark/conjur-cli:5 sleep infinity

#copy policy into container 
sudo docker cp policy/ conjur-cli:/

#Init conjur session from CLI container
sudo docker exec -i conjur-cli conjur init --account $company_name --url https://$master_name <<< yes

#Login to conjur and load policy
sudo docker exec conjur-cli conjur authn login -u admin -p Cyberark1
sudo docker exec conjur-cli conjur policy load --replace root /policy/root.yml
sudo docker exec conjur-cli conjur policy load apps /policy/apps.yml
sudo docker exec conjur-cli conjur policy load apps/secrets /policy/secrets.yml

#set values for passwords in secrets policy

sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/ansible_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/electric_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/openshift_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/docker_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/aws_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/azure_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/cd-variables/kubernetes_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/ci-variables/puppet_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/ci-variables/chef_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)
sudo docker exec conjur-cli conjur variable values add apps/secrets/ci-variables/jenkins_secret $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32)