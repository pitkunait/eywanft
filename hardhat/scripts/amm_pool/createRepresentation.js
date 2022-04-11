let networkConfig = require(process.env.HHC_PASS ? process.env.HHC_PASS : '../../helper-hardhat-config.json')
const { addressToBytes32, timeout } = require('../../utils/helper');
const hre = require("hardhat");

async function main() {

  this.s = await networkConfig[network.name].synthesis;
  this.p = await networkConfig[network.name].portal;
  this.sourceForRepresentation = networkConfig[network.name].sourceForRepresentation;
  this.networks = process.env.NETS.trim().split(",");

  const [deployer] = await ethers.getSigners();
  console.log("Owner:", deployer.address);

  const Synthesis = await ethers.getContractFactory("Synthesis", {
    libraries: {
      RequestIdLib: networkConfig[network.name].requestIdLib,
    }
  });
  const synthesis = Synthesis.attach(this.s);
  
  const Portal = await ethers.getContractFactory("Portal", {
    libraries: {
      RequestIdLib: networkConfig[network.name].requestIdLib,
    }
  });
  const portal = Portal.attach(this.p);

  // origin token should be from another place
  for (let netw of this.sourceForRepresentation) {
    let tokens = networkConfig[netw].token;
    for (let t of tokens) {
      let tokenAddressBytes32 = addressToBytes32(t.address);
      if (await synthesis.representationSynt(tokenAddressBytes32) === '0x0000000000000000000000000000000000000000') {
        this.tx = await synthesis.createRepresentation(tokenAddressBytes32, "18", `${t.name}`, `${t.symbol}(${networkConfig[netw].netwiker})`,
          networkConfig[netw].chainId, networkConfig[netw].netwiker)
        console.log(`createRepresentation for ${t.name} on ${network.name} source from ${netw}: ${this.tx.hash}`);
        await this.tx.wait();
      }
    }
  }

  // create representation for crosschain tokens
  for (let netw of this.sourceForRepresentation) {
    if (networkConfig[netw].localToken) {
      let tokens = networkConfig[netw].localToken;
      for (let t of tokens) {
        let tokenAddressBytes32 = addressToBytes32(t.address);
        if (await synthesis.representationSynt(tokenAddressBytes32) === '0x0000000000000000000000000000000000000000') {
          this.tx = await synthesis.createRepresentation(tokenAddressBytes32, "18", `${t.name}`, `${t.symbol}(${networkConfig[netw].netwiker})`,
            networkConfig[netw].chainId, networkConfig[netw].netwiker)
          console.log(`createRepresentation for ${t.name} token on ${network.name} source from ${netw}: ${this.tx.hash}`);
          await this.tx.wait();
        }
      }
    }
  }

  for (let netw of networks) {
      let tokens = networkConfig[netw].localToken;
      for (let t of tokens) {
        let tokenAddressBytes32 = addressToBytes32(t.address);
        if (await synthesis.representationSynt(tokenAddressBytes32) === '0x0000000000000000000000000000000000000000') {
          this.tx = await portal["approveRepresentationRequest(bytes32,uint8)"](tokenAddressBytes32, "18");
          console.log(`approveRepresentationRequest for ${t.name} token on ${network.name} source from ${netw}: ${this.tx.hash}`);
          await this.tx.wait();
        }
     }
  }

  for (let netw of this.sourceForRepresentation) {
    let adrTokenEywa = networkConfig[netw].eywa;
    console.log('@@@@@@ - ',adrTokenEywa);
    if(adrTokenEywa){
      let tokenAddressBytes32 = addressToBytes32(adrTokenEywa);
      if (await synthesis.representationSynt(tokenAddressBytes32) === '0x0000000000000000000000000000000000000000') {
        this.tx = await synthesis.createRepresentation(tokenAddressBytes32, "18", "EYWA-Token", `EYWA(${networkConfig[netw].netwiker})`,
        networkConfig[netw].chainId, networkConfig[netw].netwiker)
        console.log(`createRepresentation for ${t.name} token on ${network.name} source from ${netw}: ${this.tx.hash}`);
        await this.tx.wait();
      }
    }
  }

  for (let netw of networks) {
    let adrTokenEywa = networkConfig[netw].eywa;
    if (adrTokenEywa){
      let tokenAddressBytes32 = addressToBytes32(adrTokenEywa);
      if (await synthesis.representationSynt(tokenAddressBytes32) === '0x0000000000000000000000000000000000000000') {
        this.tx = await portal["approveRepresentationRequest(bytes32,uint8)"](tokenAddressBytes32, "18");
        console.log(`approveRepresentationRequest for EYWA-Token token on ${network.name} source from ${netw}: ${this.tx.hash}`);
        await this.tx.wait();
      }
    }
  }

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
