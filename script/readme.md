# Automatic network deployment script

Repository consists of 3 main files:

- env.sh - containing important environment variables, allowing to customize the script for the project needs
- functions.sh - containing helper functions, to avoid clutter in the main script file
- script.sh - main script, allowing to setup the network

## Requirements

- helm v3.8.1
- kubectl v1.23.5
- istioctl v1.13.2
- kubectl hlf plugin
- yq 4.24.5
- jq 1.6
- configtxlator 1.4.3

## Usage

For more information on how this script works please refer to [our article](https://espeoblockchain.com/blog/hyperledger-fabric-network-on-kubernetes).
If you have any questions feel free to email me at [marcin.wojciechowski@espeo.eu](mailto:marcin.wojciechowski@espeo.eu).
