import hre from "hardhat";
const network = await hre.network.connect();
const ethers = network.ethers;
import * as readline from 'readline';

const line = "|======================================================================|";

const contracts = ["Car", "Engine", "Wheel", "FuelTank", "Fuel"];
let car: any;
let carAddress: string;
let engine: any;
let engineAddress: string;
let wheel: any;
let wheelAddress: string;
let fuelTank: any;
let fuelTankAddress: string;
let fuel: any;
let fuelAddress: string;

let alice: any;
let bob: any;

// ========================================================
// Deploying contracts
// ========================================================

async function deploy(): Promise<void> {
  [alice, bob] = await ethers.getSigners();

  console.log(line);
  console.log("| Deploying contracts");
  console.log(line);
  for (const contract of contracts) {
    const Contract = await ethers.getContractFactory(contract);
    const contractInstance = await Contract.deploy();
    await contractInstance.deploymentTransaction()
    await _assignContract(contract, contractInstance);
    console.log(`| ${contract} : ${await contractInstance.getAddress()}`);
  }
  console.log(line);
}

// ========================================================
// Minting car parts
// ========================================================

async function mintCar(to: string): Promise<any> {
  const tx =   await car.mint(to);
  const receipt = await tx.wait();
   // Transfer event: [from, to, tokenId] (ERC721 Event)
   return receipt.logs[0].args[2];
}

async function mintEngine(to: string): Promise<any> {
  const tx =   await engine.mint(to);
  const receipt = await tx.wait();
   // Transfer event: [from, to, tokenId] (ERC721 Event)
   return receipt.logs[0].args[2];
}

async function mintWheel(to: string): Promise<any> {
  const tx =   await wheel.mint(to);
  const receipt = await tx.wait();
   // Transfer event: [from, to, tokenId] (ERC721 Event)
   return receipt.logs[0].args[2];
}

async function mintFuelTank(to: string): Promise<any> {
  const tx =   await fuelTank.mint(to);
  const receipt = await tx.wait();
   // Transfer event: [from, to, tokenId] (ERC721 Event)
   return receipt.logs[0].args[2];
}

async function mintFuel(to: string): Promise<any> {
  const tx =   await fuel.mintTo(to);
  const receipt = await tx.wait();
   // Transfer event: [from, to, value] (ERC20 Event)
   return receipt.logs[0].args[2];
}

async function mintCarParts(to: string): Promise<CarParts> {
  const carToken =   await mintCar(to);
  const engineToken = await mintEngine(to);
  const wheelToken_1 = await mintWheel(to);
  const wheelToken_2 = await mintWheel(to);
  const wheelToken_3 = await mintWheel(to);
  const wheelToken_4 = await mintWheel(to);
  const fuelTankToken = await mintFuelTank(to);
  const fuelToken = await mintFuel(to);

  console.log(line);
  console.log(`| Minted car parts to ${to}`);
  console.log(line);
  console.log(`| Car ID: ${carToken}`);
  console.log(`| Engine ID: ${engineToken}`);    
  console.log(`| Wheel ID: ${wheelToken_1}, ${wheelToken_2}, ${wheelToken_3}, ${wheelToken_4}`);
  console.log(`| Fuel Tank ID: ${fuelTankToken}`);
  console.log(`| Fuel Balance: ${Number(fuelToken) / 10**18}L`);
  console.log(line);

  return { carToken, engineToken, wheelToken_1, wheelToken_2, wheelToken_3, wheelToken_4, fuelTankToken, fuelToken };
}

// ========================================================
// 1. Attaching NFTs to a parent composable NFT
// ========================================================

