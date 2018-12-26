main(){
  printf '\n-----'
  printf '\nThis Script will pull a secret via REST.'
  secret_pull 
  printf '\n-----\n'
}

secret_pull(){
  local conjurCert="/root/conjur-acme.pem"
  local api=$(cat ~/.netrc | awk '/password/ {print $2}')
  local hostname=$(cat ~/.netrc | awk '/login/ {print $2}')
  local secret_name="apps/secrets/ci-variables/puppet_secret"
  local auth=$(curl -s --cacert $conjurCert  -H "Content-Type: text/plain" -X POST -d "$api" https://conjur-master/authn/acme/$hostname/authenticate)
  local auth_token=$(echo -n $auth | base64 | tr -d '\r\n')
  local secret_retrieve=$(curl --cacert $conjurCert -s -X GET -H "Authorization: Token token=\"$auth_token\"" https://conjur-master/secrets/acme/variable/$secret_name)
  printf "\n"
  printf "\nSecret is: $secret_retrieve" 
}

main