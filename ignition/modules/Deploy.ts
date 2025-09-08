import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("DeployAllCarPartsContracts", (m) => {
  // Deploy all contracts
  const car = m.contract("Car");
  const engine = m.contract("Engine");
  const wheel = m.contract("Wheel");
  const fuelTank = m.contract("FuelTank");
  const fuel = m.contract("Fuel");

  return { 
    car,
    engine,
    wheel,
    fuelTank,
    fuel
  };
});
