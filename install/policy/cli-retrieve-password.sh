#sample script to retrieve credential from conjur
main(){
  printf '\n-----'
  printf '\nThis Script will pull a secret via REST.'
  secret_pull 
  printf '\n-----\n'
}

secret_pull(){
  local master_name=
  local company_name=
  local conjur_cert="/root/conjur-$company_name.pem"
  local api=$(cat ~/.netrc | awk '/password/ {print $2}')
  local host_name=$(cat ~/.netrc | awk '/login/ {print $2}')
  local secret_name="apps/secrets/ci-variables/puppet_secret"
  local auth=$(curl -s --cacert $conjur_cert  -H "Content-Type: text/plain" -X POST -d "$api" https://$master_name/authn/$company_name/$host_name/authenticate)
  local auth_token=$(echo -n $auth | base64 | tr -d '\r\n')
  local secret_retrieve=$(curl --cacert $conjur_cert -s -X GET -H "Authorization: Token token=\"$auth_token\"" https://$master_name/secrets/$company_name/variable/$secret_name)
  printf "\n"
  printf "\nSecret is: $secret_retrieve" 
}

main