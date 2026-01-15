// scripts/verify-contracts.js
// Standalone version - directly reads the deployment JSON (no DeploymentManager dependency)

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🔍 Standalone Contract Verification on Mantlescan (Mantle Sepolia)");
  console.log("=============================================================\n");

  const network = hre.network.name;
  console.log("Network:", network);

  // Hardcoded path to your actual deployment file
  const deploymentPath = path.join(__dirname, "../deployments/mantle-testnet.json");

  if (!fs.existsSync(deploymentPath)) {
    console.error("❌ Deployment file not found at:", deploymentPath);
    console.error("Please run deploy-contracts.js first or check the path.");
    process.exit(1);
  }

  console.log("Deployment file:", deploymentPath);
  console.log("File size:", fs.statSync(deploymentPath).size, "bytes");

  let deployment;
  try {
    deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    console.log("Deployment loaded successfully");
    console.log("Network in file:", deployment.network);
    console.log("Deployer:", deployment.deployer || "(not set)");
    console.log("Last updated:", deployment.lastUpdated || deployment.timestamp);
  } catch (err) {
    console.error("❌ Failed to parse deployment JSON:", err.message);
    process.exit(1);
  }

  // Extract constructor args for contracts that need them
  const constructorArgs = deployment.constructorArgs || {};

  // List of contracts to verify (using exact paths from your file)
  const contractsToVerify = [
    { name: "FeeDistributor",     address: deployment.contracts.core?.FeeDistributor,     argsKey: "core.FeeDistributor" },
    { name: "XeroToken",          address: deployment.contracts.tokens?.XERO,             argsKey: "tokens.XERO" },
    { name: "XeroGovernance",     address: deployment.contracts.core?.Governance,         argsKey: "core.Governance" },
    { name: "CollateralVault",    address: deployment.contracts.core?.CollateralVault,    argsKey: "core.CollateralVault" },
    { name: "PriceOracle",        address: deployment.contracts.core?.PriceOracle,        argsKey: "core.PriceOracle" },
    { name: "ReputationRegistry", address: deployment.contracts.core?.ReputationRegistry, argsKey: "core.ReputationRegistry" },
    { name: "PrivacyModule",      address: deployment.contracts.core?.PrivacyModule,      argsKey: "core.PrivacyModule" },
    { name: "LoanCore",           address: deployment.contracts.core?.LoanCore,           argsKey: "core.LoanCore" },
    { name: "OfferBook",          address: deployment.contracts.core?.OfferBook,          argsKey: "core.OfferBook" }
  ];

  console.log("\nFound contracts to verify:");
  contractsToVerify.forEach(c => {
    console.log(`  • ${c.name.padEnd(20)} → ${c.address || "MISSING"}`);
  });

  if (network === "localhost" || network === "hardhat") {
    console.log("\nℹ️  Skipping verification on local network");
    return;
  }

  let successCount = 0;
  let skippedCount = 0;
  let errorCount = 0;

  for (const contract of contractsToVerify) {
    if (!contract.address) {
      console.log(`\n⚠️  Skipping ${contract.name} - address missing in deployment`);
      skippedCount++;
      continue;
    }

    console.log(`\nVerifying ${contract.name} at ${contract.address}...`);

    try {
      await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: constructorArgs[contract.argsKey] || [],
      });

      console.log(`✅ ${contract.name} verified successfully`);
      successCount++;
    } catch (error) {
      if (error.message.includes("Already Verified")) {
        console.log(`ℹ️  ${contract.name} already verified`);
        skippedCount++;
      } else {
        console.error(`❌ Error verifying ${contract.name}:`, error.message);
        errorCount++;
      }
    }
  }

  console.log("\n=============================================================");
  console.log("Verification Summary:");
  console.log(`✅ Successfully verified: ${successCount}`);
  console.log(`ℹ️  Already verified / skipped: ${skippedCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log("=============================================================\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\nVerification failed:", error);
    process.exit(1);
  });