const fs = require('fs');
const path = require('path');

async function main() {
  console.log("📦 Exporting contract ABIs...\n");

  const artifactsPath = path.join(__dirname, '../artifacts/contracts');
  const outputPath = path.join(__dirname, '../abis');

  // Create output directory
  if (!fs.existsSync(outputPath)) {
    fs.mkdirSync(outputPath, { recursive: true });
  }

  const contractFiles = [
    { name: 'LoanCore', file: 'LoanCore.sol' },
    { name: 'OfferBook', file: 'OfferBook.sol' },
    { name: 'CollateralVault', file: 'CollateralVault.sol' },
    { name: 'PriceOracle', file: 'PriceOracle.sol' },
    { name: 'ReputationRegistry', file: 'ReputationRegistry.sol' },
    { name: 'PrivacyModule', file: 'PrivacyModule.sol' },
    { name: 'FeeDistributor', file: 'FeeDistributor.sol' },
    { name: 'XeroToken', file: 'XeroToken.sol' },
    { name: 'XeroGovernance', file: 'XeroGovernance.sol' },
  ];

  const abis = {};
  let successCount = 0;
  let errorCount = 0;

  for (const contract of contractFiles) {
    try {
      const artifactPath = path.join(
        artifactsPath,
        contract.file,
        `${contract.name}.json`
      );

      if (fs.existsSync(artifactPath)) {
        const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
        
        // Save individual ABI
        fs.writeFileSync(
          path.join(outputPath, `${contract.name}.json`),
          JSON.stringify(artifact.abi, null, 2)
        );

        // Add to combined object
        abis[contract.name] = artifact.abi;

        console.log(`✅ Exported ${contract.name} ABI`);
        successCount++;
      } else {
        console.log(`⚠️  ${contract.name} artifact not found`);
        errorCount++;
      }
    } catch (error) {
      console.error(`❌ Error exporting ${contract.name}:`, error.message);
      errorCount++;
    }
  }

  // Save combined ABIs file
  fs.writeFileSync(
    path.join(outputPath, 'index.json'),
    JSON.stringify(abis, null, 2)
  );

  // Create TypeScript type definitions
  const typeDefs = generateTypeDefinitions(abis);
  fs.writeFileSync(
    path.join(outputPath, 'types.ts'),
    typeDefs
  );

  // Create JavaScript index file
  const jsIndex = generateJSIndex(Object.keys(abis));
  fs.writeFileSync(
    path.join(outputPath, 'index.js'),
    jsIndex
  );

  console.log('\n📊 Export Summary:');
  console.log('==================================================');
  console.log(`✅ Successfully exported: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log(`📁 Output directory: ${outputPath}`);
  console.log('==================================================\n');
}

function generateTypeDefinitions(abis) {
  let typeDefs = `// Auto-generated TypeScript definitions
// Generated on: ${new Date().toISOString()}

export interface ContractABIs {
`;

  for (const contractName of Object.keys(abis)) {
    typeDefs += `  ${contractName}: any[];\n`;
  }

  typeDefs += `}

export const ABIs: ContractABIs = {
`;

  for (const contractName of Object.keys(abis)) {
    typeDefs += `  ${contractName}: require('./${contractName}.json'),\n`;
  }

  typeDefs += `};\n`;

  return typeDefs;
}

function generateJSIndex(contractNames) {
  let jsIndex = `// Auto-generated JavaScript index
// Generated on: ${new Date().toISOString()}

`;

  for (const name of contractNames) {
    jsIndex += `const ${name}ABI = require('./${name}.json');\n`;
  }

  jsIndex += `\nmodule.exports = {
`;

  for (const name of contractNames) {
    jsIndex += `  ${name}ABI,\n`;
  }

  jsIndex += `};\n`;

  return jsIndex;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error:");
    console.error(error);
    process.exit(1);
  });