// ========================================================
// Method 1: Using safeTransferFrom with data (ERC721)
// ========================================================
async function transferEngineToCar(engineToken: string, carToken: string): Promise<void> {
  console.log(line);
  console.log(`| Sending Engine #${engineToken} to Car #${carToken}...`);
  console.log(line);
  console.log(`| From: ${await alice.getAddress()}`);
  console.log(`| To: ${carAddress}`);
    
  const data = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [carToken]);
  const tx = await engine.connect(alice)["safeTransferFrom(address,address,uint256,bytes)"](
    await alice.getAddress(),
    carAddress,
    engineToken,
    data
  );
  const receipt = await tx.wait();

  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| Engine #${engineToken} successfully transferred to Car #${carToken}`);
}

// ========================================================
// Method 2: Using getChild() function (ERC721)
// ========================================================
async function addWheelToCar(wheelToken: string, carToken: string): Promise<void> {
  console.log(line);
  console.log(`| Adding Wheel #${wheelToken} to Car #${carToken}...`);
  console.log(line);
  console.log(`| From: ${await alice.getAddress()}`);
  console.log(`| To: ${carAddress}`);
  
  // First, approve the car contract to transfer the wheel
  const approveTx = await wheel.connect(alice).approve(carAddress, wheelToken);
  await approveTx.wait();
  console.log(`|`);
  console.log(`| Alice approved Car contract to claim the Wheel #${wheelToken}`);
  console.log(`|`);
  
  // Then use getChild to add the wheel to the car
  const tx = await car.connect(alice).getChild(
    await alice.getAddress(),
    carToken,
    wheelAddress,
    wheelToken
  );
    
  const receipt = await tx.wait();
  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| Wheel #${wheelToken} successfully added to Car #${carToken}`);
  console.log(line);
  console.log("");
}

// ========================================================
// Method 3: Adding composable to composable 
//           using ERC721 safeTransferFrom with data (FuelTank to Car)
// ========================================================
async function addFuelTankToCar(fuelTankToken: string, carToken: string): Promise<void> {
  console.log(line);
  console.log(`| Adding FuelTank #${fuelTankToken} to Car #${carToken}...`);
  console.log(line);
  console.log(`| From: ${await alice.getAddress()}`);
  console.log(`| To: ${carAddress}`);
  
  // Use safeTransferFrom with data for composable to composable transfer
  const data = ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [carToken]);
  const tx = await fuelTank.connect(alice)["safeTransferFrom(address,address,uint256,bytes)"](
    await alice.getAddress(),
    carAddress,
    fuelTankToken,
    data
  );
    
  const receipt = await tx.wait();
  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| FuelTank #${fuelTankToken} successfully added to Car #${carToken}`);
  console.log(line);
}

// ========================================================
// 2. Detaching NFTs from a parent composable NFT
// ========================================================

// ========================================================
// Method 1: Using transferChild to send to EOA
// ========================================================
async function detachEngineFromCar(engineToken: string, carToken: string): Promise<void> {
  const directOwner = await engine.ownerOf(engineToken);

  console.log(line);
  console.log(`| Detaching Engine #${engineToken} from Car #${carToken}...`);
  console.log(line);
  console.log("|");
  console.log("| Reference CAR Contract Address:");
  console.log(`| ${carAddress}`);
  console.log("|");
  
  console.log(`| From: ${directOwner}`);
  console.log(`| To: ${await alice.getAddress()}`);
  
  const tx = await car.connect(alice).transferChild(carToken, await alice.getAddress(), engineAddress, engineToken);
  const receipt = await tx.wait();
  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| Engine #${engineToken} successfully detached from Car #${carToken}`);
  console.log(line);
}

// ========================================================
// Method 2: Using safeTransferChild (with data to send to another composable NFT)
// ========================================================
async function detachWheelFromCar(wheelToken: string, carToken: string): Promise<void> {
  const directOwner = await wheel.ownerOf(wheelToken);

  console.log(line);
  console.log(`| Detaching Wheel #${wheelToken} from Car #${carToken}...`);
  console.log(line);
  console.log("|");
  console.log("| Reference CAR Contract Address:");
  console.log(`| ${carAddress}`);
  console.log("|");
  
  console.log(`| From: ${directOwner}`);
  console.log(`| To: ${await alice.getAddress()}`);
  
  const tx = await car.connect(alice).safeTransferChild(carToken, await alice.getAddress(), wheelAddress, wheelToken);
  const receipt = await tx.wait();
  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| Wheel #${wheelToken} successfully detached from Car #${carToken}`);
  console.log(line);
  console.log("");
}

