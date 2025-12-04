// build.js - Script to package Lambda functions
const fs = require('fs');
const path = require('path');
const archiver = require('archiver');

const lambdaFunctions = [
  { name: 'createTestRun', file: 'createTestRun.js' },
  { name: 'getTestRuns', file: 'getTestRuns.js' },
  { name: 'getTestRunById', file: 'getTestRunById.js' },
  { name: 'updateTestRun', file: 'updateTestRun.js' },
  { name: 'uploadArtifact', file: 'uploadArtifact.js' },
  { name: 'getArtifact', file: 'getArtifact.js' }
];

const lambdaDir = path.join(__dirname, 'lambda');

// Create lambda directory if it doesn't exist
if (!fs.existsSync(lambdaDir)) {
  fs.mkdirSync(lambdaDir, { recursive: true });
}

async function packageLambda(lambdaName, fileName) {
  return new Promise((resolve, reject) => {
    const outputPath = path.join(lambdaDir, `${lambdaName.toLowerCase().replace(/([A-Z])/g, '_$1').toLowerCase()}.zip`);
    const output = fs.createWriteStream(outputPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', () => {
      console.log(`✅ ${lambdaName}: ${archive.pointer()} bytes`);
      resolve();
    });

    archive.on('error', (err) => {
      reject(err);
    });

    archive.pipe(output);
    
    // Add the lambda function file
    const functionPath = path.join(lambdaDir, fileName);
    if (fs.existsSync(functionPath)) {
      archive.file(functionPath, { name: fileName });
    }
    
    // Add node_modules
    const nodeModulesPath = path.join(__dirname, 'node_modules');
    if (fs.existsSync(nodeModulesPath)) {
      archive.directory(nodeModulesPath, 'node_modules');
    }
    
    archive.finalize();
  });
}

async function buildAll() {
  console.log('🔨 Building Lambda function packages...\n');
  
  try {
    for (const lambda of lambdaFunctions) {
      await packageLambda(lambda.name, lambda.file);
    }
    console.log('\n✨ All Lambda functions packaged successfully!');
  } catch (error) {
    console.error('❌ Error packaging Lambda functions:', error);
    process.exit(1);
  }
}

buildAll();
