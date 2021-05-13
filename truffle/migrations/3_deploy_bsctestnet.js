const { exec } = require('child_process');


const NodeList                          = artifacts.require('NodeList');
const Bridge                            = artifacts.require('Bridge');
const ProxyAdminBridge                  = artifacts.require('ProxyAdminBridge');
const TransparentUpgradeableProxyBridge = artifacts.require('TransparentUpgradeableProxyBridge');

module.exports = async (deployer, network, accounts) => {

  
  if (network === 'bsctestnet') {
     try {
              const initializeData = Buffer.from('');
              const [proxyAdminOwner, newAdmin, anotherAccount] = accounts;

                                        await deployer.deploy(NodeList, { from: proxyAdminOwner });
              let nodeList            = await NodeList.deployed();              


                                        await deployer.deploy(Bridge, { from: proxyAdminOwner });
              let bridge              = await Bridge.deployed();

                                        await deployer.deploy(ProxyAdminBridge, { from: proxyAdminOwner });
              let proxyAdminBridge    = await ProxyAdminBridge.deployed();    
                                        await deployer.deploy(TransparentUpgradeableProxyBridge,
                                                              bridge.address,
                                                              proxyAdminBridge.address,
                                                              initializeData,
                                                              {from: proxyAdminOwner});

              let tupb                = await TransparentUpgradeableProxyBridge.deployed();

              
              let env_file = "env_connect_to_network2.env";
              exec(`${process.cwd()}/scripts/bash/update_env_adapter.sh 8081 NETWORK2 ${bridge.address} ${tupb.address} ${proxyAdminBridge.address} ${env_file} ${nodeList.address}`, { maxBuffer: 1024 * 100000000 }, (err, stdout, stderr) => {
                if (err) {
                    console.log('THROW ERROR', err);
                    return;
                }
              });

            } catch (err) {
              console.error(err)
            }
  
    }
}