// ========================================================
// Method 3: Using transferChildToParent (Send to another composable NFT)
// ========================================================
async function detachFuelTankFromCar(fuelTankToken: string, fromCarToken: string): Promise<void> {
  console.log(line);
  console.log(`| Detaching Fuel Tank #${fuelTankToken} from Car #${fromCarToken}...`);
  console.log(line);

  await waitForInput("First, let's mint a new car to Alice...");
  const toCarToken = await mintCar(await alice.getAddress());
  console.log(line);
  console.log(`| Minted new Car as destination (Car ID: ${toCarToken})`);
  console.log(`| Car owner: ${await car.ownerOf(toCarToken)}`);
  console.log(line);

  await waitForInput("We are now set to transfer the fuel tank to the new car...");
  console.log(line);
  console.log("| Transferring Fuel Tank...");
  console.log(`| From: Car #${fromCarToken} (${carAddress})`);
  console.log(`| To: Car #${toCarToken} (${carAddress})`);
  console.log("|");
  
  // Use transferChildToParent to move fuel tank from one car to another
  const tx = await car.connect(alice).transferChildToParent(
    fromCarToken,
    carAddress,
    toCarToken,
    fuelTankAddress,
    fuelTankToken
  );
  const receipt = await tx.wait();
  
  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| FuelTank #${fuelTankToken} successfully transferred from Car #${fromCarToken} to Car #${toCarToken}`);
  console.log(line);

  await waitForInput("Let's send the fuel tank back to Alice for the demo purposes...");
  console.log(line);
  console.log("| Transferring Fuel Tank...");
  console.log(`| From: Car #${toCarToken} (${carAddress})`);
  console.log(`| To: Alice (${await alice.getAddress()})`);
  console.log("|");
  
  const tx2 = await car.connect(alice).transferChild(toCarToken, await alice.getAddress(), fuelTankAddress, fuelTankToken);
  const receipt2 = await tx2.wait();

  console.log(`| Transaction hash: ${tx2.hash}`);
  console.log(`| Gas used: ${receipt2.gasUsed.toString()}`);
  console.log(`| FuelTank #${fuelTankToken} successfully transferred from Car #${toCarToken} to Alice`);
  console.log(line);
}

/**
 * Assemble the car parts to the car
 * @param waiting - whether to wait for input before each step (default: true)
 * @returns the car parts
 */
async function assemble(carParts: CarParts, waiting: boolean = true): Promise<void> {
  console.log(line);
  console.log("| Assembling the car");
  console.log(line);

  if (waiting) {
    await waitForInput("Let's send the engine to the car...");
  }
  await transferEngineToCar(carParts.engineToken, carParts.carToken);

  console.log(line);

  if (waiting) {
    await waitForInput("Our car needs wheels! Let's add the four wheels to the car...");
  }
  await addWheelToCar(carParts.wheelToken_1, carParts.carToken);
  await addWheelToCar(carParts.wheelToken_2, carParts.carToken);
  await addWheelToCar(carParts.wheelToken_3, carParts.carToken);
  await addWheelToCar(carParts.wheelToken_4, carParts.carToken);

  if (waiting) {
    await waitForInput("A car without a fuel tank doesnt go far! Let's add the fuel tank to the car...");
  }
  await addFuelTankToCar(carParts.fuelTankToken, carParts.carToken);
}

/**
 * Disassemble the car
 * @param carParts - the car parts to disassemble
 * @param to - the address to send the car parts to
 */
