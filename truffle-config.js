module.exports = {
  networks: {
    /*
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // eslint-disable-line camelcase
    },
    */
    development: {
      platform: 'klaytn',
      url: 'https://api.baobab.klaytn.net:8651',
      gasLimit: 10000000, // increase if you need
    },
    coverage: {
      host: 'localhost',
      network_id: '*', // eslint-disable-line camelcase
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
    ganache: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // eslint-disable-line camelcase
    }
  },
  compilers: {
    solc: {
      version: '0.5.8',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: 'constantinople'
      }
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions: {
      currency: 'KRW',
      gasPrice: 5
    }
  }
};
