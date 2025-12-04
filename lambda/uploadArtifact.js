// lambda/uploadArtifact.js
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const s3Client = new S3Client({});
const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);

exports.handler = async (event) => {
  try {
    const testRunId = event.pathParameters?.id;
    const body = JSON.parse(event.body);
    const { filename, contentType } = body;
    
    if (!testRunId || !filename) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Test run ID and filename are required' })
      };
    }
    
    // Verify test run exists
    const testRun = await docClient.send(new GetCommand({
      TableName: process.env.TEST_RUNS_TABLE,
      Key: { id: testRunId }
    }));
    
    if (!testRun.Item) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Test run not found' })
      };
    }
    
    // Generate S3 key
    const s3Key = `test-runs/${testRunId}/artifacts/${filename}`;
    
    // Generate pre-signed URL for upload
    const command = new PutObjectCommand({
      Bucket: process.env.ARTIFACTS_BUCKET,
      Key: s3Key,
      ContentType: contentType || 'application/octet-stream'
    });
    
    const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
    
    // Determine if this is a screenshot based on file extension
    const isScreenshot = /\.(png|jpg|jpeg|gif|webp)$/i.test(filename);
    const artifactList = isScreenshot ? 'screenshots' : 'artifacts';
    
    // Update test run with artifact reference
    const artifacts = testRun.Item[artifactList] || [];
    if (!artifacts.includes(filename)) {
      artifacts.push(filename);
      
      await docClient.send(new UpdateCommand({
        TableName: process.env.TEST_RUNS_TABLE,
        Key: { id: testRunId },
        UpdateExpression: `SET #artifactList = :artifacts`,
        ExpressionAttributeNames: { '#artifactList': artifactList },
        ExpressionAttributeValues: { ':artifacts': artifacts }
      }));
    }
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        uploadUrl,
        s3Key,
        artifactUrl: `https://${process.env.ARTIFACTS_BUCKET}.s3.amazonaws.com/${s3Key}`
      })
    };
  } catch (error) {
    console.error('Error generating upload URL:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Failed to generate upload URL' })
    };
  }
};
