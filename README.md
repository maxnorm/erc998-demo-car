# ERC998 Composable NFT Demo - Car Assembly

This project demonstrates the power of ERC998 composable NFTs through a car assembly example. Cars are composable NFTs that can own and be composed of various car parts (also NFTs), showcasing the "NFT of NFTs" concept.

## What is ERC998?

ERC998 is a standard for composable NFTs that allows an NFT to own other NFTs and ERC20 tokens. This creates hierarchical ownership structures where a parent NFT can contain child tokens, enabling complex digital asset compositions.

## Project Overview

This demo project includes:

- **Car Contract**: ERC998 composable NFT representing cars that can own car parts
- **Part Contracts**: ERC721/ERC998 NFTs representing individual car parts (Engine, Wheel, FuelTank)
- **Fuel Contract**: ERC20 token representing fuel that can be owned by fuel tanks
- **Interactive Demo Script**: Comprehensive demonstration of car assembly and disassembly

## Schema

![ERC998 Composable NFT Demo - Car Assembly](./doc/assets/schema.png)

## Usage

### Running the Interactive Demo

Run the interactive demo script that demonstrates all ERC998 functionality:

1. Clone the repository:
```shell
git clone https://github.com/maxnorm/erc998-demo-car.git
```

2. Install dependencies:
```shell
npm install
```

3. Run the development network (In another terminal):
```shell
npx hardhat node
```

4. Run the demo script & monitor the logs to see the demo:
```shell
npx hardhat run scripts/demo.ts --network localhost
```

This script will:
1. Deploy Car, Engine, Wheel, FuelTank, and Fuel contracts
2. Mint various car parts (engine, 4 wheels, fuel tank) and fuel
3. Assemble parts into a complete car using different ERC998 methods
4. Demonstrate part transfers and disassembly
5. Show car sales with all nested ownership intact
6. Verify ownership hierarchies throughout the process