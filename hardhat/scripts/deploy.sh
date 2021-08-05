#! /bin/bash

getField(){
 node -pe 'JSON.parse(process.argv[1]).'$1 "$(cat ../helper-hardhat-config.json)"
}

## only this networks will deploy otherwise script will processing and check NEEDS for deploy by all networks in config
## NOTE: "NEEDS" it is when address in config is epmty (=== '')
node ./_deploy.js --networks ${1} --parentpid $$

nets=${1}
if [[ ${1} =~ ^('')$ ]]
 then
  nets=$(jq 'keys[]' ../helper-hardhat-config.json)
  nets=${nets//\"/ }
  echo '> Create (override) env files only'
  for net in ${nets//\,/ }
  do    
    ./update_env_adapter.sh create $(getField ${net}.env_file[0])  RPC_URL=$(getField ${net}.rpcUrl) NETWORK_ID=$(getField ${net}.chainId) BRIDGE_ADDRESS=$(getField ${net}.bridge) NODELIST_ADDRESS=$(getField ${net}.nodeList) DEXPOOL_ADDRESS=$(getField ${net}.mockDexPool) PORTAL_ADDRESS=$(getField ${net}.portal) SYNTHESIS_ADDRESS=$(getField ${net}.synthesis) PAYMASTER_ADDRESS=$(getField ${net}.paymaster)
    ./update_env_adapter.sh create $(getField ${net}.env_file[1]) BRIDGE_$(getField ${net}.n)=$(getField ${net}.bridge) NODELIST_$(getField ${net}.n)=$(getField ${net}.nodeList) DEXPOOL_$(getField ${net}.n)=$(getField ${net}.mockDexPool) PORTAL_$(getField ${net}.n)=$(getField ${net}.portal) SYNTHESIS_$(getField ${net}.n)=$(getField ${net}.synthesis) PAYMASTER_$(getField ${net}.n)=$(getField ${net}.paymaster)    
    echo $(getField ${net}.env_file[0])
    echo $(getField ${net}.env_file[1])
  done
  exit 0
 fi

for net in ${nets//\,/ }
do
echo 'bash script for network:' ${net}
cd ../packages/gasless
npx hardhat run ./scripts/deploy.js --network ${net}
cd ../bridge
npx hardhat run ./scripts/deploy.js --network ${net}
cd ../amm_pool
npx hardhat run ./scripts/deploy.js --network ${net}
cd ../../scripts
./update_env_adapter.sh create $(getField ${net}.env_file[0])  RPC_URL=$(getField ${net}.rpcUrl) NETWORK_ID=$(getField ${net}.chainId) BRIDGE_ADDRESS=$(getField ${net}.bridge) NODELIST_ADDRESS=$(getField ${net}.nodeList) DEXPOOL_ADDRESS=$(getField ${net}.mockDexPool) PORTAL_ADDRESS=$(getField ${net}.portal) SYNTHESIS_ADDRESS=$(getField ${net}.synthesis) PAYMASTER_ADDRESS=$(getField ${net}.paymaster)
./update_env_adapter.sh create $(getField ${net}.env_file[1]) BRIDGE_$(getField ${net}.n)=$(getField ${net}.bridge) NODELIST_$(getField ${net}.n)=$(getField ${net}.nodeList) DEXPOOL_$(getField ${net}.n)=$(getField ${net}.mockDexPool) PORTAL_$(getField ${net}.n)=$(getField ${net}.portal) SYNTHESIS_$(getField ${net}.n)=$(getField ${net}.synthesis) PAYMASTER_$(getField ${net}.n)=$(getField ${net}.paymaster)

##
## init
##
cd  ../packages/bridge
npx hardhat run ./scripts/updateDexBind.js  --network ${net}
cd ../amm_pool
npx hardhat run ./scripts/createRepresentation.js --network ${net}
cd ../

done