async function disassemble(car: CarParts, to: string): Promise<void> {
  console.log(line);
  console.log("| Disassembling the car");
  console.log(line);

  await waitForInput("Let's detach the engine from the car & send it back to Alice...");
  await detachEngineFromCar(car.engineToken, car.carToken);

  await waitForInput("Let's detach the wheels from the car & send them back to Alice...");
  await detachWheelFromCar(car.wheelToken_1, car.carToken);
  await detachWheelFromCar(car.wheelToken_2, car.carToken);
  await detachWheelFromCar(car.wheelToken_3, car.carToken);
  await detachWheelFromCar(car.wheelToken_4, car.carToken);

  await waitForInput("let's transfer the fuel tank to another car owned by Alice...");
  await detachFuelTankFromCar(car.fuelTankToken, car.carToken);
}

async function sellCar(carToken: string, to: string): Promise<void> {
  console.log("\n" + line);
  console.log(`| Selling Car #${carToken} to Bob (${to})`);
  console.log(line);
  console.log(`| From: ${await alice.getAddress()}`);
  console.log(`| To: ${to}`);

  // We can use transferFrom from ERC721 to transfer the car to the buyer
  const tx = await car.connect(alice).transferFrom(await alice.getAddress(), to, carToken);
  const receipt = await tx.wait();

  console.log(`| Transaction hash: ${tx.hash}`);
  console.log(`| Gas used: ${receipt.gasUsed.toString()}`);
  console.log(`| Car #${carToken} successfully transferred to ${to}`);
  console.log(line);
}

async function main(): Promise<void> {
  console.log(line);
  console.log("| 🚗 Welcome to the ERC998 Composable NFT Demo");
  console.log("| This demo will show you how composable NFTs work with car assembly.");
  console.log(line);

  await waitForInput("Ready to deploy contracts...");
  await deploy();

  await waitForInput("Contracts deployed! Let's mint the car parts now...");
  const carParts = await mintCarParts(await alice.getAddress());

  await waitForInput("Now that Alice has the car parts, let's assemble the car now...");
  await assemble(carParts);

  console.log("");
  console.log(line);
  console.log("|");
  console.log("| 🎉 Congrats! We now have a car with 1 engine, 4 wheels, and 1 fuel tank!");
  console.log("| All of these car parts are now owned by the car using the powerful composable NFTs!");
  console.log("|");
  console.log(line);

  await waitForInput("Let's look how we can disassemble the car...");
  await disassemble(carParts, await alice.getAddress());

  await waitForInput("Now that Alice has all the car parts back, she can reassemble a car using the first car token...");
  await assemble(carParts, false);

  await waitForInput("We can now sell the car to Bob...");
  await sellCar(carParts.carToken, await bob.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// ========================================================
// Helper functions 
// ========================================================
type CarParts = { 
  carToken: any, 
  engineToken: any, 
  wheelToken_1: any, 
  wheelToken_2: any, 
  wheelToken_3: any, 
  wheelToken_4: any, 
  fuelTankToken: any, 
  fuelToken: any;
};

async function _assignContract (contract: string, contractInstance: any): Promise<void> {
  switch (contract) {
    case "Car":
      car = contractInstance;
      carAddress = await contractInstance.getAddress();
      break;
    case "Engine":
      engine = contractInstance;
      engineAddress = await contractInstance.getAddress();
      break;
    case "Wheel":
      wheel = contractInstance;
      wheelAddress = await contractInstance.getAddress();
      break;
    case "FuelTank":
      fuelTank = contractInstance;
      fuelTankAddress = await contractInstance.getAddress();
      break;
    case "Fuel":
      fuel = contractInstance;
      fuelAddress = await contractInstance.getAddress();
      break;  
  }
}

function waitForInput(message: string): Promise<void> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    console.log(`\n| ${message}`);
    rl.question('| Press Enter to continue...', () => {
      rl.close();
      resolve();
    });
    console.log("");
  });
}