#Conjur POC Install - Master install and base policies
#Please verify the commands ran before running this script in your environment

checkOS(){
  printf '\n-----'
  printf '\nInstalling dependencies'
  if [[ $(cat /etc/*-release | grep -w ID_LIKE) == 'ID_LIKE="rhel fedora"' ]]; then
    install_yum
  elif [[ $(cat /etc/*-release | grep -w ID_LIKE) == 'ID_LIKE=debian' ]]; then
    install_apt
  else
    printf "\nCouldn't figure out OS"
  fi
  printf '\n-----\n'
}

install_yum(){
#Update OS
sudo yum update -y

#install Docker CE
sudo yum install yum-utils device-mapper-persistent-data lvm2 -y
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce -y

#config docker to start automatically and start the service
sudo systemctl start docker
sudo systemctl enable /usr/lib/systemd/system/docker.service

#initiate conjur install
install_conjur
}

install_apt(){
#update OS
sudo apt-get upgrade -y

#Install packages to allow apt to use a repository over HTTPS:
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y

#Add Docker’s official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

#Set up stable docker repository
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

#Install latest version of docker-ce
sudo apt-get install docker-ce -y

#initiate conjur install
install_conjur
}

install_conjur(){
#Gather Company Name
local done=0
while : ; do
  read -p 'Please enter your company name: ' compvar
  printf  "%s\n" "You entered $compvar, is this correct (Yes or No)?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) local done=1; sed -i "s+company_name=.*+company_name=$compvar+g" config.ini; break;;
      No ) echo ""; break;;
    esac
  done
  if [[ "$done" -ne 0 ]]; then
    break
  fi
done

#Gather Hostname
local done=0
while : ; do
  read -p 'Please enter fully qualified domain name or hostname: ' hostvar
  printf "%s\n" "You entered $hostvar, is this correct (Yes or No)?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) local done=1; sed -i "s+master_name=.*+master_name=$hostvar+g" config.ini; break;;
      No ) echo ""; break;;
    esac
  done
  if [[ "$done" -ne 0 ]]; then
    break
  fi
done

#Updating cli-retrieve script based on config.ini
sed -i "s+acme+$company_name+g" $PWD/policy/cli-retrieve-password.sh
sed -i "s+conjur-master+$master_name+g" $PWD/policy/cli-retrieve-password.sh

#Load ini variables
source <(grep = config.ini)

#Load the Conjur container. Place conjur-appliance-version.tar.gz in the same folder as this script
tarname=$(find conjur-app*)
conjur_image=$(sudo docker load -i $tarname)
conjur_image=$(echo $conjur_image | sed 's/Loaded image: //')

#create docker network
sudo docker network create conjur

#start docker master container named "conjur-master"
sudo docker container run -d --name $master_name --network conjur --restart=always --security-opt=seccomp:unconfined -p 443:443 -p 5432:5432 -p 1999:1999 $conjur_image

#creates company namespace and configures conjur for secrets storage
sudo docker exec $master_name evoke configure master --hostname $master_name --admin-password $admin_password $company_name

#configure conjur policy and load variables
configure_conjur
}

configure_conjur(){
#create CLI container
sudo docker container run -d --name conjur-cli --network conjur --restart=always --entrypoint "" cyberark/conjur-cli:5 sleep infinity

#copy policy into container 
sudo docker cp policy/ conjur-cli:/

#Init conjur session from CLI container
sudo docker exec -i conjur-cli conjur init --account $company_name --url https://$master_name <<< yes

#Login to conjur and load policy
sudo docker exec conjur-cli conjur authn login -u admin -p $admin_password
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
}

checkOS
